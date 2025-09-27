//  Convenience struct for decoded IMU values (for debugging or receiver use).
//  Created by Louis Mamon on 9/15/25.


import simd

struct IMUSample {
    var quat: simd_quatf? // attitude (optional if raw-only)
    var accel: SIMD3<Float>? // linear acceleration
    var gyro: SIMD3<Float>? // angular velocity
    var mag: SIMD3<Float>? // magnetic field
    var baro: Float? // altitude (m)
}
