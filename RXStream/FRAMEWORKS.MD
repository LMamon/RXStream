##Core Motion
Accelerometer (linear acceleration, 3-axis)
Gyroscope (angular velocity, 3-axis)
Magnetometer (compass, 3-axis)
Barometer (air pressure → relative altitude)


##AVFoundation
Raw RGB camera frames (any resolution supported by the device)
Video capture pipelines (30/60/120 fps depending on sensor)

##ARKit
Camera intrinsics/extrinsics (ready to feed into CV/SLAM)
VIO poses (full 6-DoF trajectory in meters)
Scene depth maps (LiDAR or monocular depth, depending on device)
Point cloud from LiDAR scanner
Plane detection (horizontal/vertical surfaces)
Mesh reconstruction (if you enable ARMeshManager)ø
