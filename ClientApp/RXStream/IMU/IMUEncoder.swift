//  IMUEncoder.swift
//
//  Collects CoreMotion fused motion (quaternion, accel, gyro, mag) + barometer,
//  builds IMUHeader, computes CRC-32, and returns one Data packet ready for TCP/UDP.
//  Created by Louis Mamon on 9/14/25.

// TODO: Allow dynamic switching between fused/raw modes via TCP command.
// TODO: Add optional gravity vector and user acceleration split.

import Foundation
import CoreMotion
import simd

struct EncodedIMU {
    let frameId: UInt32
    let data: Data
}

enum IMUMode {
    case fused //uses CMDeviceMotion fused quaternion + accel + gyro + mag
    case rawSelected([IMUFlags]) //choose exactly which raw sensors to include
}


final class IMUEncoder {
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private var frameId: UInt32 = 0
    
    //storage for latest sensor values
    private var latestMotion: CMDeviceMotion?
    private var latestAltitude: Double = 0.0
    private let mode: IMUMode
    
    private var isRunning = false
    
    init(mode: IMUMode = .fused) {
        self.mode = mode

            motionManager.startDeviceMotionUpdates(to: .main) { motion, error in
                if let m = motion {
                    self.latestMotion = m
                    print("motion update received: \(m)")
                } else if let err = error {
                    print("motion error: \(err)")
                }
            }
    }
    
    //MARK: Control
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        //configure motion updates (fused, ~60Hz)
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion,
            _ in self?.latestMotion = motion
        }
        
        //Barometer if available
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                if let d = data {
                    //use pressure in kPa or altitude in meters
                    self?.latestAltitude = d.relativeAltitude.doubleValue
                }
            }
        }
    }

    
    func stop() {
        guard isRunning else { return }
        isRunning = false
        
        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
    }
    
    
    deinit {
        stop()
    }
    
    
    func makePacket() -> EncodedIMU? {
        guard let motion = latestMotion else { return nil }
        
        var payload = Data()
        var flags: IMUFlags = []
        
        switch mode {
        case .fused:
            //quaternion (fused attitude)
            let q = motion.attitude.quaternion
            let quatVals: [Float32] = [Float32(q.w), Float32(q.x), Float32(q.y), Float32(q.z)]
            payload.append(contentsOf: quatVals.withUnsafeBufferPointer {Data(buffer: $0) })
            flags.insert([.isFused, .hasQuat])
            
            //user acceleration
            let acc = motion.userAcceleration
            let accVals: [Float32] = [Float32(acc.x), Float32(acc.y), Float(acc.z)]
            payload.append(contentsOf: accVals.withUnsafeBufferPointer { Data(buffer: $0) })
            flags.insert(.hasAccel)
            
            //Gyro (rotation rate)
            let gyro = motion.rotationRate
            let gyroVals: [Float32] = [Float32(gyro.x), Float32(gyro.y), Float32(gyro.z)]
            payload.append(contentsOf: gyroVals.withUnsafeBufferPointer { Data(buffer: $0) })
            flags.insert(.hasGyro)
            
            //magnetic field
            let mag = motion.magneticField.field
            let magVals: [Float32] = [Float32(mag.x), Float32(mag.y), Float32(mag.z)]
            payload.append(contentsOf: magVals.withUnsafeBufferPointer { Data(buffer: $0) })
            flags.insert(.hasMag)
            
            //barometer
            let baroVals: [Float32] = [Float32(latestAltitude)]
            payload.append(contentsOf:  baroVals.withUnsafeBufferPointer { Data(buffer: $0) })
            flags.insert(.hasBaro)
        
        
        case .rawSelected(let requested):
            
            if requested.contains(.hasAccel) {
                let acc = motion.userAcceleration
                let accVals: [Float32] = [Float32(acc.x), Float32(acc.y), Float32(acc.z)]
                payload.append(contentsOf: accVals.withUnsafeBufferPointer { Data(buffer: $0) })
                flags.insert(.hasAccel)
            }
            
            if requested.contains(.hasGyro) {
                let gyro = motion.rotationRate
                let gyroVals: [Float32] = [Float32(gyro.x), Float32(gyro.y), Float32(gyro.z)]
                payload.append(contentsOf: gyroVals.withUnsafeBufferPointer { Data(buffer: $0) })
                flags.insert(.hasGyro)
            }
            
            if requested.contains(.hasMag) {
                let mag = motion.magneticField.field
                let magVals: [Float32] = [Float32(mag.x), Float32(mag.y), Float32(mag.z)]
                payload.append(contentsOf: magVals.withUnsafeBufferPointer { Data(buffer: $0) })
                flags.insert(.hasMag)
            }
            
            if requested.contains(.hasBaro) {
                let baroVals: [Float32] = [Float32(latestAltitude)]
                payload.append(contentsOf: baroVals.withUnsafeBufferPointer { Data(buffer: $0) })
                flags.insert(.hasBaro)
            }
        }
        //CRC
        let crc = CRC32.compute(payload)
        
        let header = IMUHeader(magic: IMUMagic.packet,
                               version: IMUWireVersion.current,
                               flags: flags,
                               timestampSeconds: motion.timestamp,
                               frameId: frameId,
                               payloadBytes: UInt32(payload.count),
                               crc32: crc)
        
        let fullData = header.toData() + payload
        let encoded = EncodedIMU(frameId: frameId, data: fullData)
        frameId &+= 1
        return encoded
    }
}

