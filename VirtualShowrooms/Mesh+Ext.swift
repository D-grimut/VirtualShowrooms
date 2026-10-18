//
//  Mesh+Ext.swift
//  VirtualShowrooms
//
//  Created by Kelvin J on 5/17/23.
//

import RealityKit
import ARKit
import MetalKit

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }

    func normal(at index: UInt32) -> SIMD3<Float> {
        assert(normals.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per normal.")
        let normalPointer = normals.buffer.contents().advanced(by: normals.offset + (normals.stride * Int(index)))
        let normal = normalPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return normal
    }

    // helps from StackOverflow:
    // https://stackoverflow.com/questions/61063571/arkit-3-5-how-to-export-obj-from-new-ipad-pro-with-lidar
    // Copies the anchor's geometry into world space. ARKit's buffers are read-only to us,
    // so positions and normals are written into a new interleaved buffer instead.
    func toMDLMesh(device: MTLDevice, modelMatrix: simd_float4x4) -> MDLMesh {
        let rotation = simd_float3x3(
            SIMD3<Float>(modelMatrix.columns.0.x, modelMatrix.columns.0.y, modelMatrix.columns.0.z),
            SIMD3<Float>(modelMatrix.columns.1.x, modelMatrix.columns.1.y, modelMatrix.columns.1.z),
            SIMD3<Float>(modelMatrix.columns.2.x, modelMatrix.columns.2.y, modelMatrix.columns.2.z)
        )

        // interleaved [px, py, pz, nx, ny, nz] per vertex
        var vertexData = [Float]()
        vertexData.reserveCapacity(vertices.count * 6)
        for vertexIndex in 0..<UInt32(vertices.count) {
            let local = vertex(at: vertexIndex)
            let world = modelMatrix * SIMD4<Float>(local, 1)
            let worldNormal = simd_normalize(rotation * normal(at: vertexIndex))
            vertexData.append(contentsOf: [world.x, world.y, world.z, worldNormal.x, worldNormal.y, worldNormal.z])
        }

        let allocator = MTKMeshBufferAllocator(device: device)

        let data = vertexData.withUnsafeBytes { Data($0) }
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex)

        let indexCount = faces.count * faces.indexCountPerPrimitive
        let indexData = Data(bytes: faces.buffer.contents(), count: faces.bytesPerIndex * indexCount)
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index)

        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: indexCount,
                                 indexType: faces.bytesPerIndex == 2 ? .uInt16 : .uInt32,
                                 geometryType: .triangles,
                                 material: nil)

        let floatSize = MemoryLayout<Float>.size
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .float3,
                                                            offset: 3 * floatSize,
                                                            bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 6 * floatSize)

        let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                           vertexCount: vertices.count,
                           descriptor: vertexDescriptor,
                           submeshes: [submesh])

        return mesh
    }
}


extension URL: Identifiable {
    public var id: Self { self }
}
