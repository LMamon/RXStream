//
//  RGBWireFormat.swift
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

enum RGBMagic {
    static let packet: UInt32 = 0x52474246 //"RGBF"
    static let udpChunk: UInt16 = 0xBCDE //match Depth's style
}

enum RGBWireVersion {
    static let current: UInt16 = 1
}

struct RGBFlags: OptionSet {
    let rawValue: UInt16
    static let isJPEG = RGBFlags(rawValue: 1 << 0) //if not set => raw BGRA8
}

struct RGBHeader {
    var magic: UInt32 //"RGBF"
    var version: UInt16
    var flags: RGBFlags
    var width: UInt16
    var height: UInt16
    var bytesPerRow: UInt32 //BGRA stride if raw
    var pixelFormat: UInt32 //kCVPixelFormatType_32BGRA, etc.
    var timestampSeconds: Double
    var frameId: UInt32
    var rgbPayloadBytes: UInt32
    var crc32: UInt32 //CRC32 over the RGB payload
    
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
        append(bytesPerRow)
        append(pixelFormat)
        append(timestampSeconds)
        append(frameId)
        append(rgbPayloadBytes)
        append(crc32)
        return out
    }
}
