import XCTest
@testable import Yippy

class URLEncodingTests: XCTestCase {
    func testEncodesWebDatabaseLinksAndPlainText() {
        let examples = [
            ("https://example.com/中文", "https://example.com/%E4%B8%AD%E6%96%87"),
            ("postgresql://db.example/库 名?sslmode=require",
             "postgresql://db.example/%E5%BA%93%20%E5%90%8D?sslmode=require"),
            ("jdbc:mysql://db.example/库", "jdbc:mysql://db.example/%E5%BA%93"),
            ("hello world", "hello%20world"),
            ("", "")
        ]
        for (input, expected) in examples {
            XCTAssertEqual(URLEncoding.encode(input), expected)
        }
    }

    func testPreservesURISyntaxAndPlus() {
        let syntax = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~:/?#[]@!$&'()*+,;="
        XCTAssertEqual(URLEncoding.encode(syntax), syntax)
        XCTAssertEqual(URLEncoding.encode("https://[::1]:8080/a b?q=1+2&x=y#z"),
                       "https://[::1]:8080/a%20b?q=1+2&x=y#z")
        XCTAssertEqual(URLEncoding.encode("\"<>\\^`{|}"), "%22%3C%3E%5C%5E%60%7B%7C%7D")
    }

    func testPreservesExistingEscapesInMixedText() {
        XCTAssertEqual(URLEncoding.encode("https://example.com/a%20b c?q=%2f+你#%E4%B8%AD文"),
                       "https://example.com/a%20b%20c?q=%2f+%E4%BD%A0#%E4%B8%AD%E6%96%87")
        let escapedBytes = "%00%7f%80%FF%25%2520"
        XCTAssertEqual(URLEncoding.encode(escapedBytes), escapedBytes)
    }

    func testEncodesMalformedPercentSequences() {
        XCTAssertEqual(URLEncoding.encode("% %2 %GG %2G %%20 %aF"),
                       "%25%20%252%20%25GG%20%252G%20%25%20%20%aF")
        XCTAssertEqual(URLEncoding.encode("%E4%B8%AD/100%?ok=%20&bad=%GG#%20%"),
                       "%E4%B8%AD/100%25?ok=%20&bad=%25GG#%20%25")
    }

    func testEncodesWhitespaceWithoutTrimming() {
        XCTAssertEqual(URLEncoding.encode(" \tfirst\r\nsecond \n"),
                       "%20%09first%0D%0Asecond%20%0A")
        XCTAssertEqual(URLEncoding.encode("\u{00A0}\u{0000}\u{007F}"), "%C2%A0%00%7F")
    }

    func testEncodesUnicodeWithoutNormalization() {
        XCTAssertEqual(URLEncoding.encode("👋 café"), "%F0%9F%91%8B%20caf%C3%A9")
        XCTAssertEqual(URLEncoding.encode("cafe\u{0301}"), "cafe%CC%81")
        XCTAssertEqual(URLEncoding.encode("例子.测试"), "%E4%BE%8B%E5%AD%90.%E6%B5%8B%E8%AF%95")
    }

    func testEncodingIsIdempotent() {
        let inputs = [
            "https://example.com/a%20b c?q=%2f+你#%E4%B8%AD文",
            "postgresql://db.example/库 名?sslmode=require",
            "% %2 %GG %%20 %FF", "👋 cafe\u{0301}\r\n",
            String(decoding: Array(UInt8(0)...UInt8(127)), as: UTF8.self), ""
        ]
        for input in inputs {
            let encoded = URLEncoding.encode(input)
            XCTAssertEqual(URLEncoding.encode(encoded), encoded)
        }
    }
}
