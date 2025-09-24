//
//  IMUWireFormat.swift
//  LiDARStream
//
//  Defines a stable header + flags so receiver can reconstruct IMU packets.
//  Supports fused motion (quat + accel + gyro + mag + baro) or raw subsets.
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

// TODO: Add option to include device orientation matrix alongside quaternion.

import Foundation

enum IMUMagic {
    static let packet: UInt32 = 0x494D5546 //"IMUF"
    static let updChunk: UInt16 = 0xCDEF
}

enum IMUWireVersion {
    static let current: UInt16 = 1
}

struct IMUFlags: OptionSet {
    let rawValue: UInt16
    
    static let isFused = IMUFlags(rawValue: 1 << 0) //CMDeviceMotion fused
    static let hasAccel = IMUFlags(rawValue: 1 << 1) //ax,ay,az
    static let hasGyro = IMUFlags(rawValue: 1 << 2) //gx,gy,gz
    static let hasMag = IMUFlags(rawValue: 1 << 3) //mx, my, mz
    static let hasBaro = IMUFlags(rawValue: 1 << 4) //altitude/pressure
    static let hasQuat = IMUFlags(rawValue: 1 << 5) //qw, qx, qy, qz
}

struct IMUHeader {
    var magic: UInt32 //"IMUF"
    var version: UInt16 //1
    var flags: IMUFlags
    var timestampSeconds: Double
    var frameId: UInt32
    var payloadBytes: UInt32
    var crc32: UInt32
    
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
        append(timestampSeconds)
        append(frameId)
        append(payloadBytes)
        append(crc32)
        return out
    }
}
