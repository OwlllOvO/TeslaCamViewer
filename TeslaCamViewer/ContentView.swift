import SwiftUI

struct ContentView: View {
    @StateObject private var scanner = TeslaCamScanner()
    @StateObject private var playerController = MultiAnglePlayerController()
    @State private var selectedEvent: TeslaCamEvent?

    var body: some View {
        NavigationSplitView {
            SidebarView(
                events: scanner.events,
                selectedEvent: $selectedEvent,
                isLoading: scanner.isLoading
            )
            .frame(minWidth: 220, idealWidth: 280)
        } detail: {
            if let event = selectedEvent {
                VStack(spacing: 0) {
                    MultiAngleVideoGrid(controller: playerController)
                        .background(.black)
                        .layoutPriority(1)

                    Divider()

                    PlaybackControlsView(controller: playerController)

                    EventInfoView(event: event)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("Tesla Dashcam Viewer", systemImage: "car.side")
                } description: {
                    Text("Open a TeslaCam folder or select an event to start viewing.")
                } actions: {
                    Button("Open Folder…") {
                        openFolder()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: openFolder) {
                    Label("Open Folder", systemImage: "folder")
                }
                .help("Open TeslaCam Folder")
            }
        }
        .onChange(of: selectedEvent) { _, newEvent in
            if let newEvent {
                playerController.loadEvent(newEvent)
            }
        }
        .onDisappear {
            playerController.cleanup()
        }
        .onKeyPress(.space) {
            playerController.togglePlayback()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            playerController.skipBackward(5)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            playerController.skipForward(5)
            return .handled
        }
        .onKeyPress(",") {
            playerController.stepBackward()
            return .handled
        }
        .onKeyPress(".") {
            playerController.stepForward()
            return .handled
        }
        .focusable()
    }

    private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a TeslaCam folder (TeslaCam, RecentClips, SavedClips, SentryClips, or an event folder)"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                selectedEvent = nil
                playerController.cleanup()
                await scanner.scanDirectory(url)
                if let first = scanner.events.first {
                    selectedEvent = first
                }
            }
        }
    }
}
