import Foundation
import Testing

@testable import PhotoDiaryCore

struct PairingTicketLocalTests {
    private func ticket(host: String, scheme: String) -> PairingTicket? {
        PairingTicket.parse("photodiary://sso?host=\(host)&token=t&scheme=\(scheme)")
    }

    @Test(arguments: [
        "localhost:3000", "photos.local", "nas", "192.168.1.20:8080", "10.0.0.5", "172.20.1.1",
        "127.0.0.1:3000", "169.254.3.4",
    ])
    func plainHttpReachesTheLocalNetwork(_ host: String) {
        #expect(ticket(host: host, scheme: "http")?.origin == "http://\(host)")
    }

    @Test(arguments: ["photos.example.com", "203.0.113.5", "172.32.0.1", "8.8.8.8:80"])
    func plainHttpStopsAtTheInternet(_ host: String) {
        #expect(ticket(host: host, scheme: "http") == nil)
        #expect(ticket(host: host, scheme: "https") != nil)
    }
}
