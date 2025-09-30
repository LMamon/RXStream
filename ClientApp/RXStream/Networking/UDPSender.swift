// TODO: Add error handling for dropped/failed packets.
// TODO: Consider batching multiple sensor payloads into a single UDP datagram.

import Foundation
import Network

///simple UDP sender over NWConnection
class UDPSender: FrameProtocol {
    private var connection: NWConnection
    private var queue = DispatchQueue(label: "UDP Sender Queue")
    private let host: String
    private let port: UInt16
    
    ///host: IP string of your IP
    ///port: port number used on UDP server
    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
        let endpointHost = NWEndpoint.Host(host)
        let endpointPort = NWEndpoint.Port(rawValue: port)!
        connection = NWConnection(host: endpointHost, port: endpointPort, using: .udp)
        connection.stateUpdateHandler = { state in
                switch state {
                case .ready: print("UDP ready to \(host):\(port)")
                case .failed(let err): print("UDP failed: \(err)")
                default: break
                }
            }
        connection.start(queue: queue)
    }
    
    func send(data: Data) {
        print(" UDP queued \(data.count) bytes to \(host):\(port)")
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("UDP send error: \(error)")
            } else {
                print("UDP packet sent (\(data.count) bytes)")
            }
        })
    }
    
    deinit {
        connection.cancel()
    }
}
