// TODO: Implement TCP receive loop for console > iPhone control commands.
// TODO: Define a structured control protocol (JSON or simple key=value).

import Foundation
import Network

//conforms to depthsender to enable swapping UCP/TCP
class TCPSender: FrameProtocol {
    private var connection: NWConnection
    private var queue = DispatchQueue(label: "TCP Sender Queue")
    
    ///host: IP string of your Mac
    ///port: port number you'll use on your Python UDP server
    init (host: String, port: UInt16) {
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
        connection.start(queue:queue)
    }
    
    func send(data: Data) {
        connection.send(content: data, completion: .contentProcessed{error in
            if let err = error {
                print("TCP send failed: \(err)")
            }
        })
    }
    
    deinit{
        connection.cancel()
    }
}
