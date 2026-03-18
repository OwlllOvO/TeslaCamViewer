import SwiftUI

struct SidebarView: View {
    let events: [TeslaCamEvent]
    @Binding var selectedEvent: TeslaCamEvent?
    let isLoading: Bool

    private var hasSections: Bool {
        events.contains { $0.sourceFolder != nil }
    }

    private var groupedEvents: [(String, [TeslaCamEvent])] {
        var groups: [(String, [TeslaCamEvent])] = []
        var current: (String, [TeslaCamEvent])?

        for event in events {
            let key = event.sourceFolder ?? ""
            if let c = current, c.0 == key {
                current!.1.append(event)
            } else {
                if let c = current {
                    groups.append(c)
                }
                current = (key, [event])
            }
        }
        if let c = current {
            groups.append(c)
        }
        return groups
    }

    var body: some View {
        List(selection: Binding<TeslaCamEvent.ID?>(
            get: { selectedEvent?.id },
            set: { newID in
                selectedEvent = events.first { $0.id == newID }
            }
        )) {
            if isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning…")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if events.isEmpty && !isLoading {
                ContentUnavailableView {
                    Label("No Events", systemImage: "video.slash")
                } description: {
                    Text("Open a TeslaCam folder to view recordings.")
                }
            }

            if hasSections {
                ForEach(groupedEvents, id: \.0) { sectionName, sectionEvents in
                    Section(sectionName) {
                        ForEach(sectionEvents) { event in
                            EventRow(event: event)
                                .tag(event.id)
                        }
                    }
                }
            } else {
                ForEach(events) { event in
                    EventRow(event: event)
                        .tag(event.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Events")
    }
}

struct EventRow: View {
    let event: TeslaCamEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let info = event.eventInfo {
                    Image(systemName: iconForReason(info.reason))
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "video.fill")
                        .foregroundStyle(.blue)
                }

                Text(eventTitle)
                    .font(.headline)
                    .lineLimit(1)
            }

            HStack {
                if let info = event.eventInfo {
                    let location = [info.city, info.street].compactMap({ $0 }).joined(separator: " ")
                    if !location.isEmpty {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text("\(event.segments.count) clips")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(formatDuration(event.totalDuration))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var eventTitle: String {
        let name = event.folderURL.lastPathComponent
        let parts = name.split(separator: "_")
        if parts.count >= 2 {
            let datePart = parts[0]
            let timePart = parts[1].replacingOccurrences(of: "-", with: ":")
            return "\(datePart) \(timePart)"
        }
        return name
    }

    private func iconForReason(_ reason: String?) -> String {
        guard let reason else { return "video.fill" }
        if reason.contains("sentry") { return "shield.fill" }
        if reason.contains("user_interaction") { return "hand.tap.fill" }
        if reason.contains("honk") { return "speaker.wave.3.fill" }
        return "video.fill"
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds > 0 else { return "" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return "\(minutes)m \(secs)s"
    }
}
