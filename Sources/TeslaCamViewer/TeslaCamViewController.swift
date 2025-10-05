import Cocoa
import AVFoundation
import AVKit

// MARK: - Main View Controller

class TeslaCamViewController: NSViewController {
    private var cameraViews: [CameraView] = []
    private var players: [AVPlayer] = []
    private var playerLayers: [AVPlayerLayer] = []
    private var timeObserver: Any?
    private var isUserSeeking = false
    private var isSynchronizing = false
    
    // UI Elements
    private let gridView = NSView()
    private let controlsView = NSView()
    private let playPauseButton = NSButton()
    private let timeSlider = NSSlider()
    private let currentTimeLabel = NSTextField(labelWithString: "00:00")
    private let totalTimeLabel = NSTextField(labelWithString: "00:00")
    private let speedControl = NSSegmentedControl()
    private let customSpeedField = NSTextField()
    private let customSpeedLabel = NSTextField(labelWithString: "Speed:")
    private let jumpToEventButton = NSButton()
    private let openFolderButton = NSButton()
    private let eventInfoLabel = NSTextField(labelWithString: "")
    private let eventMarkerLayer = CAShapeLayer()
    
    private var totalDuration: CMTime = .zero
    private var eventInfo: EventInfo?
    private var eventTimestamp: Date?
    private var firstSegmentTimestamp: Date?
    
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1400, height: 900))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Setup grid view for 6 cameras (2x3 layout)
        gridView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gridView)
        
        // Setup controls view
        controlsView.translatesAutoresizingMaskIntoConstraints = false
        controlsView.wantsLayer = true
        controlsView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        view.addSubview(controlsView)
        
        // Open folder button
        openFolderButton.title = "Open Folder"
        openFolderButton.bezelStyle = .rounded
        openFolderButton.target = self
        openFolderButton.action = #selector(openFolder)
        openFolderButton.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(openFolderButton)
        
        // Play/Pause button
        playPauseButton.title = "▶️"
        playPauseButton.bezelStyle = .rounded
        playPauseButton.target = self
        playPauseButton.action = #selector(togglePlayPause)
        playPauseButton.isEnabled = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(playPauseButton)
        
        // Time slider
        timeSlider.minValue = 0
        timeSlider.maxValue = 1
        timeSlider.doubleValue = 0
        timeSlider.target = self
        timeSlider.action = #selector(sliderValueChanged)
        timeSlider.isEnabled = false
        timeSlider.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(timeSlider)
        
        // Time labels
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        totalTimeLabel.translatesAutoresizingMaskIntoConstraints = false
        currentTimeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        totalTimeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        controlsView.addSubview(currentTimeLabel)
        controlsView.addSubview(totalTimeLabel)
        
        // Speed control
        speedControl.segmentCount = 5
        speedControl.setLabel("0.5x", forSegment: 0)
        speedControl.setLabel("1x", forSegment: 1)
        speedControl.setLabel("2x", forSegment: 2)
        speedControl.setLabel("4x", forSegment: 3)
        speedControl.setLabel("8x", forSegment: 4)
        speedControl.selectedSegment = 1  // Default to 1x
        speedControl.target = self
        speedControl.action = #selector(speedChanged)
        speedControl.isEnabled = false
        speedControl.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(speedControl)
        
        // Custom speed label
        customSpeedLabel.translatesAutoresizingMaskIntoConstraints = false
        customSpeedLabel.font = NSFont.systemFont(ofSize: 11)
        customSpeedLabel.alignment = .right
        controlsView.addSubview(customSpeedLabel)
        
        // Custom speed input field
        customSpeedField.translatesAutoresizingMaskIntoConstraints = false
        customSpeedField.placeholderString = "Custom"
        customSpeedField.font = NSFont.systemFont(ofSize: 11)
        customSpeedField.alignment = .center
        customSpeedField.target = self
        customSpeedField.action = #selector(customSpeedChanged)
        customSpeedField.isEnabled = false
        controlsView.addSubview(customSpeedField)
        
        // Jump to event button
        jumpToEventButton.title = "⚡ Jump to Event"
        jumpToEventButton.bezelStyle = .rounded
        jumpToEventButton.target = self
        jumpToEventButton.action = #selector(jumpToEvent)
        jumpToEventButton.isEnabled = false
        jumpToEventButton.translatesAutoresizingMaskIntoConstraints = false
        controlsView.addSubview(jumpToEventButton)
        
        // Event info label
        eventInfoLabel.translatesAutoresizingMaskIntoConstraints = false
        eventInfoLabel.font = NSFont.systemFont(ofSize: 11)
        eventInfoLabel.textColor = .secondaryLabelColor
        controlsView.addSubview(eventInfoLabel)
        
        setupLayoutConstraints()
    }
    
    private func setupLayoutConstraints() {
        NSLayoutConstraint.activate([
            // Grid view (top area for videos)
            gridView.topAnchor.constraint(equalTo: view.topAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gridView.bottomAnchor.constraint(equalTo: controlsView.topAnchor),
            
            // Controls view (bottom bar)
            controlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            controlsView.heightAnchor.constraint(equalToConstant: 100),
            
            // Open folder button
            openFolderButton.leadingAnchor.constraint(equalTo: controlsView.leadingAnchor, constant: 20),
            openFolderButton.topAnchor.constraint(equalTo: controlsView.topAnchor, constant: 15),
            
            // Event info label
            eventInfoLabel.leadingAnchor.constraint(equalTo: openFolderButton.trailingAnchor, constant: 15),
            eventInfoLabel.centerYAnchor.constraint(equalTo: openFolderButton.centerYAnchor),
            eventInfoLabel.trailingAnchor.constraint(lessThanOrEqualTo: jumpToEventButton.leadingAnchor, constant: -15),
            
            // Jump to event button (same row as event info)
            jumpToEventButton.trailingAnchor.constraint(equalTo: controlsView.trailingAnchor, constant: -20),
            jumpToEventButton.centerYAnchor.constraint(equalTo: openFolderButton.centerYAnchor),
            jumpToEventButton.widthAnchor.constraint(equalToConstant: 130),
            
            // Play/Pause button
            playPauseButton.leadingAnchor.constraint(equalTo: controlsView.leadingAnchor, constant: 20),
            playPauseButton.topAnchor.constraint(equalTo: openFolderButton.bottomAnchor, constant: 10),
            playPauseButton.widthAnchor.constraint(equalToConstant: 60),
            
            // Current time label
            currentTimeLabel.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 10),
            currentTimeLabel.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            
            // Time slider (shorten to avoid overlap with custom speed)
            timeSlider.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 10),
            timeSlider.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            timeSlider.trailingAnchor.constraint(equalTo: totalTimeLabel.leadingAnchor, constant: -10),
            
            // Total time label
            totalTimeLabel.trailingAnchor.constraint(equalTo: customSpeedLabel.leadingAnchor, constant: -15),
            totalTimeLabel.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            
            // Custom speed label
            customSpeedLabel.trailingAnchor.constraint(equalTo: customSpeedField.leadingAnchor, constant: -5),
            customSpeedLabel.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            customSpeedLabel.widthAnchor.constraint(equalToConstant: 40),
            
            // Custom speed field
            customSpeedField.trailingAnchor.constraint(equalTo: speedControl.leadingAnchor, constant: -10),
            customSpeedField.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            customSpeedField.widthAnchor.constraint(equalToConstant: 50),
            
            // Speed control
            speedControl.trailingAnchor.constraint(equalTo: controlsView.trailingAnchor, constant: -20),
            speedControl.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            speedControl.widthAnchor.constraint(equalToConstant: 250)
        ])
    }
    
    @objc private func openFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select Tesla Dashcam Event Folder"
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.loadFolder(url: url)
            }
        }
    }
    
    private func loadFolder(url: URL) {
        // Clear existing players
        cleanupPlayers()
        
        // Parse folder
        guard let (cameras, event) = TeslaFolderParser.parse(url: url) else {
            showAlert(message: "Unable to parse folder. Please ensure you selected a valid Tesla dashcam folder.")
            return
        }
        
        cameraViews = cameras
        eventInfo = event
        
        // Calculate total duration (use the maximum duration among all cameras)
        totalDuration = cameras.map { $0.totalDuration }.max() ?? .zero
        
        // Debug: Print duration information
        print("📊 Video duration analysis:")
        for camera in cameras {
            let duration = CMTimeGetSeconds(camera.totalDuration)
            print("   \(camera.name): \(duration) seconds (\(camera.segments.count) segments)")
        }
        print("   Total duration: \(CMTimeGetSeconds(totalDuration)) seconds")
        
        // Store first segment timestamp for event time calculation
        firstSegmentTimestamp = cameras.first?.segments.first?.timestamp
        
        // Parse event timestamp
        if let timestampString = event?.timestamp {
            print("📅 Event timestamp string: \(timestampString)")
            
            // Try multiple date formats
            let iso8601Formatter = ISO8601DateFormatter()
            
            // Try with fractional seconds first
            iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            eventTimestamp = iso8601Formatter.date(from: timestampString)
            
            // Try without fractional seconds
            if eventTimestamp == nil {
                iso8601Formatter.formatOptions = [.withInternetDateTime]
                eventTimestamp = iso8601Formatter.date(from: timestampString)
            }
            
            // Try simple date formatter for format like "2025-10-01T14:10:01"
            if eventTimestamp == nil {
                let simpleDateFormatter = DateFormatter()
                simpleDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                simpleDateFormatter.timeZone = TimeZone.current
                eventTimestamp = simpleDateFormatter.date(from: timestampString)
            }
            
            if let timestamp = eventTimestamp {
                print("✅ Event timestamp parsed: \(timestamp)")
            } else {
                print("❌ Failed to parse event timestamp")
            }
        }
        
        // Print first segment timestamp for debugging
        if let firstSegment = firstSegmentTimestamp {
            print("📹 First segment timestamp: \(firstSegment)")
            
            if let eventTime = eventTimestamp {
                let diff = eventTime.timeIntervalSince(firstSegment)
                let totalSeconds = CMTimeGetSeconds(totalDuration)
                print("⏱️  Time difference: \(diff) seconds (\(diff/60) minutes)")
                print("🎯 Event position: \(diff/totalSeconds * 100)% of video duration")
                if diff > totalSeconds {
                    print("⚠️  Event time exceeds video duration by \(diff - totalSeconds) seconds")
                }
            }
        }
        
        // Update UI
        updateEventInfo()
        
        // Setup players for each camera view
        setupPlayers()
        
        // Enable controls
        playPauseButton.isEnabled = true
        timeSlider.isEnabled = true
        speedControl.isEnabled = true
        customSpeedField.isEnabled = true
        
        // Enable jump to event button if we have event timestamp
        jumpToEventButton.isEnabled = (eventTimestamp != nil && firstSegmentTimestamp != nil)
        
        totalTimeLabel.stringValue = formatTime(totalDuration)
        
        // Draw event marker on slider
        drawEventMarker()
        
        // Auto-play after loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.togglePlayPause()
        }
    }
    
    private func setupPlayers() {
        // Remove old player layers
        playerLayers.forEach { $0.removeFromSuperlayer() }
        playerLayers.removeAll()
        players.removeAll()
        
        // Remove old text label layers
        gridView.layer?.sublayers?.filter { $0 is CATextLayer && $0.name?.starts(with: "cameraLabel_") == true }.forEach {
            $0.removeFromSuperlayer()
        }
        
        // Create players for each camera
        for (_, cameraView) in cameraViews.enumerated() {
            let player = AVPlayer()
            player.actionAtItemEnd = .none
            players.append(player)
            
            // Create player layer
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspect
            playerLayers.append(playerLayer)
            
            // Add to grid
            gridView.layer?.addSublayer(playerLayer)
            
            // Load first segment
            if let firstSegment = cameraView.segments.first {
                let playerItem = AVPlayerItem(url: firstSegment.url)
                player.replaceCurrentItem(with: playerItem)
                
                // Observe when item ends to load next segment
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(playerItemDidReachEnd(_:)),
                    name: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem
                )
            }
        }
        
        // Add time observer to primary player
        if let primaryPlayer = players.first {
            let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = primaryPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                self?.updateTimeDisplay(time)
            }
        }
        
        layoutPlayerLayers()
    }
    
    private func layoutPlayerLayers() {
        let gridRect = gridView.bounds
        let cols = 3
        let rows = 2
        
        // Label height at bottom of each cell
        let labelHeight: CGFloat = 30
        
        let cellWidth = gridRect.width / CGFloat(cols)
        let cellHeight = gridRect.height / CGFloat(rows)
        
        // Get scale factor for Retina displays
        let scale = view.window?.backingScaleFactor ?? 2.0
        
        // Define the fixed layout positions for each camera type
        // Layout: Left Pillar, Front, Right Pillar (top row)
        //         Left Repeater, Back, Right Repeater (bottom row)
        let cameraPositions: [String: (col: Int, row: Int)] = [
            "left_pillar": (0, 0),    // Top-left
            "front": (1, 0),          // Top-center
            "right_pillar": (2, 0),   // Top-right
            "left_repeater": (0, 1),  // Bottom-left
            "back": (1, 1),           // Bottom-center
            "right_repeater": (2, 1)  // Bottom-right
        ]
        
        // Create a map from camera name to player layer index
        var cameraToLayerMap: [String: Int] = [:]
        for (index, cameraView) in cameraViews.enumerated() {
            cameraToLayerMap[cameraView.name] = index
        }
        
        // Wrap all layout updates in a single CATransaction for synchronized updates
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Position each player layer at its fixed location
        for (cameraName, position) in cameraPositions {
            if let layerIndex = cameraToLayerMap[cameraName] {
                let layer = playerLayers[layerIndex]
                let cameraView = cameraViews[layerIndex]
                
                let x = CGFloat(position.col) * cellWidth
                let y = gridRect.height - CGFloat(position.row + 1) * cellHeight // Flip Y coordinate
                
                // Video layer takes most of the cell, leaving room for label at bottom
                let videoHeight = cellHeight - labelHeight
                
                layer.frame = CGRect(x: x, y: y + labelHeight, width: cellWidth, height: videoHeight)
                
                // Find or create text layer for camera name
                var textLayer: CATextLayer
                if let existingTextLayer = gridView.layer?.sublayers?.first(where: { 
                    $0 is CATextLayer && $0.name == "cameraLabel_\(cameraName)" 
                }) as? CATextLayer {
                    textLayer = existingTextLayer
                } else {
                    textLayer = CATextLayer()
                    textLayer.string = formatCameraName(cameraView.name)
                    textLayer.foregroundColor = NSColor.white.cgColor
                    textLayer.backgroundColor = NSColor.black.cgColor
                    textLayer.alignmentMode = .center
                    textLayer.name = "cameraLabel_\(cameraName)"
                    gridView.layer?.addSublayer(textLayer)
                }
                
                // Update text layer properties and position
                textLayer.fontSize = 14
                textLayer.contentsScale = scale  // Fix blurry text on Retina
                textLayer.frame = CGRect(
                    x: x,
                    y: y,  // Position at bottom of cell
                    width: cellWidth,
                    height: labelHeight
                )
                textLayer.cornerRadius = 0
                
                // Make sure the layer is visible
                layer.isHidden = false
            } else {
                // Camera not available - this position will be empty (no layer to hide)
                // The empty space will show the background color
            }
        }
        
        CATransaction.commit()
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        // Use CATransaction to ensure immediate, synchronized updates
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layoutPlayerLayers()
        CATransaction.commit()
        
        // Update marker position after layout is complete
        updateEventMarkerPosition()
    }
    
    @objc private func togglePlayPause() {
        guard let primaryPlayer = players.first else { return }
        
        if primaryPlayer.rate == 0 {
            // Play all players - get current speed
            var currentSpeed: Float = 1.0
            
            // Check if using preset speed
            if speedControl.selectedSegment >= 0 && speedControl.selectedSegment < 5 {
                let speeds: [Float] = [0.5, 1.0, 2.0, 4.0, 8.0]
                currentSpeed = speeds[speedControl.selectedSegment]
            } else if let speedText = customSpeedField.stringValue.trimmingCharacters(in: .whitespaces) as String?,
                      !speedText.isEmpty,
                      let customSpeed = Float(speedText) {
                currentSpeed = customSpeed
            }
            
            players.forEach { $0.play(); $0.rate = currentSpeed }
            playPauseButton.title = "⏸"
        } else {
            // Pause all players
            players.forEach { $0.pause() }
            playPauseButton.title = "▶️"
        }
    }
    
    @objc private func sliderValueChanged() {
        guard !cameraViews.isEmpty else { return }
        
        isUserSeeking = true
        
        let targetTime = CMTime(seconds: timeSlider.doubleValue, preferredTimescale: 600)
        seekToTime(targetTime)
        
        // Reset flag after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isUserSeeking = false
        }
    }
    
    private func seekToTime(_ time: CMTime) {
        guard !isSynchronizing else { return }
        isSynchronizing = true
        
        let wasPlaying = players.first?.rate != 0
        let currentSpeed = players.first?.rate ?? 1.0
        
        // Pause all players during seek
        players.forEach { $0.pause() }
        
        // Seek each player to appropriate segment
        for (index, cameraView) in cameraViews.enumerated() {
            let (segmentIndex, offset) = cameraView.segmentIndex(for: time)
            
            guard segmentIndex < cameraView.segments.count else { continue }
            
            let segment = cameraView.segments[segmentIndex]
            let player = players[index]
            
            // Check if we need to load a different segment
            if let currentItem = player.currentItem,
               let currentURL = (currentItem.asset as? AVURLAsset)?.url,
               currentURL != segment.url {
                // Load new segment
                let newItem = AVPlayerItem(url: segment.url)
                player.replaceCurrentItem(with: newItem)
                
                // Observe new item
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(playerItemDidReachEnd(_:)),
                    name: .AVPlayerItemDidPlayToEndTime,
                    object: newItem
                )
            }
            
            // Seek to offset within segment
            player.seek(to: offset, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        // Resume playback if was playing
        if wasPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.players.forEach { $0.play(); $0.rate = currentSpeed }
                self?.isSynchronizing = false
            }
        } else {
            isSynchronizing = false
        }
    }
    
    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        guard let playerItem = notification.object as? AVPlayerItem,
              let player = players.first(where: { $0.currentItem === playerItem }),
              let playerIndex = players.firstIndex(of: player) else { return }
        
        let cameraView = cameraViews[playerIndex]
        
        // Find current segment
        if let currentURL = (playerItem.asset as? AVURLAsset)?.url,
           let currentSegmentIndex = cameraView.segments.firstIndex(where: { $0.url == currentURL }),
           currentSegmentIndex + 1 < cameraView.segments.count {
            
            // Load next segment
            let nextSegment = cameraView.segments[currentSegmentIndex + 1]
            let newItem = AVPlayerItem(url: nextSegment.url)
            
            let wasPlaying = player.rate != 0
            let currentSpeed = player.rate
            
            player.replaceCurrentItem(with: newItem)
            
            // Observe new item
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerItemDidReachEnd(_:)),
                name: .AVPlayerItemDidPlayToEndTime,
                object: newItem
            )
            
            if wasPlaying {
                player.play()
                player.rate = currentSpeed
            }
        } else {
            // Reached end of all segments
            if playerIndex == 0 {
                // Primary player reached end
                playPauseButton.title = "▶️"
            }
        }
    }
    
    @objc private func speedChanged() {
        let speeds: [Float] = [0.5, 1.0, 2.0, 4.0, 8.0]
        let selectedSpeed = speeds[speedControl.selectedSegment]
        
        // Clear custom speed field when using preset speeds
        customSpeedField.stringValue = ""
        
        applySpeed(selectedSpeed)
    }
    
    @objc private func customSpeedChanged() {
        guard let speedText = customSpeedField.stringValue.trimmingCharacters(in: .whitespaces) as String?,
              !speedText.isEmpty,
              let customSpeed = Float(speedText),
              customSpeed > 0 && customSpeed <= 16 else {
            // Invalid input, revert to current speed
            customSpeedField.stringValue = ""
            return
        }
        
        // Deselect preset speeds
        speedControl.selectedSegment = -1
        
        applySpeed(customSpeed)
    }
    
    private func applySpeed(_ speed: Float) {
        players.forEach { player in
            if player.rate != 0 {
                player.rate = speed
            }
        }
    }
    
    @objc private func jumpToEvent() {
        guard let eventTime = eventTimestamp,
              let firstSegmentTime = firstSegmentTimestamp else {
            return
        }
        
        // Calculate time difference between event and first segment
        let timeDifference = eventTime.timeIntervalSince(firstSegmentTime)
        let totalSeconds = CMTimeGetSeconds(totalDuration)
        
        // Jump to 10 seconds before the event, or 10 seconds before video end if event exceeds duration
        let targetSeconds: Double
        if timeDifference <= totalSeconds {
            // Event is within video duration, jump to 10 seconds before event
            targetSeconds = max(0, timeDifference - 10)
        } else {
            // Event exceeds video duration, jump to 10 seconds before video end
            targetSeconds = max(0, totalSeconds - 10)
        }
        let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
        
        // Seek to that time
        seekToTime(targetTime)
        
        // Update slider
        timeSlider.doubleValue = targetSeconds
    }
    
    private func drawEventMarker() {
        guard let eventTime = eventTimestamp,
              let firstSegmentTime = firstSegmentTimestamp else {
            print("⚠️  Cannot draw event marker: missing timestamp")
            eventMarkerLayer.removeFromSuperlayer()
            return
        }
        
        // Calculate event position in timeline
        let timeDifference = eventTime.timeIntervalSince(firstSegmentTime)
        let totalSeconds = CMTimeGetSeconds(totalDuration)
        
        print("🎯 Drawing event marker:")
        print("   Time difference: \(timeDifference) seconds")
        print("   Total duration: \(totalSeconds) seconds")
        print("   Position: \(timeDifference / totalSeconds * 100)%")
        
        guard timeDifference >= 0 else {
            print("❌ Event time \(timeDifference) is before video start")
            eventMarkerLayer.removeFromSuperlayer()
            return
        }
        
        // If event time exceeds video duration, clamp it to the end
        if timeDifference > totalSeconds {
            print("⚠️  Event time \(timeDifference) exceeds video duration \(totalSeconds), clamping to end")
        }
        
        // Configure marker layer
        eventMarkerLayer.fillColor = NSColor.systemRed.cgColor
        eventMarkerLayer.strokeColor = NSColor.white.cgColor
        eventMarkerLayer.lineWidth = 2.0
        eventMarkerLayer.shadowColor = NSColor.black.cgColor
        eventMarkerLayer.shadowOpacity = 0.5
        eventMarkerLayer.shadowOffset = CGSize(width: 0, height: 2)
        eventMarkerLayer.shadowRadius = 2
        
        // Add marker layer to slider's superview
        if eventMarkerLayer.superlayer == nil, let superLayer = timeSlider.superview?.layer {
            superLayer.addSublayer(eventMarkerLayer)
            print("✅ Event marker layer added")
        }
        
        // Update marker position
        DispatchQueue.main.async { [weak self] in
            self?.updateEventMarkerPosition()
        }
    }
    
    private func updateEventMarkerPosition() {
        guard let eventTime = eventTimestamp,
              let firstSegmentTime = firstSegmentTimestamp,
              eventMarkerLayer.superlayer != nil else {
            return
        }
        
        let timeDifference = eventTime.timeIntervalSince(firstSegmentTime)
        let totalSeconds = CMTimeGetSeconds(totalDuration)
        
        guard totalSeconds > 0 else { return }
        
        // Use clamped time difference for position calculation
        let clampedTimeDifference = min(timeDifference, totalSeconds)
        let ratio = CGFloat(clampedTimeDifference / totalSeconds)
        
        // Get slider frame and ensure we have valid dimensions
        let sliderFrame = timeSlider.frame
        guard sliderFrame.width > 0, sliderFrame.height > 0 else { return }
        
        // Calculate marker position in superview coordinates
        let markerX = sliderFrame.minX + ratio * sliderFrame.width
        let markerY = sliderFrame.midY
        
        // Create circular shape for marker
        let markerRadius: CGFloat = 6
        let circlePath = CGMutablePath()
        circlePath.addEllipse(in: CGRect(
            x: markerX - markerRadius,
            y: markerY - markerRadius,
            width: markerRadius * 2,
            height: markerRadius * 2
        ))
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        eventMarkerLayer.path = circlePath
        CATransaction.commit()
    }
    
    private func updateTimeDisplay(_ time: CMTime) {
        guard !isUserSeeking else { return }
        
        // Calculate total elapsed time across all segments
        if let primaryPlayer = players.first,
           let currentItem = primaryPlayer.currentItem,
           let currentURL = (currentItem.asset as? AVURLAsset)?.url,
           let cameraView = cameraViews.first {
            
            var elapsedTime = primaryPlayer.currentTime()
            
            // Add duration of all previous segments
            for segment in cameraView.segments {
                if segment.url == currentURL {
                    break
                }
                elapsedTime = elapsedTime + segment.duration
            }
            
            // Clamp elapsed time to total duration to prevent exceeding
            let totalSeconds = CMTimeGetSeconds(totalDuration)
            let elapsedSeconds = CMTimeGetSeconds(elapsedTime)
            
            if elapsedSeconds >= totalSeconds {
                // Video has reached the end
                currentTimeLabel.stringValue = formatTime(totalDuration)
                timeSlider.doubleValue = totalSeconds
                timeSlider.maxValue = totalSeconds
                
                // Ensure all players are paused
                players.forEach { $0.pause() }
                playPauseButton.title = "▶️"
            } else {
                currentTimeLabel.stringValue = formatTime(elapsedTime)
                timeSlider.doubleValue = elapsedSeconds
                timeSlider.maxValue = totalSeconds
            }
        }
    }
    
    private func updateEventInfo() {
        guard let info = eventInfo else {
            eventInfoLabel.stringValue = ""
            return
        }
        
        var parts: [String] = []
        if let city = info.city {
            parts.append("📍 \(city)")
        }
        if let timestamp = info.timestamp {
            parts.append("🕐 \(timestamp)")
        }
        if let reason = info.reason {
            let reasonText = formatReason(reason)
            parts.append("⚠️ \(reasonText)")
        }
        
        eventInfoLabel.stringValue = parts.joined(separator: "  ")
    }
    
    func cleanupPlayers() {
        // Remove time observer
        if let observer = timeObserver, let primaryPlayer = players.first {
            primaryPlayer.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        // Remove notifications
        NotificationCenter.default.removeObserver(self)
        
        // Stop and remove players
        players.forEach { $0.pause(); $0.replaceCurrentItem(with: nil) }
        players.removeAll()
        
        // Remove player layers
        playerLayers.forEach { $0.removeFromSuperlayer() }
        playerLayers.removeAll()
        
        cameraViews.removeAll()
    }
    
    deinit {
        cleanupPlayers()
    }
}

