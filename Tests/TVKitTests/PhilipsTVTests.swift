import XCTest

@testable import TVKit

final class PhilipsTVTests: XCTestCase {
    func testSystemInfoDecodesRealResponse() throws {
        let json = """
            {"menulanguage": "Unknown", "name": "PHILIPS TV", "country": "Brazil",
            "model_encrypted": "K2kseVsmQFgkd15gKkJ+ah9AT1L+aiZ4FZOpbufZqx4=", "nettvversion": "4.4.2",
            "epgsource": "broadcast"}
            """
        let info = try JSONDecoder().decode(PhilipsSystemInfo.self, from: Data(json.utf8))
        XCTAssertEqual(info.name, "PHILIPS TV")
        XCTAssertEqual(info.country, "Brazil")
        XCTAssertEqual(info.netTVVersion, "4.4.2")
    }

    func testVolumeDecodesRealResponse() throws {
        let json = #"{"muted": false, "current": 52, "min": 0, "max": 60}"#
        let volume = try JSONDecoder().decode(PhilipsVolume.self, from: Data(json.utf8))
        XCTAssertEqual(volume, PhilipsVolume(current: 52, min: 0, max: 60, muted: false))
    }

    func testSourcesAreSortedByName() throws {
        let json = """
            {"tv": {"name": "Watch TV"}, "hdmi2": {"name": "HDMI 2"}, "hdmi10": {"name": "HDMI 10"},
            "hdmi1": {"name": "HDMI 1"}, "vga": {"name": "VGA"}, "broken": {}}
            """
        let sources = try PhilipsTV.sources(from: Data(json.utf8))
        XCTAssertEqual(sources.map(\.id), ["hdmi1", "hdmi2", "hdmi10", "vga", "tv"])
        XCTAssertEqual(sources.first?.name, "HDMI 1")
    }

    func testSamsungKeysMapToPhilipsKeys() {
        XCTAssertEqual(PhilipsKey(.enter), .confirm)
        XCTAssertEqual(PhilipsKey(.power), .standby)
        XCTAssertEqual(PhilipsKey(.volumeUp)?.rawValue, "VolumeUp")
        XCTAssertEqual(PhilipsKey(.channelDown)?.rawValue, "ChannelStepDown")
        XCTAssertEqual(PhilipsKey(.digit(7))?.rawValue, "Digit7")
        XCTAssertNil(PhilipsKey(.hdmi(1)))
        XCTAssertNil(PhilipsKey(RemoteKey("KEY_UNKNOWN")))
    }
}
