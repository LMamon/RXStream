
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
    private var frameId: UInt32 = 0
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    /// If set, encodes frames as JPEG with this quality (0.0...1.0).
    /// If nil, sends raw BGRA8.
    private let jpegQuality: CGFloat?
    
    init(jpegQuality: CGFloat? = 0.7) {
        self.jpegQuality = jpegQuality
    }
    
    ///build packet
    func makePacket(capturedImage: CVPixelBuffer,
                     timestamp: Double) -> EncodedRGB? {
         let w = CVPixelBufferGetWidth(capturedImage)
         let h = CVPixelBufferGetHeight(capturedImage)

         let payload: Data
         let flags: RGBFlags
         let bytesPerRow: UInt32
         let pixelFormat: UInt32 = kCVPixelFormatType_32BGRA

         if let q = jpegQuality {
             // JPEG encode
             guard let jpeg = Self.jpegData(from: capturedImage,
                                            width: w,
                                            height: h,
                                            quality: q,
                                            ciContext: ciContext) else { return nil }
             payload = jpeg
             flags = [.isJPEG]
             bytesPerRow = 0
         } else {
             //Raw BGRA bytes
             guard let raw = Self.bgraBytes(from: capturedImage) else { return nil }
             payload = raw
             flags = []
             bytesPerRow = UInt32(w * 4)
         }

         //CRC
         let crc = CRC32.compute(payload)

         //header
         let header = RGBHeader(
             magic: RGBMagic.packet,
             version: RGBWireVersion.current,
             flags: flags,
             width: UInt16(w),
             height: UInt16(h),
             bytesPerRow: bytesPerRow,
             pixelFormat: pixelFormat,
             timestampSeconds: timestamp,
             frameId: frameId,
             rgbPayloadBytes: UInt32(payload.count),
             crc32: crc
         )

        
        


        let fullData = header.toData() + payload
        let encoded = EncodedRGB(frameId: frameId, data: fullData)
        frameId &+= 1
        return encoded
     }
     
        
        //MARK: - Helpers
    private static func jpegData(from pixelBuffer: CVPixelBuffer,
                                     width: Int,
                                     height: Int,
                                     quality: CGFloat,
                                     ciContext: CIContext) -> Data? {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            guard let cgImage = ciContext.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
                return nil
            }
            let uiImage = UIImage(cgImage: cgImage)
            return uiImage.jpegData(compressionQuality: quality)
        }
    
    private static func bgraBytes(from pixelBuffer: CVPixelBuffer) -> Data? {
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

            guard let baseAddr = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
            let bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let h = CVPixelBufferGetHeight(pixelBuffer)
            let size = bpr * h

            return Data(bytes: baseAddr, count: size)
        }
    }



