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
