//  transport interface
//  Created by Louis Mamon on 6/6/25.

// TODO: Add a receive() API if TCP is extended to 2-way communication.


import Foundation

//interface for both UDP and TCP
protocol FrameProtocol {
    func send(data: Data)
}

enum NetworkProtocol: String, CaseIterable, Identifiable {
    case udp = "UDP"
    case tcp = "TCP"
    var id: String { rawValue }
}
