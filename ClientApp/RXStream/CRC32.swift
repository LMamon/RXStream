//  A tiny, fast CRC-32 (IEEE) so receiver can verify integrity (esp. for UDP)
//  Created by Louis Mamon on 9/8/25.

// TODO: Benchmark CRC32 vs faster hashing (e.g., xxHash) for large payloads.

import Foundation

enum CRC32 {
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
                
            }
            return c
        }
    }()
    
    static func compute(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        data.withUnsafeBytes { buf in
            guard let base = buf.bindMemory(to: UInt8.self).baseAddress else { return }
            for i in 0..<buf.count {
                let idx = Int((crc ^ UInt32(base[i])) & 0xFF)
                crc = table[idx] ^ (crc >> 8)
            }
        }
        return crc ^ 0xFFFFFFFF
    }
    
    static func compute(_ parts: [Data]) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for part in parts {
            part.withUnsafeBytes { buf in
                guard let base = buf.bindMemory(to: UInt8.self).baseAddress else { return }
                for i in 0..<buf.count {
                    let idx = Int((crc ^ UInt32(base[i])) & 0xFF)
                    crc = table[idx] ^ (crc >> 8)
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
