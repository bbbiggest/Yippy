/// Escapes UTF-8 text while preserving URI syntax and existing percent escapes.
enum URLEncoding {
    private static let allowedBytes = Set(
        ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789" +
         "-._~:/?#[]@!$&'()*+,;=").utf8
    )
    private static let hexDigits = Array("0123456789ABCDEF".utf8)

    static func encode(_ text: String) -> String {
        let bytes = Array(text.utf8)
        var encoded = [UInt8]()
        encoded.reserveCapacity(bytes.count)
        var index = 0

        while index < bytes.count {
            let byte = bytes[index]
            // Preserve escapes before encoding literal percent signs, including
            // when escaped and readable characters appear in the same input.
            if byte == 0x25, index + 2 < bytes.count,
                isHexDigit(bytes[index + 1]), isHexDigit(bytes[index + 2]) {
                encoded.append(contentsOf: bytes[index...index + 2])
                index += 3
                continue
            }

            if allowedBytes.contains(byte) {
                encoded.append(byte)
            } else {
                encoded.append(0x25)
                encoded.append(hexDigits[Int(byte >> 4)])
                encoded.append(hexDigits[Int(byte & 0x0F)])
            }
            index += 1
        }

        return String(decoding: encoded, as: UTF8.self)
    }

    private static func isHexDigit(_ byte: UInt8) -> Bool {
        switch byte {
        case 0x30...0x39, 0x41...0x46, 0x61...0x66: return true
        default: return false
        }
    }
}
