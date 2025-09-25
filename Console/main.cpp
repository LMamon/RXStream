#include <iostream>
#include "Protocol.h"

int main() {
    std::cout << "RXConsole build successful" << std::endl;
    
    Protocol net(5000);
    while (true) { 
        Frame f = net.recvFrame();
        if (f.valid) std::cout << "Got frame " << f.frameId << " magic=" << f.magic << std::endl;
    }
    
    
    return 0;
}

