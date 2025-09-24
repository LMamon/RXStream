# Overview
RXStream turns your iPhone into a real-time sensor node.
It streams RGB, Depth(lidar sensor required), and IMU over UDP TCP using a lightweight custom packet format

Unlike MAVlink, RXStream is not a flight-control protocol. Instead its an interface designed for:
- Rapid prototyping of computer vision & SLAM pipelines
- Engineers who want sensor data without building a swift app or relying on the Apple app store.
- Students/researchers experimenting with parsing & receiving sensor packets in C/C++.

# Features
- Streams multiple sensor modalities:
  - RGB (camera frames, JPEG-compressed by default; raw BGRA optional)
  - Depth (per-pixel float32 map + optional confidence buffer)
  - IMU (quaternion, accelerometer, gyroscope, magnetometer, barometer)
- Low-latency UDP transport for high-rate sensor data
- Reliable TCP control channel for configs/commands (future 2-way support)
- Modular packet format (each sensor type has its own header schema, extensible for new sensors)
- Receiver-ready for integration with and CV/3D pipelines

# Architecture
- Client: collects sensor data > encodes into packets > streams over UDP > sends configs over TCP
- Server: listens on sockets > parses packets > feeds into pipeline

# Packet Format
Each sensor stream has its own stable wire format (header + payload).
Headers include width/height, pixel format, timestamps, frame IDs, and CRC-32 checksums.

## Header Schema:
- RGBHeader
  magic ("RGBF"), version, flags, width, height, bytesPerRow, pixelFormat, timestamp, frameId, payload size, crc32
- DepthHeader ￼
  magic ("DPTH"), version, flags, width, height, bytesPerRow, pixelFormat, timestamp, frameId, intrinsics (3×3), camera transform (4×4), payload sizes, crc32
- IMUHeader ￼
  magic ("IMUF"), version, flags, timestamp, frameId, payload size, crc32

# Getting Started
## Prerequisites
-Client (iOS app)
  - Xcode (to build and run on iPhone)
-Server (receiver)
  - cmake + g++/clang (Linux/MacOS)
  - OpenCV/Open3D optional for visualization

# Build + Run
1. Clone repo & open RXStream.xcodeproj in Xcode
2. Select your iPhone target > run

## Roadmap
- Add ARKit feature points stream alongside depth
- Implement 2-way TCP control
- Provide C++ parsing library for easy integration
- Python bindings for prototyping

## License
This project is licensed under the Apache License 2.0(LICENSE).
See [official text](https://www.apache.org/licenses/LICENSE-2.0) for details.

## Third-Party Dependencies
- Apple ARKit & CoreMotion Frameworks (Apple SDK license)
