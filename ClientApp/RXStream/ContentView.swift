// TODO: Validate IP/port input fields (disallow invalid addresses).
// TODO: Add UI toggle for FeaturePoints when encoder is implemented.
// TODO: Persist last-used IP/ports and toggles in UserDefaults.

import ARKit
import RealityKit
import SwiftUI
import UIKit


extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ContentView: View {
    @State private var ipAddress = ""
    @State private var udpPort: Int? = nil
    @State private var tcpPort: Int? = nil
    
    @State private var sendDepth = false
    @State private var sendRGB = false
    @State private var sendIMU = false
    
    @State private var showRGBPreview = false
    @State private var isStreaming = false
    
    private var isValidConfig: Bool {
        !ipAddress.isEmpty && (udpPort ?? 0) > 0 && (tcpPort ?? 0) > 0
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                //top preview
                ZStack {
                        ARViewContainer(destinationIP: ipAddress,
                                        destinationPort: UInt16(udpPort ?? 0),
                                        tcpPort: UInt16(tcpPort ?? 0),
                                        sendDepth: $sendDepth,
                                        sendRGB: $sendRGB,
                                        sendIMU: $sendIMU,
                                        isStreaming: $isStreaming,
                                        showRGBPreview: $showRGBPreview)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                if !isValidConfig {
                    VStack {
                        Text("Enter IP + Ports, then press Start Streaming")
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.black.opacity(0.6))
                                    .blur(radius: 1)
                            )
                            .padding(.top, 12)
                            .transition(.opacity)
                            .animation(.easeInOut, value: isValidConfig)
                        Spacer()
                    }
                }
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showRGBPreview.toggle() }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .padding(10)
                                .background(.black.opacity(0.6))
                                .clipShape(Circle())
                                .foregroundStyle(.white)
                        }
                        .padding()
                    }
                        Spacer()
                    
                    }
                }
                
                //bottom half
                VStack(spacing: 15) {
                    //toggles
                    Toggle("Depth", isOn: $sendDepth)
                    Toggle("RGB", isOn: $sendRGB)
                    Toggle("IMU", isOn: $sendIMU)
                    
                    //IP +ports
                    TextField("IP Address", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("UDP Port", value: $udpPort, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("TCP Port", value: $tcpPort, formatter: NumberFormatter())
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    //Start/End Button
                    Button(action: {
                        UIApplication.shared.endEditing()
                        isStreaming.toggle()
                    }) {
                        Text(isStreaming ? "End Streaming" : "Start Streaming")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isStreaming ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isValidConfig)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.endEditing()
        }
    }
}


//#Preview {
//    ContentView()
//}


