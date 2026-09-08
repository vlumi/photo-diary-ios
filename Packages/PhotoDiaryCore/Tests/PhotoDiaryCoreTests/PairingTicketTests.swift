import Foundation
import XCTest

@testable import PhotoDiaryCore

final class PairingTicketTests: XCTestCase {
    func testParsesTheCanonicalLink() {
        let ticket = PairingTicket.parse(
            "photodiary://sso?host=photos.example.com&token=abc.def.ghi"
        )
        XCTAssertEqual(ticket, PairingTicket(host: "photos.example.com", token: "abc.def.ghi"))
        XCTAssertEqual(ticket?.origin, "https://photos.example.com")
    }

    func testTrimsWhitespaceAndLowercasesTheHost() {
        let ticket = PairingTicket.parse(
            "  photodiary://sso?host=Photos.Example.COM:8443&token=t \n"
        )
        XCTAssertEqual(ticket?.host, "photos.example.com:8443")
        XCTAssertEqual(ticket?.token, "t")
    }

    func testDecodesAPercentEncodedToken() {
        let url = URL(string: "photodiary://sso?host=h.example&token=a%2Bb%2Fc%3Dd")!
        XCTAssertEqual(PairingTicket.parse(url)?.token, "a+b/c=d")
    }

    func testRejectsOtherSchemesAndActions() {
        XCTAssertNil(PairingTicket.parse("https://sso?host=h.example&token=t"))
        XCTAssertNil(PairingTicket.parse("photodiary://open?host=h.example&token=t"))
        XCTAssertNil(PairingTicket.parse("photodiary-demo://sso?host=h.example&token=t"))
    }

    func testRejectsHostsThatAreNotBareHostnames() {
        for bad in [
            "https://evil.example", "evil.example/path", "user@evil.example",
            "evil.example:99999999", "evil example", "",
        ] {
            let encoded = bad.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            XCTAssertNil(
                PairingTicket.parse("photodiary://sso?host=\(encoded)&token=t"),
                "accepted host \(bad)"
            )
        }
    }

    func testSchemeHttpIsHonouredAndOthersRejected() {
        let dev = PairingTicket.parse("photodiary://sso?host=localhost:3000&token=t&scheme=http")
        XCTAssertEqual(dev?.scheme, "http")
        XCTAssertEqual(dev?.origin, "http://localhost:3000")
        let upper = PairingTicket.parse("photodiary://sso?host=h.example&token=t&scheme=HTTPS")
        XCTAssertEqual(upper?.scheme, "https")
        XCTAssertNil(PairingTicket.parse("photodiary://sso?host=h.example&token=t&scheme=ftp"))
    }

    func testRejectsMissingOrEmptyToken() {
        XCTAssertNil(PairingTicket.parse("photodiary://sso?host=h.example"))
        XCTAssertNil(PairingTicket.parse("photodiary://sso?host=h.example&token="))
    }

    func testRejectsGarbage() {
        XCTAssertNil(PairingTicket.parse("not a link"))
        XCTAssertNil(PairingTicket.parse(""))
    }
}
