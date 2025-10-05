import Foundation
import AVFoundation

// MARK: - Data Models

struct EventInfo: Codable {
    let timestamp: String?
    let city: String?
    let est_lat: String?
    let est_lon: String?
    let reason: String?
    let camera: String?
}

struct VideoSegment {
    let timestamp: Date
    let url: URL
    let duration: CMTime
}

class CameraView {
    let name: String
    let segments: [VideoSegment]
    var totalDuration: CMTime {
        segments.reduce(CMTime.zero) { $0 + $1.duration }
    }
    
    init(name: String, segments: [VideoSegment]) {
        self.name = name
        self.segments = segments
    }
    
    func segmentIndex(for time: CMTime) -> (index: Int, offset: CMTime) {
        var accumulatedTime = CMTime.zero
        for (index, segment) in segments.enumerated() {
            let nextTime = accumulatedTime + segment.duration
            if time < nextTime {
                return (index, time - accumulatedTime)
            }
            accumulatedTime = nextTime
        }
        // Return last segment if time exceeds total duration
        let lastIndex = max(0, segments.count - 1)
        return (lastIndex, segments.isEmpty ? .zero : time - (totalDuration - segments[lastIndex].duration))
    }
}

