import Foundation

enum CameraAngle: String, CaseIterable, Identifiable {
    case front
    case back
    case leftPillar = "left_pillar"
    case leftRepeater = "left_repeater"
    case rightPillar = "right_pillar"
    case rightRepeater = "right_repeater"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .front: return "Front"
        case .back: return "Back"
        case .leftPillar: return "Left Pillar"
        case .leftRepeater: return "Left Repeater"
        case .rightPillar: return "Right Pillar"
        case .rightRepeater: return "Right Repeater"
        }
    }

    static var topRow: [CameraAngle] { [.leftPillar, .front, .rightPillar] }
    static var bottomRow: [CameraAngle] { [.leftRepeater, .back, .rightRepeater] }
}

struct EventInfo: Codable, Equatable {
    let timestamp: String?
    let city: String?
    let street: String?
    let est_lat: String?
    let est_lon: String?
    let reason: String?
    let camera: String?

    var eventDate: Date? {
        guard let timestamp else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: timestamp)
    }

    var reasonDisplayName: String {
        guard let reason else { return "Unknown" }
        return reason
            .replacingOccurrences(of: "user_interaction_", with: "")
            .replacingOccurrences(of: "dashcam_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

struct ClipSegment: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let videos: [CameraAngle: URL]
    let duration: TimeInterval

    var displayTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }

    static func == (lhs: ClipSegment, rhs: ClipSegment) -> Bool {
        lhs.id == rhs.id
    }
}

struct TeslaCamEvent: Identifiable, Equatable {
    let id = UUID()
    let folderURL: URL
    let eventInfo: EventInfo?
    let segments: [ClipSegment]
    let thumbURL: URL?

    var displayName: String {
        let name = folderURL.lastPathComponent
        if let eventInfo, let city = eventInfo.city, let street = eventInfo.street {
            return "\(name) - \(city) \(street)"
        }
        return name
    }

    var eventTimestamp: Date? {
        eventInfo?.eventDate
    }

    var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    var startTime: Date? {
        segments.first?.timestamp
    }

    static func == (lhs: TeslaCamEvent, rhs: TeslaCamEvent) -> Bool {
        lhs.id == rhs.id
    }
}

enum FolderType {
    case teslaCam
    case recentClips
    case savedClips
    case sentryClips
    case singleEvent
}
