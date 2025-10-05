import Cocoa
import AVFoundation

// MARK: - Utility Functions

extension TeslaCamViewController {
    func formatCameraName(_ name: String) -> String {
        switch name {
        case "front": return "Front"
        case "back": return "Back"
        case "left_pillar": return "Left Pillar"
        case "right_pillar": return "Right Pillar"
        case "left_repeater": return "Left Repeater"
        case "right_repeater": return "Right Repeater"
        default: return name
        }
    }
    
    func formatReason(_ reason: String) -> String {
        return reason
    }
    
    func formatTime(_ time: CMTime) -> String {
        let seconds = Int(CMTimeGetSeconds(time))
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    func showAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

