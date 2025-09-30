// TODO: Implement TCP receive loop for runtime sensor toggling (RGB/Depth/IMU).
// TODO: Add optional FeaturePoints encoder & toggle.
// TODO: Consider using Metal for efficient RGB/Depth preview rendering.
// TODO: Clean up duplicated session config (frameSemantics set twice).

import SwiftUI
import ARKit
import UIKit
import Network
import CoreImage

struct ARViewContainer: UIViewRepresentable {
    let destinationIP: String
    let destinationPort: UInt16
    let tcpPort: UInt16
    
    @Binding var sendDepth: Bool
    @Binding var sendRGB: Bool
    @Binding var sendIMU: Bool
    @Binding var isStreaming: Bool
    @Binding var showRGBPreview: Bool
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.session.delegate = context.coordinator
        arView.automaticallyUpdatesLighting = false
        arView.autoenablesDefaultLighting = false
        
        //configure AR session
        let config = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
    
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
        
        //store CI context + overlay view
        context.coordinator.ciContext = CIContext()
        context.coordinator.overlayView = UIImageView(frame: arView.bounds)
        context.coordinator.overlayView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.addSubview(context.coordinator.overlayView!)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.sendDepth = sendDepth && isStreaming
        context.coordinator.sendRGB = sendRGB && isStreaming
        context.coordinator.sendIMU = sendIMU && isStreaming
        context.coordinator.isStreaming = isStreaming
        
    
        context.coordinator.previewDepth = sendDepth
        context.coordinator.previewRGB = sendRGB
        //context.coordinator.previewMode = showRGBPreview ? .rgb : .depth
        
        if !sendDepth && !sendRGB {
                context.coordinator.previewMode = .none
            } else if sendRGB && sendDepth {
                context.coordinator.previewMode = showRGBPreview ? .rgb : .depth
            } else if sendRGB {
                context.coordinator.previewMode = .rgb
            } else if sendDepth {
                context.coordinator.previewMode = .depth
            }
        
        if isStreaming, !destinationIP.isEmpty {
                context.coordinator.updateConnection(
                    ip: destinationIP,
                    udpPort: destinationPort,
                    tcpPort: tcpPort
                )
            }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(ip: destinationIP,
                           udpPort: destinationPort,
                           tcpPort: tcpPort)
    }
    
    enum PreviewMode {
        case rgb
        case depth
        case none
    }
    
    class Coordinator: NSObject, ARSessionDelegate {
        
        private var udpSender: FrameProtocol?
        private var tcpSender: FrameProtocol?
        
        //encoders
        private let depthEncoder = DepthEncoder()
        private let rgbEncoder = RGBEncoder(jpegQuality: 0.7)
        private let imuEncoder = IMUEncoder()
        private let encodeQueue = DispatchQueue(label: "rx.encode.queue", qos: .userInitiated)
        private var isEncoding = false
        private var hasPrintedDidUpdate = false
        
        var sendDepth = false
        var sendRGB = false
        var sendIMU = false
        var isStreaming = false
        
        //preview handling
        var previewDepth = false
        var previewRGB = false
        var previewMode: PreviewMode = .none
        var ciContext: CIContext?
        var overlayView: UIImageView?
        
        //initialize with user input
        init(ip: String, udpPort: UInt16, tcpPort: UInt16) {
            super.init()
            if !ip.isEmpty && udpPort > 0 {
                    self.udpSender = UDPSender(host: ip, port: udpPort)
                }
                if !ip.isEmpty && tcpPort > 0 {
                    self.tcpSender = TCPSender(host: ip, port: tcpPort)
                }
        }
        
        func updateConnection(ip: String, udpPort: UInt16, tcpPort: UInt16) {
            if udpPort > 0 {
                self.udpSender = UDPSender(host: ip, port: udpPort)
            }
            if tcpPort > 0 {
                self.tcpSender = TCPSender(host: ip, port: tcpPort)
            }
        }
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            if !hasPrintedDidUpdate {
                        print("ARSession didUpdate called")
                    hasPrintedDidUpdate = true
            }
            
            guard !isEncoding else { return }
            isEncoding = true

            //extract what we need immediately
            let depthMap = frame.sceneDepth?.depthMap
            let confidenceMap = frame.sceneDepth?.confidenceMap
            let timestamp = frame.timestamp
            let intrinsics = frame.camera.intrinsics
            let transform = frame.camera.transform
            let capturedImage = frame.capturedImage
            
            
            encodeQueue.async { [weak self] in
                guard let self = self else { return }
                defer { self.isEncoding = false }

            // Depth
            if self.sendDepth, let dm = depthMap {
                    if let depthEncoded = self.depthEncoder.makePacket(
                        depthMap: dm,
                        confidenceMap: confidenceMap,
                        timestamp: timestamp,
                        intrinsics: intrinsics,
                        cameraTransform: transform
                    ) {
                        self.sendFrameUDP(depthEncoded.data, frameId: depthEncoded.frameId)
                        print("Depth frame \(depthEncoded.frameId) sent (\(CVPixelBufferGetWidth(dm))×\(CVPixelBufferGetHeight(dm)))")
                    }
                }

                // RGB
                if self.sendRGB {
                        if let rgbEncoded = self.rgbEncoder.makePacket(
                            capturedImage: capturedImage,
                            timestamp: timestamp
                        ) {
                            self.sendFrameUDP(rgbEncoded.data, frameId: 0)
                            print("RGB frame \(rgbEncoded.frameId) sent (\(CVPixelBufferGetWidth(capturedImage))×\(CVPixelBufferGetHeight(capturedImage)))")
                        }
                    }

                // IMU
                if self.sendIMU {
                    imuEncoder.start()
                    if let imuEncoded = self.imuEncoder.makePacket() {
                        self.sendFrameUDP(imuEncoded.data, frameId: imuEncoded.frameId)
                        print("IMU sent (frameId: \(imuEncoded.frameId))")
                    }
                } else {
                    imuEncoder.stop()
                }
                
            }

            //update preview on UI thread
            updatePreview(depthMap: depthMap, capturedImage: capturedImage)
        }
        
        //MARK: preview helper
        private func updatePreview(depthMap: CVPixelBuffer?, capturedImage: CVPixelBuffer) {
            switch previewMode {
                case .rgb:
                    showRGBPreview(from: capturedImage)
                case .depth:
                    if let dm = depthMap {
                        showDepthPreview(from: dm)
                    } else {
                        showBlankPreview()
                    }
                case .none:
                    showBlankPreview()
            }
        }
        
        
        
        //MARK: UDP frame transmitter
        
        private func sendFrameUDP(_ data: Data, frameId: UInt32) {
            guard isStreaming else { return }
            for chunk in UdpChunk.makeChunks(frameId: frameId,
                                             payload: data,
                                             maxUDPPayload: 1400) {
                udpSender?.send(data: chunk)
            }
        }
        
        //MARK: TCP control channel
        func sendControlMessage(_ message: String) {
            guard isStreaming,
                  let data = message.data(using: .utf8) else { return }
            tcpSender?.send(data: data)
        }
        
        // MARK: - Preview helpers
        private func showRGBPreview(from capturedImage: CVPixelBuffer) {
            let ci = ciContext ?? CIContext() // reuse if available
                let ciImage = CIImage(cvPixelBuffer: capturedImage)
                if let cgImage = ci.createCGImage(ciImage, from: ciImage.extent) {
                    DispatchQueue.main.async {
                        self.overlayView?.image = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
                        self.overlayView?.isHidden = false
                        self.overlayView?.backgroundColor = .clear
                    }
            }
        }
        
        private func showDepthPreview(from depthMap: CVPixelBuffer) {
            if let cgImage = makeGrayscaleImage(from: depthMap) {
                
                    DispatchQueue.main.async {
                        self.overlayView?.isHidden = false
                        self.overlayView?.backgroundColor = .clear
                        self.overlayView?.image = UIImage(cgImage: cgImage)
                    }
            }
        }
        
        public func showBlankPreview() {
            DispatchQueue.main.async {
                self.overlayView?.isHidden = true
                self.overlayView?.backgroundColor = .clear
                self.overlayView?.image = nil
            }
       }
        
        
        //MARK: depth > grayscale CIImage
        private func makeGrayscaleImage(from depthMap: CVPixelBuffer) -> CGImage? {
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
            
            let rawDepth = CIImage(cvPixelBuffer: depthMap)
            
            let minDepth: CGFloat = 0.1
            let maxDepth: CGFloat = 10.0
            let scale = 1.0 / (maxDepth - minDepth)
            let bias = -minDepth * scale
            
            let normalized = rawDepth.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: scale,
                                            y: 0,
                                            z: 0,
                                            w: 0),
                    "inputGVector": CIVector(x: 0,
                                             y: scale,
                                             z: 0,
                                             w: 0),
                     "inputBVector": CIVector(x: 0,
                                              y: 0,
                                              z: scale,
                                              w: 0),
                    "inputAVector": CIVector(x: 0,
                                             y: 0,
                                             z: 0,
                                             w: 1),
                    "inputBiasVector": CIVector(x: bias,
                                                y: bias,
                                                z: bias,
                                                w: 0)
                ])
            
            let grayscale = normalized.applyingFilter("CIColorControls", parameters: [
                                                                        kCIInputContrastKey: 1.0,
                                                                        kCIInputBrightnessKey: 0.0,
                                                                        kCIInputSaturationKey: 0.0
                ])
                .oriented(.right)
            
            return ciContext?.createCGImage(grayscale, from: grayscale.extent)
        }
    }
}
