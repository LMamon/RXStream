//  shared network interface for console
//
//   Exposes a Frame struct that holds:
//     - frameId (sender’s running counter)
//     - magic (sensor type: "DPTH", "RGBF", "IMUF")
//     - raw reassembled data (header + payload)
//     - crcOk flag
//     - valid flag
//
//  Note:
//  Protocol only deals with the transport/reassembly layer. It does not
//  parse Depth/RGB/IMU headers. That responsibility belongs to the
//  corresponding listener/decoder classes built on top of this API.

// TODO: open UDP socket and bind to port
// TODO: receive raw UDP packets
// TODO: provide helper functions for closing socket, errors, etc.

#pragma once

#include <cstdint>
#include <string>
#include <vector>
#include <unordered_map>


struct Frame {
    uint32_t frameId = 0;
    uint32_t magic = 0; // "DPTH", "RGBF", "IMUF"
    bool crcOk = false;
    std::vector<uint8_t> data; //full payload
    bool valid = false;
};

class Protocol { 
    public:
        explicit Protocol(uint16_t port);
        ~Protocol();

        Protocol(const Protocol&) = delete;
        Protocol& operator = (const Protocol&) = delete;
        Protocol(Protocol&&) noexcept;
        Protocol& operator = (Protocol&&) noexcept;

        //Blocking receive > returns a full reassembled frame
        Frame recvFrame();

        uint16_t port() const { return port_; }

    private:
        //internal helpers
        struct Reassembly {
            uint16_t totalChunks = 0;
            uint16_t received = 0;
            std::vector<std::vector<uint8_t>> chunks;
            size_t totalBytes = 0;
        };

        struct UdpChunkHeader {
                uint16_t magic;  //0xABCD
                uint8_t version;  //0X01
                uint32_t frameId;
                uint16_t chunkIndex;
                uint16_t totalChunks;
            } __attribute__((__packed__));
    
        int fd_; //socket fd
        uint16_t port_; //bound port

        std::unordered_map<uint32_t, Reassembly> frames_;

        //crc-32
        static uint32_t crc32_ieee(const uint8_t* data, size_t len);
};
