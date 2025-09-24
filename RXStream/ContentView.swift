//
//  ContentView.swift
//  LiDARStream
//
//  Created by Louis Mamon on 6/5/25.
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
    @State private var udpPort = ""
    @State private var tcpPort = ""
    
    @State private var sendDepth = false
    @State private var sendRGB = false
    @State private var sendIMU = false
    
    @State private var showRGBPreview = false
    @State private var isStreaming = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                //top preview
                ZStack(alignment: .topTrailing) {
                    ARViewContainer(destinationIP: ipAddress,
                                    destinationPort: UInt16(udpPort) ?? 0,
                                    tcpPort: UInt16(tcpPort) ?? 0,
                                    sendDepth: $sendDepth,
                                    sendRGB: $sendRGB,
                                    sendIMU: $sendIMU,
                                    isStreaming: $isStreaming,
                                    showRGBPreview: $showRGBPreview)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Button(action: { showRGBPreview.toggle() }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .padding(10)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                            .foregroundStyle(.white)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                
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
                    
                    TextField("UDP Port", text: $udpPort)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("TCP Port", text: $tcpPort)
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


