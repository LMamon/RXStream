// TODO: Implement TCP receive loop for console > iPhone control commands.
// TODO: Define a structured control protocol (JSON or simple key=value).

import Foundation
import Network

//conforms to depthsender to enable swapping UCP/TCP
class TCPSender: FrameProtocol {
    private var connection: NWConnection
    private var queue = DispatchQueue(label: "TCP Sender Queue")
    private let host: String
    private let port: UInt16
    
    ///host: IP string of your console
    ///port: port number used on UDP server
    init (host: String, port: UInt16) {
        self.host = host
        self.port = port
        let nwHost = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        connection = NWConnection(host: nwHost, port: nwPort, using: .tcp)
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                print("TCP ready to \(host):\(port)")
            case .failed(let err):
                print("TCP failed to connect to \(host):\(port) with error \(err)")
            default:
                break
            }
        }
        connection.start(queue: queue)
    }
    
    func send(data: Data) {
        print(" TCP queued \(data.count) bytes to \(host):\(port)")
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("TCP send error: \(error)")
            } else {
                print("TCP packet sent (\(data.count) bytes)")
            }
        })
    }
    
    deinit{
        connection.cancel()
    }
}
