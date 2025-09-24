//
//  RGBEncoder.swift
//  LiDARStream
//
//  Created by Louis Mamon on 9/14/25.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.


import Foundation
import ARKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers


struct EncodedRGB {
    let frameId: UInt32
    let data: Data
}

final class RGBEncoder {
    private var nextFrameId: UInt32 = 0
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    /// If set, encodes frames as JPEG with this quality (0.0...1.0).
    /// If nil, sends raw BGRA8.
    private let jpegQuality: CGFloat?
    
    init(jpegQuality: CGFloat? = 0.7) {
        self.jpegQuality = jpegQuality
    }
    
    ///build packet
    func makePacket(from frame: ARFrame) -> EncodedRGB? {
        let px = frame.capturedImage
        let w = CVPixelBufferGetWidth(px)
        let h = CVPixelBufferGetHeight(px)
        
        //encoding path
        let payload: Data
        let flags: RGBFlags
        let bytesPerRow: UInt32
        let pixelFormat: UInt32 = kCVPixelFormatType_32BGRA
        
        
        if let q = jpegQuality {
            guard let jpeg = Self.jpegData(from: px,
                                                 width: w,
                                                 height: h,
                                                 quality: q,
                                                 ciContext: ciContext) else { return nil }
            
            payload = jpeg
            flags = [.isJPEG]
            bytesPerRow = 0
        } else {
            guard let raw = Self.bgraBytes(from: px) else { return nil }
            payload = raw
            flags = []
            bytesPerRow = UInt32(w * 4)
            
        }
        
        let crc = CRC32.compute(payload)
        
        //build header
        let header = RGBHeader(magic: RGBMagic.packet,
                               version: RGBWireVersion.current,
                               flags: flags,
                               width: UInt16(w),
                               height: UInt16(h),
                               bytesPerRow: bytesPerRow,
                               pixelFormat: pixelFormat,
                               timestampSeconds: frame.timestamp,
                               frameId: nextFrameId,
                               rgbPayloadBytes: UInt32(payload.count),
                               crc32: crc)
        
        let fullData = header.toData() + payload
        let encoded = EncodedRGB(frameId: nextFrameId, data: fullData)
        nextFrameId &+= 1
        return encoded
    }
     
        
        //MARK: - Helpers
        
    private static func jpegData(from pixelBuffer: CVPixelBuffer,
                                 width: Int,
                                 height: Int,
                                 quality: CGFloat,
                                 ciContext: CIContext) -> Data? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: width))
        else {
            return nil
        }
        
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil
        }
        
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
    
    private static func bgraBytes(from pixelBuffer: CVPixelBuffer) -> Data? {
        guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_32BGRA else {
            return nil //skipping conversion fallback for simplicity
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let length = bytesPerRow * height
        return Data(bytes: base, count: length)
        
    }
    }



