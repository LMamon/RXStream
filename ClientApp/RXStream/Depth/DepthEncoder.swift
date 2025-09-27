// TODO: Optionally downsample depth map before sending to reduce bandwidth.
// TODO: Consider compressing depth map (e.g., zlib) for smaller payload size.

import ARKit
import CoreVideo
import simd

struct EncodedDepth {
    let frameId: UInt32
    let data: Data
}

final class DepthEncoder {
    private var nextFrameId: UInt32 = 0
    
    //Returns a single wire packet: [header][depthPayload][confPayload?]
    func makePacket(from frame: ARFrame) -> EncodedDepth? {
        guard let sceneDepth = frame.sceneDepth else { return nil}
        let depthPB = sceneDepth.depthMap
        let confPB = sceneDepth.confidenceMap //may be nil on some devices
        
        //validate expected format
        guard CVPixelBufferGetPixelFormatType(depthPB) == kCVPixelFormatType_DepthFloat32 else { return nil }
        
        //lock, copy to tightly packed bufffers
        CVPixelBufferLockBaseAddress(depthPB, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthPB, .readOnly) }
        
        let w = CVPixelBufferGetWidth(depthPB)
        let h = CVPixelBufferGetHeight(depthPB)
        
        let srcBPR = CVPixelBufferGetBytesPerRow(depthPB)
        let dstBPR = w * MemoryLayout<Float32>.size //tight stride
        let depthPackedSize = dstBPR * h
        
        guard let srcBase = CVPixelBufferGetBaseAddress(depthPB) else { return nil }
        
        var depthPacked = Data(count: depthPackedSize)
        depthPacked.withUnsafeMutableBytes { dstBuf in
            guard let dstBase = dstBuf.baseAddress else { return }
            for row in 0..<h {
                let srcRow = srcBase.advanced(by: row * srcBPR)
                let dstRow = dstBase.advanced(by: row * dstBPR)
                memcpy(dstRow, srcRow, dstBPR)
            }
        }
        
        //Confidence (optional): pack tightly as width*1 per row (UInt8)
        var confPacked = Data()
        var flags: DepthFlags = []
        if let confPB, CVPixelBufferGetPixelFormatType(confPB) == kCVPixelFormatType_OneComponent8 {
            CVPixelBufferLockBaseAddress(confPB, .readOnly)
            let cw = CVPixelBufferGetWidth(confPB)
            let ch = CVPixelBufferGetHeight(confPB)
            let cSrcBPR = CVPixelBufferGetBytesPerRow(confPB)
            guard let cBase = CVPixelBufferGetBaseAddress(confPB),
                  
                cw == w, ch == h else {
                CVPixelBufferUnlockBaseAddress(confPB, .readOnly)
                return nil
            }
            confPacked = Data(count: w * h) //tight stride w * 1
            confPacked.withUnsafeMutableBytes { dstBuf in
                guard let dstBase = dstBuf.baseAddress else { return }
                for row in 0..<h {
                    let srcRow = cBase.advanced(by: row * cSrcBPR)
                    let dstRow = dstBase.advanced(by: row * w)
                    memcpy(dstRow, srcRow, w)
                }
            }
            CVPixelBufferUnlockBaseAddress(confPB, .readOnly)
            flags.insert(.hasConfidence)
        }
        
        //CRC over payloads(s)
        let crc = CRC32.compute([depthPacked, confPacked])
        
        //build header
        let header = DepthHeader(
                    magic: DepthMagic.packet,
                    version: DepthWireVersion.current,
                    flags: flags,
                    width: UInt16(w),
                    height: UInt16(h),
                    bytesPerRowPacked: UInt32(dstBPR),
                    pixelFormat: UInt32(kCVPixelFormatType_DepthFloat32),
                    timestampSeconds: frame.timestamp,
                    frameId: nextFrameId,
                    intrinsics: frame.camera.intrinsics,
                    cameraTransform: frame.camera.transform,
                    depthPayloadBytes: UInt32(depthPacked.count),
                    confPayloadBytes: UInt32(confPacked.count),
                    crc32: crc
                )

        
                let fullData = header.toData() + depthPacked + confPacked
                let encoded = EncodedDepth(frameId: nextFrameId, data: fullData)
                nextFrameId &+= 1
                return encoded
    }
}
