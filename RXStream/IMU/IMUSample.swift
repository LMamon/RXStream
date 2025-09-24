//
//  IMUSample.swift
//  LiDARStream
//
//  Convenience struct for decoded IMU values (for debugging or receiver use).
//  Created by Louis Mamon on 9/15/25.
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

import simd

struct IMUSample {
    var quat: simd_quatf? // attitude (optional if raw-only)
    var accel: SIMD3<Float>? // linear acceleration
    var gyro: SIMD3<Float>? // angular velocity
    var mag: SIMD3<Float>? // magnetic field
    var baro: Float? // altitude (m)
}
