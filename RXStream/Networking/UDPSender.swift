//
//  UDPSender.swift
//  LiDARStream
//
//  Created by Louis Mamon on 6/6/25.
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

// TODO: Add error handling for dropped/failed packets.
// TODO: Consider batching multiple sensor payloads into a single UDP datagram.

import Foundation
import Network

///simple UDP sender over NWConnection
class UDPSender: FrameProtocol {
    private var connection: NWConnection
    private var queue = DispatchQueue(label: "UDP Sender Queue")
    
    ///host: IP string of your Mac
    ///port: port number you'll use on your Python UDP server
    init(host: String, port: UInt16) {
        let endpointHost = NWEndpoint.Host(host)
        let endpointPort = NWEndpoint.Port(rawValue: port)!
        connection = NWConnection(host: endpointHost, port: endpointPort, using: .udp)
        connection.start(queue: .main)
    }
    
    func send(data: Data) {
        connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                print("Error sending: \(error)")
            }
        })
    }
    
    deinit {
        connection.cancel()
    }
}
