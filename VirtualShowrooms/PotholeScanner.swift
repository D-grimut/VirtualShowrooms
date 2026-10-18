//
//  PotholeScanner.swift
//  VirtualShowrooms
//
//  Fuses raw LiDAR depth (ARFrame.sceneDepth) into a heightmap aligned to the road surface.
//  Much finer than ARKit's scene-reconstruction mesh: every high-confidence depth sample from
//  every frame is averaged into 2 mm cells instead of being smoothed into a room-scale mesh.
//

import ARKit
import CoreGraphics
import simd

/// World-space frame the heightmap lives in: origin on the road, `normal` pointing up.
struct SurfaceFrame {
    let origin: SIMD3<Float>
    let normal: SIMD3<Float>
    let axisU: SIMD3<Float>
    let axisV: SIMD3<Float>
}

/// Depth + confidence copied out of an ARFrame, so the frame itself isn't retained
/// (holding ARFrames makes ARKit drop frames).
struct DepthSnapshot {
    let width: Int
    let height: Int
    let depth: [Float32]
    let confidence: [UInt8]
    let timestamp: TimeInterval
    let cameraTransform: simd_float4x4
    // intrinsics refer to the full camera image; depth pixel centres are scaled up to it
    private let fx, fy, cx, cy: Float
    private let scaleX, scaleY: Float

    init?(frame: ARFrame) {
        guard let sceneDepth = frame.sceneDepth, let confidenceMap = sceneDepth.confidenceMap else { return nil }
        let depthMap = sceneDepth.depthMap

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
        }

        let w = CVPixelBufferGetWidth(depthMap)
        let h = CVPixelBufferGetHeight(depthMap)
        guard w > 0, h > 0,
              CVPixelBufferGetWidth(confidenceMap) == w, CVPixelBufferGetHeight(confidenceMap) == h,
              let depthBase = CVPixelBufferGetBaseAddress(depthMap),
              let confidenceBase = CVPixelBufferGetBaseAddress(confidenceMap) else { return nil }

        let depthRowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        let confidenceRowBytes = CVPixelBufferGetBytesPerRow(confidenceMap)

        var depth = [Float32](repeating: 0, count: w * h)
        var confidence = [UInt8](repeating: 0, count: w * h)
        depth.withUnsafeMutableBytes { dst in
            for y in 0..<h {
                memcpy(dst.baseAddress! + y * w * 4, depthBase + y * depthRowBytes, w * 4)
            }
        }
        confidence.withUnsafeMutableBytes { dst in
            for y in 0..<h {
                memcpy(dst.baseAddress! + y * w, confidenceBase + y * confidenceRowBytes, w)
            }
        }

        let intrinsics = frame.camera.intrinsics
        let resolution = frame.camera.imageResolution
        self.width = w
        self.height = h
        self.depth = depth
        self.confidence = confidence
        self.timestamp = frame.timestamp
        self.cameraTransform = frame.camera.transform
        self.fx = intrinsics.columns.0.x
        self.fy = intrinsics.columns.1.y
        self.cx = intrinsics.columns.2.x
        self.cy = intrinsics.columns.2.y
        self.scaleX = Float(resolution.width) / Float(w)
        self.scaleY = Float(resolution.height) / Float(h)
    }

    var cameraPosition: SIMD3<Float> {
        SIMD3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
    }

    var cameraForward: SIMD3<Float> {
        -SIMD3(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)
    }

    static let highConfidence = UInt8(ARConfidenceLevel.high.rawValue)

    /// Unprojects a depth pixel (its centre) to world space. ARKit camera space: x right, y up, looking down -z.
    @inline(__always)
    func worldPoint(x: Int, y: Int, depth d: Float) -> SIMD3<Float> {
        let pu = (Float(x) + 0.5) * scaleX
        let pv = (Float(y) + 0.5) * scaleY
        let local = SIMD4<Float>((pu - cx) / fx * d, -(pv - cy) / fy * d, -d, 1)
        let world = cameraTransform * local
        return SIMD3(world.x, world.y, world.z)
    }

    /// Distance to the surface at the image centre, only when the LiDAR is confident about it.
    func centreDepth() -> Float? {
        let index = (height / 2) * width + width / 2
        guard confidence[index] == Self.highConfidence else { return nil }
        return depth[index]
    }

    /// High-confidence world points on a sparse pixel grid (for finding the road plane).
    func sparsePoints(step: Int, range: ClosedRange<Float>) -> [SIMD3<Float>] {
        var points: [SIMD3<Float>] = []
        points.reserveCapacity((width / step) * (height / step))
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let index = y * width + x
                let d = depth[index]
                guard confidence[index] == Self.highConfidence, range.contains(d) else { continue }
                points.append(worldPoint(x: x, y: y, depth: d))
            }
        }
        return points
    }
}

/// Finds the road/floor plane in a single frame so the heightmap can be laid on it.
/// This only orients the grid; the reference surface used for volume is re-fitted later
/// on the intact ring around the pothole (see PotholeAnalyzer).
enum SurfaceLocator {
    static func locate(points: [SIMD3<Float>], camera: simd_float4x4) -> SurfaceFrame? {
        guard points.count >= 400 else { return nil }

        // RANSAC for the dominant near-horizontal plane
        let threshold: Float = 0.01
        var bestInliers = 0
        var bestNormal = SIMD3<Float>(0, 1, 0)
        var bestPoint = SIMD3<Float>.zero
        for _ in 0..<150 {
            let a = points[Int.random(in: 0..<points.count)]
            let b = points[Int.random(in: 0..<points.count)]
            let c = points[Int.random(in: 0..<points.count)]
            let cross = simd_cross(b - a, c - a)
            let length = simd_length(cross)
            guard length > 1e-6 else { continue }
            var n = cross / length
            if n.y < 0 { n = -n }
            // roads and floors are level to within a few degrees; ARKit's world y is gravity-up
            guard n.y > 0.85 else { continue }
            var inliers = 0
            for p in points where abs(simd_dot(p - a, n)) < threshold {
                inliers += 1
            }
            if inliers > bestInliers {
                bestInliers = inliers
                bestNormal = n
                bestPoint = a
            }
        }
        guard bestInliers >= points.count * 2 / 5 else { return nil }

        // least-squares refine on the inliers: y = a*x + b*z + c
        let inliers = points.filter { abs(simd_dot($0 - bestPoint, bestNormal)) < threshold }
        var ata = [Double](repeating: 0, count: 9)
        var atb = [Double](repeating: 0, count: 3)
        var centroid = SIMD3<Double>.zero
        for p in inliers {
            let row = [Double(p.x), Double(p.z), 1]
            for i in 0..<3 {
                atb[i] += row[i] * Double(p.y)
                for j in 0..<3 { ata[i * 3 + j] += row[i] * row[j] }
            }
            centroid += SIMD3<Double>(Double(p.x), Double(p.y), Double(p.z))
        }
        centroid /= Double(inliers.count)
        guard let coefficients = LinearSolver.solve(ata, atb, n: 3) else { return nil }
        let normal = simd_normalize(SIMD3<Float>(Float(-coefficients[0]), 1, Float(-coefficients[1])))
        let planeY = coefficients[0] * centroid.x + coefficients[1] * centroid.z + coefficients[2]
        let planePoint = SIMD3<Float>(Float(centroid.x), Float(planeY), Float(centroid.z))

        // centre the grid where the camera is pointing
        let position = SIMD3(camera.columns.3.x, camera.columns.3.y, camera.columns.3.z)
        let forward = -SIMD3(camera.columns.2.x, camera.columns.2.y, camera.columns.2.z)
        var origin = planePoint
        let denominator = simd_dot(forward, normal)
        if abs(denominator) > 0.2 {
            let t = simd_dot(planePoint - position, normal) / denominator
            if t > 0 && t < 3 { origin = position + forward * t }
        }

        // v points the way the user is facing along the ground, u to their right
        var along = forward - simd_dot(forward, normal) * normal
        if simd_length(along) < 1e-3 {
            let up = SIMD3(camera.columns.1.x, camera.columns.1.y, camera.columns.1.z)
            along = up - simd_dot(up, normal) * normal
        }
        let axisV = simd_normalize(along)
        let axisU = simd_cross(axisV, normal)
        return SurfaceFrame(origin: origin, normal: normal, axisU: axisU, axisV: axisV)
    }
}

/// Confidence-weighted running average of surface height per 2 mm cell.
/// Not thread-safe: use it from a single serial queue.
final class HeightmapGrid {
    let frame: SurfaceFrame
    let cellSize: Float
    let size: Int // cells per side

    private(set) var sumW: [Float]
    private(set) var sumWH: [Float]
    private(set) var count: [UInt16]

    // depth samples outside this range are noisy (far) or below the LiDAR's minimum range (near)
    static let depthRange: ClosedRange<Float> = 0.15...1.5
    // reject grazing views: depth error grows quickly with incidence angle
    static let minCosIncidence: Float = 0.5
    // depth jump between neighbouring pixels that marks a "flying pixel" at an edge
    static let edgeJump: Float = 0.02

    init(frame: SurfaceFrame, cellSize: Float = 0.002, extent: Float = 2.0) {
        self.frame = frame
        self.cellSize = cellSize
        self.size = Int((extent / cellSize).rounded())
        let cells = size * size
        sumW = [Float](repeating: 0, count: cells)
        sumWH = [Float](repeating: 0, count: cells)
        count = [UInt16](repeating: 0, count: cells)
    }

    /// Adds every usable depth sample of the snapshot. Returns how many were used.
    @discardableResult
    func integrate(_ snapshot: DepthSnapshot) -> Int {
        let w = snapshot.width
        let h = snapshot.height
        let origin = frame.origin
        let normal = frame.normal
        let axisU = frame.axisU
        let axisV = frame.axisV
        let camera = snapshot.cameraPosition
        let inverseCell = 1 / cellSize
        let size = self.size
        let half = size / 2
        var used = 0

        snapshot.depth.withUnsafeBufferPointer { depth in
        snapshot.confidence.withUnsafeBufferPointer { confidence in
        sumW.withUnsafeMutableBufferPointer { sumW in
        sumWH.withUnsafeMutableBufferPointer { sumWH in
        count.withUnsafeMutableBufferPointer { count in
            for y in 1..<(h - 1) {
                for x in 1..<(w - 1) {
                    let index = y * w + x
                    let d = depth[index]
                    guard confidence[index] == DepthSnapshot.highConfidence,
                          Self.depthRange.contains(d) else { continue }

                    // skip pixels straddling a depth edge (pothole rims smear between near and far)
                    if abs(depth[index - 1] - d) > Self.edgeJump || abs(depth[index + 1] - d) > Self.edgeJump
                        || abs(depth[index - w] - d) > Self.edgeJump || abs(depth[index + w] - d) > Self.edgeJump {
                        continue
                    }

                    let p = snapshot.worldPoint(x: x, y: y, depth: d)
                    let ray = p - camera
                    let rayLength = simd_length(ray)
                    let cosIncidence = -simd_dot(ray, normal) / rayLength
                    guard cosIncidence > Self.minCosIncidence else { continue }

                    let relative = p - origin
                    let ix = Int((simd_dot(relative, axisU) * inverseCell).rounded(.down)) + half
                    let iy = Int((simd_dot(relative, axisV) * inverseCell).rounded(.down)) + half
                    guard ix >= 0, iy >= 0, ix < size, iy < size else { continue }

                    // nearer, straighter-on samples are more precise
                    let weight = cosIncidence / (d * d)
                    let cell = iy * size + ix
                    sumW[cell] += weight
                    sumWH[cell] += weight * simd_dot(relative, normal)
                    if count[cell] < UInt16.max { count[cell] += 1 }
                    used += 1
                }
            }
        }
        }
        }
        }
        }
        return used
    }

    /// Top-down coverage map of the central area: grey = not scanned yet, green = flat, yellow→red = deeper.
    func previewImage(extent: Float = 1.2, pixels: Int = 160) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: pixels * pixels * 4)
        let cellsPerPixel = extent / cellSize / Float(pixels)
        let start = Float(size) / 2 - extent / cellSize / 2
        for py in 0..<pixels {
            // forward (v) points up in the image
            let iy = Int(start + (Float(pixels - 1 - py) + 0.5) * cellsPerPixel)
            for px in 0..<pixels {
                let ix = Int(start + (Float(px) + 0.5) * cellsPerPixel)
                let out = (py * pixels + px) * 4
                var color: (UInt8, UInt8, UInt8) = (45, 45, 48)
                if ix >= 0, iy >= 0, ix < size, iy < size {
                    let cell = iy * size + ix
                    if count[cell] > 0 {
                        let depth = -sumWH[cell] / sumW[cell]
                        if depth < 0.005 {
                            color = (80, 170, 95)
                        } else {
                            let t = min(depth / 0.06, 1)
                            color = (255, UInt8(220 * (1 - t)), 40)
                        }
                    }
                }
                rgba[out] = color.0
                rgba[out + 1] = color.1
                rgba[out + 2] = color.2
                rgba[out + 3] = 255
            }
        }
        // crosshair at the grid centre
        for offset in -4...4 {
            for (px, py) in [(pixels / 2 + offset, pixels / 2), (pixels / 2, pixels / 2 + offset)] {
                let out = (py * pixels + px) * 4
                rgba[out] = 255; rgba[out + 1] = 255; rgba[out + 2] = 255
            }
        }

        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: pixels, height: pixels, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

/// Small dense solver for least-squares normal equations.
enum LinearSolver {
    /// Solves A x = b (A is n×n, row-major) with partial pivoting. Returns nil if singular.
    static func solve(_ a: [Double], _ b: [Double], n: Int) -> [Double]? {
        var m = a
        var x = b
        for col in 0..<n {
            var pivot = col
            for row in (col + 1)..<max(col + 1, n) where abs(m[row * n + col]) > abs(m[pivot * n + col]) {
                pivot = row
            }
            guard abs(m[pivot * n + col]) > 1e-12 else { return nil }
            if pivot != col {
                for k in 0..<n { m.swapAt(col * n + k, pivot * n + k) }
                x.swapAt(col, pivot)
            }
            for row in (col + 1)..<max(col + 1, n) {
                let factor = m[row * n + col] / m[col * n + col]
                guard factor != 0 else { continue }
                for k in col..<n { m[row * n + k] -= factor * m[col * n + k] }
                x[row] -= factor * x[col]
            }
        }
        for row in stride(from: n - 1, through: 0, by: -1) {
            var sum = x[row]
            for k in (row + 1)..<max(row + 1, n) { sum -= m[row * n + k] * x[k] }
            x[row] = sum / m[row * n + row]
        }
        return x
    }
}
