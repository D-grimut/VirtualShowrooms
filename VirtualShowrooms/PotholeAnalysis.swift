//
//  PotholeAnalysis.swift
//  VirtualShowrooms
//
//  Turns a fused heightmap into pothole measurements:
//  1. fit the intact road surface on a ring around the hole (robust plane, or quadratic for crowned roads)
//  2. depth = reference surface − measured surface
//  3. pothole = cells deeper than 13 mm (ASTM D6433 lower bound), grown out to the rim at ~noise level
//  4. volume = Σ depth × cell area, with unscanned cells inside the outline interpolated and reported
//

import Foundation
import simd

struct PotholeMeasurement: Codable {
    var volumeLitres: Double
    var volumeCubicMetres: Double
    var areaSquareMetres: Double
    /// 99th percentile of depth: robust "max depth" that ignores single noisy cells
    var maxDepthMm: Double
    var deepestPointMm: Double
    var meanDepthMm: Double
    var lengthMm: Double
    var widthMm: Double
    var referenceSurface: String
    /// scatter of the intact road around the reference surface (sensor noise + real texture)
    var referenceRmsMm: Double
    /// share of the pothole footprint measured directly (the rest was interpolated)
    var coveragePercent: Double
    /// share of the 3–30 cm ring around the pothole that was scanned
    var surroundCoveragePercent: Double
    var meanSamplesPerCell: Double
    var cellSizeMm: Double
    var framesIntegrated: Int
    var quality: String
    var warnings: [String]
    var scannedAt: Date
}

struct PotholeResult {
    let measurement: PotholeMeasurement
    let width: Int
    let height: Int
    let cellSize: Float
    /// metres below the reference surface (positive = deeper), NaN where nothing was scanned
    let depth: [Float]
    let inPothole: [Bool]
}

enum PotholeAnalysisError: LocalizedError {
    case notEnoughData
    case notEnoughSurround
    case noPothole

    var errorDescription: String? {
        switch self {
        case .notEnoughData:
            return "Not enough of the surface was scanned. Sweep slowly over the pothole and the road around it."
        case .notEnoughSurround:
            return "Not enough intact road around the pothole was scanned. Include about 30 cm of road on every side."
        case .noPothole:
            return "No depression deeper than 13 mm was found near the centre of the scan. Aim at the pothole when you start."
        }
    }
}

/// Model of the intact road: height above the grid plane as a function of (x, y) in metres.
struct ReferenceSurface {
    enum Kind: String { case plane, quadratic }

    let kind: Kind
    let coefficients: [Double]
    let centreX: Double
    let centreY: Double

    func height(x: Float, y: Float) -> Float {
        let dx = Double(x) - centreX
        let dy = Double(y) - centreY
        let c = coefficients
        var h = c[0] + c[1] * dx + c[2] * dy
        if kind == .quadratic {
            h += c[3] * dx * dx + c[4] * dx * dy + c[5] * dy * dy
        }
        return Float(h)
    }

    static func leastSquares(_ kind: Kind, xs: [Float], ys: [Float], hs: [Float],
                             indices: [Int], centreX: Double, centreY: Double) -> ReferenceSurface? {
        let n = kind == .plane ? 3 : 6
        guard indices.count >= n * 4 else { return nil }
        var ata = [Double](repeating: 0, count: n * n)
        var atb = [Double](repeating: 0, count: n)
        var row = [Double](repeating: 0, count: n)
        for i in indices {
            let dx = Double(xs[i]) - centreX
            let dy = Double(ys[i]) - centreY
            row[0] = 1; row[1] = dx; row[2] = dy
            if n == 6 { row[3] = dx * dx; row[4] = dx * dy; row[5] = dy * dy }
            let h = Double(hs[i])
            for a in 0..<n {
                atb[a] += row[a] * h
                for b in 0..<n { ata[a * n + b] += row[a] * row[b] }
            }
        }
        guard let solution = LinearSolver.solve(ata, atb, n: n) else { return nil }
        return ReferenceSurface(kind: kind, coefficients: solution, centreX: centreX, centreY: centreY)
    }

    /// Least squares with iterative outlier trimming (2.5 robust σ). Returns the surface and inlier RMS.
    static func robustFit(_ kind: Kind, xs: [Float], ys: [Float], hs: [Float]) -> (surface: ReferenceSurface, rms: Float)? {
        guard !xs.isEmpty else { return nil }
        let centreX = xs.reduce(0.0) { $0 + Double($1) } / Double(xs.count)
        let centreY = ys.reduce(0.0) { $0 + Double($1) } / Double(ys.count)
        var indices = Array(xs.indices)
        var surface: ReferenceSurface?
        for _ in 0..<5 {
            guard let fit = leastSquares(kind, xs: xs, ys: ys, hs: hs, indices: indices,
                                         centreX: centreX, centreY: centreY) else { return nil }
            surface = fit
            // residual of every point once: the median uses the current inliers, the trim re-tests all
            let residuals = xs.indices.map { abs(hs[$0] - fit.height(x: xs[$0], y: ys[$0])) }
            let absResiduals = indices.map { residuals[$0] }.sorted()
            let sigma = 1.4826 * absResiduals[absResiduals.count / 2]
            let limit = max(2.5 * sigma, 0.0015)
            let kept = xs.indices.filter { residuals[$0] < limit }
            if kept.count == indices.count { break }
            indices = kept
        }
        guard let surface else { return nil }
        var sumSquares: Double = 0
        for i in indices {
            let r = Double(hs[i] - surface.height(x: xs[i], y: ys[i]))
            sumSquares += r * r
        }
        return (surface, Float((sumSquares / Double(max(indices.count, 1))).squareRoot()))
    }
}

enum PotholeAnalyzer {
    static let seedDepth: Float = 0.013      // ASTM D6433: potholes start at 13 mm
    static let growDepth: Float = 0.003      // follow the rim slope out to about sensor noise level
    static let minPotholeArea: Float = 0.001 // 10 cm²
    static let ringInner: Float = 0.03
    static let ringOuter: Float = 0.30
    static let minSamples: UInt16 = 2

    // 4-neighbour offsets (static so the hot loops don't allocate)
    private static let neighbourDI = [-1, 1, 0, 0]
    private static let neighbourDJ = [0, 0, -1, 1]

    static func analyze(grid: HeightmapGrid, framesIntegrated: Int) throws -> PotholeResult {
        let size = grid.size
        let cell = grid.cellSize
        let counts = grid.count
        let sumW = grid.sumW
        let sumWH = grid.sumWH

        // 1. crop to the scanned area
        var minX = size, minY = size, maxX = -1, maxY = -1
        for iy in 0..<size {
            for ix in 0..<size where counts[iy * size + ix] >= minSamples {
                minX = min(minX, ix); maxX = max(maxX, ix)
                minY = min(minY, iy); maxY = max(maxY, iy)
            }
        }
        guard maxX >= minX else { throw PotholeAnalysisError.notEnoughData }
        let w = maxX - minX + 1
        let h = maxY - minY + 1
        let half = Float(size / 2)

        // cell-centre coordinates in metres in the grid plane
        var xs = [Float](repeating: 0, count: w * h)
        var ys = [Float](repeating: 0, count: w * h)
        var height = [Float](repeating: .nan, count: w * h)
        var samples = [UInt16](repeating: 0, count: w * h)
        var observed = 0
        for j in 0..<h {
            for i in 0..<w {
                let index = j * w + i
                xs[index] = (Float(minX + i) - half + 0.5) * cell
                ys[index] = (Float(minY + j) - half + 0.5) * cell
                let g = (minY + j) * size + minX + i
                if counts[g] >= minSamples {
                    height[index] = sumWH[g] / sumW[g]
                    samples[index] = counts[g]
                    observed += 1
                }
            }
        }
        guard Float(observed) * cell * cell >= 0.04 else { throw PotholeAnalysisError.notEnoughData }

        // 2. remove isolated spikes
        height = despeckle(height, w: w, h: h, limit: 0.008)

        // 3. rough reference over the whole scan; pothole cells are the outliers
        guard var surface = initialSurface(height, xs: xs, ys: ys) else { throw PotholeAnalysisError.notEnoughData }

        // 4. segment, refit the reference on the intact ring around the outline, repeat with the better surface
        var target = SIMD2<Float>(Float(size / 2 - minX), Float(size / 2 - minY))
        var referenceRms: Float = 0
        var surroundCoverage: Float = 0
        for _ in 0..<2 {
            let depth = depthField(height, xs: xs, ys: ys, surface: surface)
            guard let segmentation = segment(depth, w: w, h: h, cell: cell, near: target) else {
                throw PotholeAnalysisError.noPothole
            }
            target = segmentation.centroid

            let distance = distanceTransform(segmentation.mask, w: w, h: h)
            var ringX: [Float] = [], ringY: [Float] = [], ringH: [Float] = []
            var ringCells = 0
            for index in 0..<(w * h) {
                let d = distance[index] * cell
                guard d >= ringInner, d <= ringOuter else { continue }
                ringCells += 1
                if !height[index].isNaN {
                    ringX.append(xs[index]); ringY.append(ys[index]); ringH.append(height[index])
                }
            }
            guard ringH.count >= 500 else { throw PotholeAnalysisError.notEnoughSurround }
            surroundCoverage = Float(ringH.count) / Float(max(ringCells, 1))

            // cap the fit size; the ring can hold hundreds of thousands of cells
            let stride = max(1, ringH.count / 120_000)
            if stride > 1 {
                ringX = Swift.stride(from: 0, to: ringX.count, by: stride).map { ringX[$0] }
                ringY = Swift.stride(from: 0, to: ringY.count, by: stride).map { ringY[$0] }
                ringH = Swift.stride(from: 0, to: ringH.count, by: stride).map { ringH[$0] }
            }

            guard let plane = ReferenceSurface.robustFit(.plane, xs: ringX, ys: ringY, hs: ringH) else {
                throw PotholeAnalysisError.notEnoughSurround
            }
            surface = plane.surface
            referenceRms = plane.rms
            // crowned or warped surface: use the quadratic only when it clearly fits better
            if ringH.count >= 3000,
               let quadratic = ReferenceSurface.robustFit(.quadratic, xs: ringX, ys: ringY, hs: ringH),
               quadratic.rms < plane.rms * 0.85 {
                surface = quadratic.surface
                referenceRms = quadratic.rms
            }
        }

        // final outline against the final reference
        var depth = depthField(height, xs: xs, ys: ys, surface: surface)
        guard let segmentation = segment(depth, w: w, h: h, cell: cell, near: target) else {
            throw PotholeAnalysisError.noPothole
        }
        let mask = segmentation.mask

        // 5. interpolate cells inside the outline that the LiDAR never saw
        let gaps = fillGaps(&depth, mask: mask, w: w, h: h)

        // 6. measure
        let cellArea = Double(cell) * Double(cell)
        var regionDepths: [Float] = []
        var volume: Double = 0
        var sumX: Double = 0, sumY: Double = 0
        var sampleTotal: Double = 0
        var sampledCells = 0
        for index in 0..<(w * h) where mask[index] {
            let d = depth[index].isNaN ? 0 : depth[index]
            regionDepths.append(d)
            volume += Double(max(d, 0)) * cellArea
            sumX += Double(xs[index]); sumY += Double(ys[index])
            if samples[index] > 0 { sampleTotal += Double(samples[index]); sampledCells += 1 }
        }
        let regionCount = regionDepths.count
        let area = Double(regionCount) * cellArea
        regionDepths.sort()
        let p99 = regionDepths[Int(Double(regionCount - 1) * 0.99)]
        let deepest = regionDepths.last ?? 0

        // length/width along the outline's principal axes
        let meanX = sumX / Double(regionCount), meanY = sumY / Double(regionCount)
        var cxx: Double = 0, cyy: Double = 0, cxy: Double = 0
        for index in 0..<(w * h) where mask[index] {
            let dx = Double(xs[index]) - meanX, dy = Double(ys[index]) - meanY
            cxx += dx * dx; cyy += dy * dy; cxy += dx * dy
        }
        let angle = 0.5 * atan2(2 * cxy, cxx - cyy)
        let major = SIMD2<Double>(cos(angle), sin(angle))
        let minor = SIMD2<Double>(-major.y, major.x)
        var minA = Double.greatestFiniteMagnitude, maxA = -Double.greatestFiniteMagnitude
        var minB = Double.greatestFiniteMagnitude, maxB = -Double.greatestFiniteMagnitude
        for index in 0..<(w * h) where mask[index] {
            let p = SIMD2<Double>(Double(xs[index]) - meanX, Double(ys[index]) - meanY)
            let a = simd_dot(p, major), b = simd_dot(p, minor)
            minA = min(minA, a); maxA = max(maxA, a)
            minB = min(minB, b); maxB = max(maxB, b)
        }
        let length = maxA - minA + Double(cell)
        let width = maxB - minB + Double(cell)

        let coverage = 1 - Double(gaps) / Double(regionCount)
        let meanSamples = sampledCells > 0 ? sampleTotal / Double(sampledCells) : 0

        var warnings: [String] = []
        if coverage < 0.97 {
            warnings.append(String(format: "%.0f%% of the pothole had no LiDAR data and was filled in from its surroundings. Sweep over the gaps, tilting to see the walls.", (1 - coverage) * 100))
        }
        if segmentation.touchesEdge {
            warnings.append("The pothole reaches the edge of the scanned area, so part of it may be missing. Scan further around it.")
        }
        if surroundCoverage < 0.6 {
            warnings.append(String(format: "Only %.0f%% of the road within 30 cm of the pothole was scanned, so the reference surface is less certain.", surroundCoverage * 100))
        }
        if referenceRms > 0.003 {
            warnings.append(String(format: "The surrounding road is rough (±%.1f mm), which limits volume accuracy.", referenceRms * 1000))
        }
        if meanSamples < 5 {
            warnings.append("Few depth samples per cell. Scan a little longer for a more precise result.")
        }

        let measurement = PotholeMeasurement(
            volumeLitres: volume * 1000,
            volumeCubicMetres: volume,
            areaSquareMetres: area,
            maxDepthMm: Double(p99) * 1000,
            deepestPointMm: Double(deepest) * 1000,
            meanDepthMm: area > 0 ? volume / area * 1000 : 0,
            lengthMm: length * 1000,
            widthMm: width * 1000,
            referenceSurface: surface.kind.rawValue,
            referenceRmsMm: Double(referenceRms) * 1000,
            coveragePercent: coverage * 100,
            surroundCoveragePercent: Double(surroundCoverage) * 100,
            meanSamplesPerCell: meanSamples,
            cellSizeMm: Double(cell) * 1000,
            framesIntegrated: framesIntegrated,
            quality: warnings.isEmpty ? "good" : "check",
            warnings: warnings,
            scannedAt: Date()
        )
        return PotholeResult(measurement: measurement, width: w, height: h, cellSize: cell, depth: depth, inPothole: mask)
    }

    // MARK: - Steps

    private static func depthField(_ height: [Float], xs: [Float], ys: [Float], surface: ReferenceSurface) -> [Float] {
        var depth = [Float](repeating: .nan, count: height.count)
        for index in height.indices where !height[index].isNaN {
            depth[index] = surface.height(x: xs[index], y: ys[index]) - height[index]
        }
        return depth
    }

    /// Replaces cells that differ from their 3×3 median by more than `limit`.
    private static func despeckle(_ height: [Float], w: Int, h: Int, limit: Float) -> [Float] {
        var output = height
        var window = [Float](repeating: 0, count: 9)
        for j in 0..<h {
            for i in 0..<w {
                let value = height[j * w + i]
                guard !value.isNaN else { continue }
                var n = 0
                for dj in -1...1 {
                    let y = j + dj
                    guard y >= 0, y < h else { continue }
                    for di in -1...1 {
                        let x = i + di
                        guard x >= 0, x < w else { continue }
                        let v = height[y * w + x]
                        if !v.isNaN { window[n] = v; n += 1 }
                    }
                }
                guard n >= 5 else { continue }
                // insertion sort of at most 9 values
                for a in 1..<n {
                    let key = window[a]
                    var b = a - 1
                    while b >= 0 && window[b] > key { window[b + 1] = window[b]; b -= 1 }
                    window[b + 1] = key
                }
                let median = window[n / 2]
                if abs(value - median) > limit { output[j * w + i] = median }
            }
        }
        return output
    }

    /// RANSAC plane over a subsample of the scan, then least-squares on its inliers.
    private static func initialSurface(_ height: [Float], xs: [Float], ys: [Float]) -> ReferenceSurface? {
        let valid = height.indices.filter { !height[$0].isNaN }
        guard valid.count >= 500 else { return nil }
        let step = max(1, valid.count / 60_000)
        let sample = Swift.stride(from: 0, to: valid.count, by: step).map { valid[$0] }

        let threshold: Float = 0.006
        var bestInliers = 0
        var best: (Float, Float, Float) = (0, 0, 0)
        for _ in 0..<300 {
            let p = (0..<3).map { _ in sample[Int.random(in: 0..<sample.count)] }
            let a = p.map { [1, Double(xs[$0]), Double(ys[$0])] }.flatMap { $0 }
            let b = p.map { Double(height[$0]) }
            guard let c = LinearSolver.solve(a, b, n: 3) else { continue }
            let c0 = Float(c[0]), c1 = Float(c[1]), c2 = Float(c[2])
            var inliers = 0
            for index in sample where abs(height[index] - (c0 + c1 * xs[index] + c2 * ys[index])) < threshold {
                inliers += 1
            }
            if inliers > bestInliers { bestInliers = inliers; best = (c0, c1, c2) }
        }
        guard bestInliers >= 100 else { return nil }
        let inliers = sample.filter { abs(height[$0] - (best.0 + best.1 * xs[$0] + best.2 * ys[$0])) < threshold }
        return ReferenceSurface.leastSquares(.plane, xs: xs, ys: ys, hs: height, indices: inliers, centreX: 0, centreY: 0)
    }

    private struct Segmentation {
        let mask: [Bool]
        let centroid: SIMD2<Float>
        let touchesEdge: Bool
    }

    /// Picks the deep component nearest `target`, grows it out to the rim, and closes enclosed gaps.
    private static func segment(_ depth: [Float], w: Int, h: Int, cell: Float, near target: SIMD2<Float>) -> Segmentation? {
        let count = w * h
        var label = [Int32](repeating: 0, count: count)
        var stack: [Int] = []
        var bestLabel: Int32 = 0
        var bestDistance = Float.greatestFiniteMagnitude
        var nextLabel: Int32 = 0
        let minCells = Int(minPotholeArea / (cell * cell))

        for start in 0..<count where label[start] == 0 && depth[start] > seedDepth {
            nextLabel += 1
            label[start] = nextLabel
            stack.append(start)
            var size = 0
            var sumI = 0, sumJ = 0
            while let index = stack.popLast() {
                size += 1
                let i = index % w, j = index / w
                sumI += i; sumJ += j
                for k in 0..<4 {
                    let ni = i + neighbourDI[k], nj = j + neighbourDJ[k]
                    guard ni >= 0, nj >= 0, ni < w, nj < h else { continue }
                    let neighbour = nj * w + ni
                    if label[neighbour] == 0 && depth[neighbour] > seedDepth {
                        label[neighbour] = nextLabel
                        stack.append(neighbour)
                    }
                }
            }
            guard size >= minCells else { continue }
            let centroid = SIMD2<Float>(Float(sumI) / Float(size), Float(sumJ) / Float(size))
            let distance = simd_distance(centroid, target)
            if distance < bestDistance { bestDistance = distance; bestLabel = nextLabel }
        }
        guard bestLabel != 0 else { return nil }

        // grow from the deep core out along the rim slope
        var mask = [Bool](repeating: false, count: count)
        for index in 0..<count where label[index] == bestLabel {
            mask[index] = true
            stack.append(index)
        }
        while let index = stack.popLast() {
            let i = index % w, j = index / w
            for k in 0..<4 {
                let ni = i + neighbourDI[k], nj = j + neighbourDJ[k]
                guard ni >= 0, nj >= 0, ni < w, nj < h else { continue }
                let neighbour = nj * w + ni
                if !mask[neighbour] && depth[neighbour] > growDepth {
                    mask[neighbour] = true
                    stack.append(neighbour)
                }
            }
        }

        // close the outline: anything not reachable from the border is inside the pothole
        // (stones, unscanned patches). Unscanned cells right next to the outline block the flood,
        // so an unseen strip of wall is filled rather than treated as outside.
        let distance = distanceTransform(mask, w: w, h: h)
        let blockRadius = 0.02 / cell
        var outside = [Bool](repeating: false, count: count)
        func passable(_ index: Int) -> Bool {
            !mask[index] && (!depth[index].isNaN || distance[index] > blockRadius)
        }
        for i in 0..<w {
            for index in [i, (h - 1) * w + i] where passable(index) && !outside[index] {
                outside[index] = true; stack.append(index)
            }
        }
        for j in 0..<h {
            for index in [j * w, j * w + w - 1] where passable(index) && !outside[index] {
                outside[index] = true; stack.append(index)
            }
        }
        while let index = stack.popLast() {
            let i = index % w, j = index / w
            for k in 0..<4 {
                let ni = i + neighbourDI[k], nj = j + neighbourDJ[k]
                guard ni >= 0, nj >= 0, ni < w, nj < h else { continue }
                let neighbour = nj * w + ni
                if !outside[neighbour] && passable(neighbour) {
                    outside[neighbour] = true
                    stack.append(neighbour)
                }
            }
        }
        // only close gaps near the outline, not unscanned corners of the crop
        for index in 0..<count where !mask[index] && !outside[index] && distance[index] <= blockRadius * 4 {
            mask[index] = true
        }

        var sumI = 0, sumJ = 0, cells = 0
        var touchesEdge = false
        for index in 0..<count where mask[index] {
            let i = index % w, j = index / w
            sumI += i; sumJ += j; cells += 1
            if i == 0 || j == 0 || i == w - 1 || j == h - 1 { touchesEdge = true }
        }
        let centroid = SIMD2<Float>(Float(sumI) / Float(cells), Float(sumJ) / Float(cells))
        return Segmentation(mask: mask, centroid: centroid, touchesEdge: touchesEdge)
    }

    /// Two-pass chamfer distance (in cells) to the nearest `true` cell.
    private static func distanceTransform(_ mask: [Bool], w: Int, h: Int) -> [Float] {
        let far = Float(w + h) * 2
        var distance = mask.map { $0 ? Float(0) : far }
        let diagonal: Float = 1.41421356
        for j in 0..<h {
            for i in 0..<w {
                let index = j * w + i
                var d = distance[index]
                if i > 0 { d = min(d, distance[index - 1] + 1) }
                if j > 0 {
                    d = min(d, distance[index - w] + 1)
                    if i > 0 { d = min(d, distance[index - w - 1] + diagonal) }
                    if i < w - 1 { d = min(d, distance[index - w + 1] + diagonal) }
                }
                distance[index] = d
            }
        }
        for j in stride(from: h - 1, through: 0, by: -1) {
            for i in stride(from: w - 1, through: 0, by: -1) {
                let index = j * w + i
                var d = distance[index]
                if i < w - 1 { d = min(d, distance[index + 1] + 1) }
                if j < h - 1 {
                    d = min(d, distance[index + w] + 1)
                    if i < w - 1 { d = min(d, distance[index + w + 1] + diagonal) }
                    if i > 0 { d = min(d, distance[index + w - 1] + diagonal) }
                }
                distance[index] = d
            }
        }
        return distance
    }

    /// Fills unscanned cells inside the outline by repeated neighbour averaging (a discrete
    /// Laplace fill: smooth, and it matches the measured depths at the gap edges). Returns the count.
    private static func fillGaps(_ depth: inout [Float], mask: [Bool], w: Int, h: Int) -> Int {
        let gaps = (0..<(w * h)).filter { mask[$0] && depth[$0].isNaN }
        guard !gaps.isEmpty else { return 0 }

        let known = (0..<(w * h)).filter { mask[$0] && !depth[$0].isNaN }
        let start = known.isEmpty ? 0 : known.reduce(Float(0)) { $0 + depth[$1] } / Float(known.count)
        for index in gaps { depth[index] = start }

        for _ in 0..<400 {
            var largestChange: Float = 0
            for index in gaps {
                let i = index % w, j = index / w
                var sum: Float = 0
                var n: Float = 0
                for k in 0..<4 {
                    let ni = i + neighbourDI[k], nj = j + neighbourDJ[k]
                    guard ni >= 0, nj >= 0, ni < w, nj < h else { continue }
                    let v = depth[nj * w + ni]
                    if !v.isNaN { sum += v; n += 1 }
                }
                if n > 0 {
                    let value = sum / n
                    largestChange = max(largestChange, abs(value - depth[index]))
                    depth[index] = value
                }
            }
            // converged to well below a micron
            if largestChange < 1e-6 { break }
        }
        return gaps.count
    }
}

/// Saves a scan as <name>.obj (heightmap mesh, metres, Y up, road surface at y = 0,
/// groups "pothole" and "road") plus <name>.json with the measurements.
enum PotholeExporter {
    @discardableResult
    static func save(_ result: PotholeResult, name: String) throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let folder = documents.appendingPathComponent("OBJ_FILES", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        // a "/" or ":" in the typed name would point outside the folder
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let baseName: String
        if cleaned.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            baseName = "pothole_" + formatter.string(from: result.measurement.scannedAt)
        } else {
            baseName = cleaned
        }

        let objURL = folder.appendingPathComponent("\(baseName).obj")
        try objText(result).write(to: objURL, atomically: true, encoding: .utf8)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(result.measurement).write(to: folder.appendingPathComponent("\(baseName).json"))
        return objURL
    }

    private static func objText(_ result: PotholeResult) -> String {
        let w = result.width, h = result.height, cell = result.cellSize
        let depth = result.depth, mask = result.inPothole

        // pothole plus a 5 cm margin of road
        var minI = w, minJ = h, maxI = -1, maxJ = -1
        for index in 0..<(w * h) where mask[index] {
            minI = min(minI, index % w); maxI = max(maxI, index % w)
            minJ = min(minJ, index / w); maxJ = max(maxJ, index / w)
        }
        let margin = Int(0.05 / cell)
        minI = max(0, minI - margin); minJ = max(0, minJ - margin)
        maxI = min(w - 1, maxI + margin); maxJ = min(h - 1, maxJ + margin)
        let centreI = Float(minI + maxI) / 2, centreJ = Float(minJ + maxJ) / 2

        func y(_ i: Int, _ j: Int) -> Float? {
            guard i >= 0, j >= 0, i < w, j < h else { return nil }
            let d = depth[j * w + i]
            return d.isNaN ? nil : -d
        }

        let m = result.measurement
        var out = "# VirtualShowrooms pothole scan\n"
        out += "# units: metres, Y up, intact road surface at y = 0\n"
        out += String(format: "# volume %.4f L, area %.5f m^2, max depth %.1f mm\n", m.volumeLitres, m.areaSquareMetres, m.maxDepthMm)

        var vertexIndex = [Int32](repeating: 0, count: w * h)
        var next: Int32 = 1
        for j in minJ...maxJ {
            for i in minI...maxI {
                guard let height = y(i, j) else { continue }
                // slope from central differences, for smooth shading
                let left = y(i - 1, j) ?? height, right = y(i + 1, j) ?? height
                let back = y(i, j - 1) ?? height, front = y(i, j + 1) ?? height
                let normal = simd_normalize(SIMD3<Float>(-(right - left) / (2 * cell), 1, (front - back) / (2 * cell)))
                let x = (Float(i) - centreI) * cell
                let z = -(Float(j) - centreJ) * cell
                out += String(format: "v %.5f %.5f %.5f\nvn %.4f %.4f %.4f\n", x, height, z, normal.x, normal.y, normal.z)
                vertexIndex[j * w + i] = next
                next += 1
            }
        }

        // faces counter-clockwise seen from above; a quad belongs to the pothole if any corner does
        var potholeFaces = "g pothole\n"
        var roadFaces = "g road\n"
        for j in minJ..<maxJ {
            for i in minI..<maxI {
                let a = j * w + i, b = a + 1, c = a + w + 1, d = a + w
                let va = vertexIndex[a], vb = vertexIndex[b], vc = vertexIndex[c], vd = vertexIndex[d]
                guard va > 0, vb > 0, vc > 0, vd > 0 else { continue }
                let faces = "f \(va)//\(va) \(vb)//\(vb) \(vc)//\(vc)\nf \(va)//\(va) \(vc)//\(vc) \(vd)//\(vd)\n"
                if mask[a] || mask[b] || mask[c] || mask[d] {
                    potholeFaces += faces
                } else {
                    roadFaces += faces
                }
            }
        }
        out += potholeFaces
        out += roadFaces
        return out
    }
}
