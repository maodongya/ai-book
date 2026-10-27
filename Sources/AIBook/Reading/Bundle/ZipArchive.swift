import Foundation

/// 仅存储（不压缩）的 ZIP。路径必须是相对路径，拒绝 `..`。
enum ZipArchive {
    enum Failure: Error {
        case unsafePath(String)
        case truncated
        case badSignature
    }

    /// 把若干相对路径打成 zip 字节。
    static func archive(files: [String: Data]) throws -> Data {
        let names = files.keys.sorted()
        for name in names {
            guard isSafePath(name) else { throw Failure.unsafePath(name) }
        }

        var local = Data()
        var central = Data()
        var entries: [(name: String, offset: UInt32, size: UInt32, crc: UInt32)] = []

        for name in names {
            let payload = files[name] ?? Data()
            let nameData = Data(name.utf8)
            let crc = crc32(payload)
            let offset = UInt32(local.count)
            let size = UInt32(payload.count)
            entries.append((name, offset, size, crc))

            appendUInt32(0x04034b50, to: &local)
            appendUInt16(20, to: &local)
            appendUInt16(0x0800, to: &local) // UTF-8 文件名
            appendUInt16(0, to: &local) // 存储
            appendUInt16(0, to: &local)
            appendUInt16(0, to: &local)
            appendUInt32(crc, to: &local)
            appendUInt32(size, to: &local)
            appendUInt32(size, to: &local)
            appendUInt16(UInt16(nameData.count), to: &local)
            appendUInt16(0, to: &local)
            local.append(nameData)
            local.append(payload)
        }

        let centralOffset = UInt32(local.count)
        for entry in entries {
            let nameData = Data(entry.name.utf8)
            appendUInt32(0x02014b50, to: &central)
            appendUInt16(20, to: &central)
            appendUInt16(20, to: &central)
            appendUInt16(0x0800, to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt32(entry.crc, to: &central)
            appendUInt32(entry.size, to: &central)
            appendUInt32(entry.size, to: &central)
            appendUInt16(UInt16(nameData.count), to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt16(0, to: &central)
            appendUInt32(0, to: &central)
            appendUInt32(entry.offset, to: &central)
            central.append(nameData)
        }

        var end = Data()
        appendUInt32(0x06054b50, to: &end)
        appendUInt16(0, to: &end)
        appendUInt16(0, to: &end)
        appendUInt16(UInt16(entries.count), to: &end)
        appendUInt16(UInt16(entries.count), to: &end)
        appendUInt32(UInt32(central.count), to: &end)
        appendUInt32(centralOffset, to: &end)
        appendUInt16(0, to: &end)

        var result = local
        result.append(central)
        result.append(end)
        return result
    }

    /// 读出 zip 内的文件。跳过目录项。
    static func extract(_ data: Data) throws -> [String: Data] {
        guard let eocd = findEndOfCentralDirectory(in: data) else { throw Failure.truncated }
        let count = Int(readUInt16(data, eocd + 10))
        let centralSize = Int(readUInt32(data, eocd + 12))
        let centralOffset = Int(readUInt32(data, eocd + 16))
        guard centralOffset >= 0, centralOffset + centralSize <= data.count else { throw Failure.truncated }

        var files: [String: Data] = [:]
        var cursor = centralOffset
        for _ in 0..<count {
            guard cursor + 46 <= data.count else { throw Failure.truncated }
            guard readUInt32(data, cursor) == 0x02014b50 else { throw Failure.badSignature }
            let method = readUInt16(data, cursor + 10)
            guard method == 0 else { throw Failure.badSignature }
            let compressed = Int(readUInt32(data, cursor + 20))
            let nameLength = Int(readUInt16(data, cursor + 28))
            let extraLength = Int(readUInt16(data, cursor + 30))
            let commentLength = Int(readUInt16(data, cursor + 32))
            let localOffset = Int(readUInt32(data, cursor + 42))
            let nameStart = cursor + 46
            guard nameStart + nameLength <= data.count else { throw Failure.truncated }
            let nameData = data.subdata(in: nameStart..<(nameStart + nameLength))
            guard let name = String(data: nameData, encoding: .utf8) else { throw Failure.unsafePath("") }
            guard isSafePath(name) || name.hasSuffix("/") else { throw Failure.unsafePath(name) }

            if !name.hasSuffix("/") {
                let payload = try readLocalPayload(data, offset: localOffset, expectedSize: compressed, name: name)
                files[name] = payload
            }
            cursor = nameStart + nameLength + extraLength + commentLength
        }
        return files
    }

    static func isSafePath(_ path: String) -> Bool {
        if path.isEmpty || path.hasPrefix("/") || path.contains("\\") { return false }
        if path.split(separator: "/").contains("..") { return false }
        return true
    }

    private static func readLocalPayload(_ data: Data, offset: Int, expectedSize: Int, name: String) throws -> Data {
        guard offset + 30 <= data.count else { throw Failure.truncated }
        guard readUInt32(data, offset) == 0x04034b50 else { throw Failure.badSignature }
        let nameLength = Int(readUInt16(data, offset + 26))
        let extraLength = Int(readUInt16(data, offset + 28))
        let start = offset + 30 + nameLength + extraLength
        let end = start + expectedSize
        guard start >= 0, end <= data.count else { throw Failure.truncated }
        let localName = data.subdata(in: (offset + 30)..<(offset + 30 + nameLength))
        guard String(data: localName, encoding: .utf8) == name else { throw Failure.unsafePath(name) }
        return data.subdata(in: start..<end)
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        let signature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
        guard data.count >= 22 else { return nil }
        let start = max(0, data.count - 22 - 65535)
        var index = data.count - 22
        while index >= start {
            if data[index] == signature[0],
               data[index + 1] == signature[1],
               data[index + 2] == signature[2],
               data[index + 3] == signature[3] {
                return index
            }
            if index == 0 { break }
            index -= 1
        }
        return nil
    }

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                let mask = 0 &- (crc & 1)
                crc = (crc >> 1) ^ (0xedb8_8320 & mask)
            }
        }
        return crc ^ 0xffff_ffff
    }

    private static func appendUInt16(_ value: UInt16, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { data.append(contentsOf: $0) }
    }

    private static func readUInt16(_ data: Data, _ offset: Int) -> UInt16 {
        let raw = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        return UInt16(littleEndian: raw)
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32 {
        let raw = UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
        return UInt32(littleEndian: raw)
    }
}
