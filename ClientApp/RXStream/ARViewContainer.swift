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
        
        if sendDepth == false && sendRGB == false { context.coordinator.previewMode = .none
            } else if showRGBPreview {
                context.coordinator.previewMode = .rgb
            } else {
                context.coordinator.previewMode = .depth
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
        
        //Encoders
        private let depthEncoder = DepthEncoder()
        private let rgbEncoder = RGBEncoder(jpegQuality: 0.7)
        private let imuEncoder = IMUEncoder()
        
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
            self.udpSender = UDPSender(host: ip, port: udpPort)
            self.tcpSender = TCPSender(host: ip, port: tcpPort)
            
        }
        
        
        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            if isStreaming {
                //Depth
                if sendDepth, let depthEndoded = depthEncoder.makePacket(from: frame) {
                    sendFrameUDP(depthEndoded.data, frameId: depthEndoded.frameId)
                }
                
                //RGB
                if sendRGB, let rgbEncoded = rgbEncoder.makePacket(from: frame) {
                    sendFrameUDP(rgbEncoded.data, frameId: 0)
                }
                
                //IMU
                if sendIMU, let imuEncoded = imuEncoder.makePacket() {
                    sendFrameUDP(imuEncoded.data, frameId: imuEncoded.frameId)
                }
            }
            
            
            let rgbOn = previewRGB
            let depthOn = previewDepth
            
            //preview rendering
            switch previewMode {
            case .rgb:
                if rgbOn{
                    showRGBPreview()
                } else if depthOn {
                    self.showDepthPreview(from: frame)
                } else {
                    self.showBlankPreview()
                }
                
            case .depth:
                if depthOn {
                    self.showDepthPreview(from: frame)
                } else if rgbOn {
                    showRGBPreview()
                } else {
                    self.showBlankPreview()
                }
            case .none:
                showBlankPreview()
            }
        }
        
        
        //MARK: UDP frame transmitter
        
        private func sendFrameUDP(_ data: Data, frameId: UInt32) {
            for chunk in UdpChunk.makeChunks(frameId: frameId,
                                             payload: data,
                                             maxUDPPayload: 1400) {
                udpSender?.send(data: chunk)
            }
        }
        
        //MARK: TCP control channel
        func sendControlMessage(_ message: String) {
            guard let data = message.data(using: .utf8) else { return }
            tcpSender?.send(data: data)
        }
        
        // MARK: - Preview helpers
        private func showRGBPreview() {
            DispatchQueue.main.async {
                self.overlayView?.isHidden = false
                self.overlayView?.backgroundColor = .clear
                self.overlayView?.image = nil
            }
        }
        
        private func showDepthPreview(from frame: ARFrame) {
            if let depthMap = frame.sceneDepth?.depthMap,
                  let cgImage = makeGrayscaleImage(from: depthMap) {
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
