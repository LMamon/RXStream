//  Returns a Frame object containing:
//     - frameId (incremented on sender side)
//     - magic ("DPTH", "RGBF", or "IMUF")
//     - raw reassembled data (header + payload)
//     - crcOk flag to indicate integrity check result
//
//  This class does not interpret Depth/RGB/IMU headers itself.
//  Higher-level listeners/decoders (DepthListener, RGBListener, IMUListener)
//  will consume Frame objects and handle sensor-specific parsing.

#include "Protocol.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstring>
#include <iostream>

static constexpr uint16_t UDP_CHUNK_MAGIC = 0xABCD;
static constexpr uint8_t UDP_CHUNK_VERSION = 0x01;
static constexpr size_t MAX_UDP_PACKET = 65507;
static constexpr uint16_t MAX_CHUNKS = 8192;
static constexpr size_t MAX_FRAMES_BYTES = 64 * 1024 * 1024; // 64MB


//crc32 ieee
uint32_t Protocol::crc32_ieee(const uint8_t* data, size_t len) {
    static uint32_t table[256];
    static bool init = false;
    if (!init) {
        for (uint32_t i = 0; i < 256; ++i) {
            uint32_t c = i;
            for (int k =0; k < 8; ++k) {
                c = (c & 1) ? (0xEDB88320U ^ (c >> 1)) : (c >> 1);
            }
            table[i] = c;
        }
        init = true;
    }
    uint32_t crc = 0xFFFFFFFFU;
    for (size_t i = 0; i < len; ++i) {
        uint8_t idx = (crc ^ data[i]) & 0xFFU;
        crc = table[idx] ^ (crc >> 8);
    }
    return crc ^ 0xFFFFFFFFU;
}
 
//ctor/dtor
Protocol::Protocol(uint16_t port) : fd_(-1), port_(port) {
    fd_ = ::socket(AF_INET, SOCK_DGRAM, 0);
    if (fd_ < 0) {
        perror("socket");
        throw std::runtime_error("failed to create socket");
    }
    int yes = 1;
    ::setsockopt(fd_, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (::bind(fd_, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        perror("bind");
        ::close(fd_);
        throw std::runtime_error("Failed to bind UDP port");
    }
    std::cout <<"[Protocol] listening on UDP port " << port << std::endl;
}

Protocol::~Protocol() {
    if (fd_ >= 0) {
        ::close(fd_);
    }
}

Protocol::Protocol(Protocol&& other) noexcept {
    fd_ = other.fd_;
    port_ = other.port_;
    frames_ = std::move(other.frames_);
    other.fd_ = -1;
}

Protocol& Protocol::operator=(Protocol&& other) noexcept {
    if (this != &other) {
        if (fd_ >= 0) ::close(fd_);
        fd_ = other.fd_;
        port_ = other.port_;
        frames_ = std::move(other.frames_);
        other.fd_ = -1;
    }
    return *this;
}

// recvFrame (blocking)
Frame Protocol::recvFrame() {
    std::vector<uint8_t> buf(MAX_UDP_PACKET);
    
    while (true) {
        sockaddr_in src{};
        socklen_t slen = sizeof(src);
        ssize_t n = :: recvfrom(fd_, 
                                buf.data(),
                                buf.size(), 
                                0,
                                reinterpret_cast<sockaddr*>(&src),
                                &slen);

        if (n < 0) {
            perror("recvfrom");
            return {};
        }
        if (n < sizeof(UdpChunkHeader)) {
            std::cerr << "[WARN] Short packet (" << n << " bytes)" << std::endl;
            continue;
        }

        //parsing header
        UdpChunkHeader hdr{};
        std::memcpy(&hdr, buf.data(), sizeof(hdr));

        if (hdr.magic != UDP_CHUNK_MAGIC || hdr.version != UDP_CHUNK_VERSION) {
            std::cerr << "[WARN] Bad UDP chunk header" << std::endl;
            continue;
        }
        if (hdr.totalChunks == 0 || hdr.totalChunks > MAX_CHUNKS) {
            std::cerr << "[WARN] Invalid totalChunks=" << hdr.totalChunks << std::endl;
            continue;
        }
        const uint8_t* payload = buf.data() +sizeof(UdpChunkHeader);
        const size_t payloadLen = n - sizeof(UdpChunkHeader);

        //insert into reassembly map
        auto& r = frames_[hdr.frameId];
        if (r.totalChunks == 0) {
            r.totalChunks = hdr.totalChunks;
            r.chunks.resize(hdr.totalChunks);
            r.received = 0;
            r.totalBytes = 0;
        }

        if (hdr.chunkIndex >= r.totalChunks) {
            std::cerr << "[WARN] Bad chunk Index=" << hdr.chunkIndex << std::endl;
            continue;
        }
        if (!r.chunks[hdr.chunkIndex].empty()) {
            continue; // duplicate
        }

        r.chunks[hdr.chunkIndex].assign(payload, payload + payloadLen);
        r.received++;
        r.totalBytes += payloadLen;

        if (r.received == r.totalChunks) { //assemble full frame
            if(r.totalBytes > MAX_FRAMES_BYTES) {
                std::cerr << "[WARN] Frame too large, dropping." << std::endl;
                frames_.erase(hdr.frameId);
                continue;
            }
            std::vector<uint8_t> whole;
            whole.reserve(r.totalBytes);
            for (uint16_t i = 0; i < r.totalChunks; ++i) {
                whole.insert(whole.end(), r.chunks[i].begin(), r.chunks[i].end());
            }

            //build frame object
            Frame f;
            f.frameId = hdr.frameId;
            f.valid = true;
            f.data = std::move(whole);

            if (f.data.size() >= 4) {
                std::memcpy(&f.magic, f.data.data(), 4);
            }

            //crc check: last 4bytes of header contain crc
            if (f.data.size() > 4) {
                uint32_t crcHdr = 0;
                std::memcpy(&crcHdr, f.data.data() + f.data.size() -4, 4);

                uint32_t crc = crc32_ieee(f.data.data(), f.data.size() - 4);
                f.crcOk = (crc == crcHdr);
            }

            frames_.erase(hdr.frameId);
            return f;
        }
    }
}
