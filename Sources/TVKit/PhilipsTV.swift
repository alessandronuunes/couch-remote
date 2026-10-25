import Foundation

/// A JointSPACE v1 key name, e.g. `VolumeUp`. Any key name the TV knows works.
public struct PhilipsKey: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public var description: String { rawValue }

    public static let standby = PhilipsKey("Standby")
    public static let up = PhilipsKey("CursorUp")
    public static let down = PhilipsKey("CursorDown")
    public static let left = PhilipsKey("CursorLeft")
    public static let right = PhilipsKey("CursorRight")
    public static let confirm = PhilipsKey("Confirm")
    public static let back = PhilipsKey("Back")
    public static let home = PhilipsKey("Home")
    public static let info = PhilipsKey("Info")
    public static let options = PhilipsKey("Options")
    public static let adjust = PhilipsKey("Adjust")
    public static let source = PhilipsKey("Source")
    public static let watchTV = PhilipsKey("WatchTV")
    public static let playPause = PhilipsKey("PlayPause")
    public static let pause = PhilipsKey("Pause")
    public static let stop = PhilipsKey("Stop")
    public static let volumeUp = PhilipsKey("VolumeUp")
    public static let volumeDown = PhilipsKey("VolumeDown")
    public static let mute = PhilipsKey("Mute")
    public static let channelUp = PhilipsKey("ChannelStepUp")
    public static let channelDown = PhilipsKey("ChannelStepDown")

    public static func digit(_ n: Int) -> PhilipsKey { PhilipsKey("Digit\(n)") }

    /// The Philips key for a Samsung remote key, so one remote layout drives both TVs.
    /// `nil` when Philips has no equivalent (HDMI shortcuts, for example).
    public init?(_ key: RemoteKey) {
        if let mapped = Self.fromSamsung[key] {
            self = mapped
            return
        }
        let raw = key.rawValue
        guard raw.count == 5, raw.hasPrefix("KEY_"), let n = Int(raw.dropFirst(4)) else { return nil }
        self = .digit(n)
    }

    private static let fromSamsung: [RemoteKey: PhilipsKey] = [
        .power: .standby,
        .up: .up,
        .down: .down,
        .left: .left,
        .right: .right,
        .enter: .confirm,
        .back: .back,
        .home: .home,
        .info: .info,
        .play: .playPause,
        .pause: .pause,
        .volumeUp: .volumeUp,
        .volumeDown: .volumeDown,
        .mute: .mute,
        .channelUp: .channelUp,
        .channelDown: .channelDown,
        .source: .source,
        .tv: .watchTV,
    ]
}

/// What a Philips TV says about itself at `GET http://<tv>:1925/1/system`.
public struct PhilipsSystemInfo: Decodable, Sendable, Equatable {
    public var name: String
    public var country: String?
    public var netTVVersion: String?

    enum CodingKeys: String, CodingKey {
        case name, country
        case netTVVersion = "nettvversion"
    }
}

/// `GET /1/audio/volume`. The range is the TV's own; it is 0–60 on NetTV sets from 2015.
public struct PhilipsVolume: Codable, Sendable, Equatable {
    public var current: Int
    public var min: Int
    public var max: Int
    public var muted: Bool
}

/// One input from `GET /1/sources`, e.g. `hdmi1` / "HDMI 1".
public struct PhilipsSource: Sendable, Equatable, Identifiable {
    public var id: String
    public var name: String
}

/// A Philips NetTV set (roughly 2011–2016, before Android TV) over JointSPACE v1: plain HTTP on port 1925,
/// no pairing.
///
/// The TV answers 200 to every key, even ones it ignores, and in standby it drops off the network
/// (it does not answer Wake-on-LAN), so it can be switched off from here but not on.
public struct PhilipsTV: Sendable {
    public let host: String

    public init(host: String) { self.host = host }

    public func info() async throws -> PhilipsSystemInfo {
        try JSONDecoder().decode(PhilipsSystemInfo.self, from: try await get("system"))
    }

    public func press(_ key: PhilipsKey) async throws {
        try await post("input/key", ["key": key.rawValue])
    }

    public func volume() async throws -> PhilipsVolume {
        try JSONDecoder().decode(PhilipsVolume.self, from: try await get("audio/volume"))
    }

    public func setVolume(_ volume: Int) async throws {
        try await post("audio/volume", ["muted": false, "current": max(0, volume)])
    }

    /// The TV wants the volume alongside the mute flag, so this reads it first.
    public func setMuted(_ muted: Bool) async throws {
        let current = try await volume().current
        try await post("audio/volume", ["muted": muted, "current": current])
    }

    /// Inputs sorted by name. The list is what the TV supports, not what is plugged in.
    public func sources() async throws -> [PhilipsSource] {
        try Self.sources(from: try await get("sources"))
    }

    /// `nil` while the TV is showing something that is not an input, such as its Smart TV portal.
    public func currentSource() async throws -> String? {
        let current = try JSONDecoder().decode([String: String].self, from: try await get("sources/current"))
        return current["id"].flatMap { $0 == "unknown" ? nil : $0 }
    }

    public func setSource(_ id: String) async throws {
        try await post("sources/current", ["id": id])
    }

    static func sources(from data: Data) throws -> [PhilipsSource] {
        try JSONDecoder().decode([String: [String: String]].self, from: data)
            .compactMap { id, fields in fields["name"].map { PhilipsSource(id: id, name: $0) } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func url(_ path: String) throws -> URL {
        guard let url = URL(string: "http://\(host):1925/1/\(path)") else { throw URLError(.badURL) }
        return url
    }

    private func get(_ path: String) async throws -> Data {
        let (data, response) = try await TVRest.session.data(from: try url(path))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return data
    }

    private func post(_ path: String, _ body: [String: any Sendable]) async throws {
        var request = URLRequest(url: try url(path))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await TVRest.session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    }
}
