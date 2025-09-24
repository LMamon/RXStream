//
//  UdpFramer.swift
//  LiDARStream
//  Robust UDP chunking with frameId and 16-bit chunk counters (so big frames don’t break).
//  Created by Louis Mamon on 9/8/25.
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

// TODO: Add reassembly utility on the receiver side (mirror of makeChunks).
// TODO: Support FEC or retransmission strategy for high packet loss networks.

import Foundation

struct UdpChunk {
    // [magic(2)][version(1)][frameId(4)][chunkIndex(2)][totalChunks(2)] + payload
    static func makeChunks(frameId: UInt32, payload: Data, maxUDPPayload: Int = 1400) -> [Data] {
        let total = payload.count
        let totalChunks = (total + maxUDPPayload - 1) / maxUDPPayload
        var chunks: [Data] = []
        chunks.reserveCapacity(totalChunks)
        
        for i in 0..<totalChunks {
            let off = i * maxUDPPayload
            let sz = min(maxUDPPayload, total - off)
            let slice = payload.subdata(in: off..<(off + sz))
                                        
            var header = Data()
            func append<T>(_ v: T) {
                var vv = v
                withUnsafeBytes(of: &vv) { rawBuf in
                        header.append(rawBuf.bindMemory(to: UInt8.self))
                    }
            }
            append(DepthMagic.udpChunk) //0xABCD
            header.append(0x01) //version
            append(frameId) //UInt32
            append(UInt16(i)) //chunkIndex
            append(UInt16(totalChunks)) //totalChunks
            chunks.append(header + slice)
        }
        return chunks
    }
}
