//  Defines a (schema) stable header + a couple of flags so receiver can reconstruct safely (and ignore fields it doesn’t use yet).
//  Created by Louis Mamon on 9/7/25.


import simd
import CoreVideo

enum DepthMagic {
    static let packet: UInt32 = 0x44505448 //"DPTH"
    static let udpChunk: UInt16 = 0xABCD //UDP chunk magic
}

//increment later if changing header layout
enum DepthWireVersion {
    static let current: UInt16 = 1
}

//header flags
struct DepthFlags: OptionSet {
    let rawValue: UInt16
    static let hasConfidence = DepthFlags(rawValue: 1 << 0)
}

struct DepthHeader {
    var magic: UInt32 //"DPTH"
    var version: UInt16 //1
    var flags: DepthFlags //bit 0 => hasConfidence
    var width: UInt16
    var height: UInt16
    var bytesPerRowPacked: UInt32 //= width * 4 (Float32)
    var pixelFormat: UInt32 //kCVPixelFormatType_DepthFloat32
    var timestampSeconds: Double
    var frameId: UInt32
    var intrinsics: simd_float3x3 //camera K
    var cameraTransform: simd_float4x4 //worldFromCamera
    var depthPayloadBytes: UInt32 //packed depth size (tight)
    var confPayloadBytes: UInt32 //packed confidence size (0 if absent)
    var crc32: UInt32 //CRC32 over depthPayload||confPayload
    
    //serializing to little-endian data
    func toData() -> Data {
        var out = Data()
        func append<T>(_ v: T) {
            var value = v
            withUnsafeBytes(of: &value) { rawBuf in
                out.append(rawBuf.bindMemory(to: UInt8.self))
            }
        }
        
        append(magic)
        append(version)
        append(flags.rawValue)
        append(width)
        append(height)
        append(bytesPerRowPacked)
        append(pixelFormat)
        append(timestampSeconds)
        append(frameId)
        var K = intrinsics
        var T = cameraTransform
        out.append(Data(bytes: &K, count: MemoryLayout.size(ofValue: K)))
        out.append(Data(bytes: &T, count: MemoryLayout.size(ofValue: T)))
        append(depthPayloadBytes)
        append(confPayloadBytes)
        append(crc32)
        return out
    }
}
