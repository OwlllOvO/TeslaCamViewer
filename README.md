# Tesla Cam Viewer

A synchronized player specifically designed for Tesla dashcam videos, supporting real-time synchronized playback of 6 camera angles.

## 🚀 Quick Start

**Get started in just 3 steps:**

```bash
# Step 1: Clone the project
git clone https://github.com/owlllovo/TeslaCamViewer.git
cd TeslaCamViewer

# Step 2: Build the project
swift build -c release

# Step 3: Run the app
./.build/release/TeslaCamViewer
```

After opening the app, click the "Open Folder" button and select a Tesla dashcam event folder to start playback.

## ✨ Features

- 🎥 **6-angle synchronized playback**: Simultaneously play the front, back, left/right B-pillar, and left/right repeater camera views (6 cameras total)  
- 🔄 **Seamless segment connection**: Automatically handle multiple video segments for continuous playback experience  
- ⏯️ **Comprehensive playback controls**: Play/pause, progress bar seeking, cross-segment jumping  
- ⚡ **Multi-speed playback**: Support 0.5x, 1x, 2x, 4x, 8x and custom playback speeds  
- 🚀 **GPU hardware acceleration**: Uses AVFoundation native framework to fully utilize macOS GPU acceleration  
- 📁 **Smart folder recognition**: Automatically parses Tesla dashcam folder structure  
- 📍 **Event information display**: Shows event time, location, trigger reason, and other info

## 🔧 System Requirements

- macOS 11.0 (Big Sur) or later  
- Xcode Command Line Tools (includes Swift compiler)  
- Mac with hardware video decoding support (basically all modern Macs)

## 📦 Installation and Build

### Method 1: Using Swift Package Manager (Recommended)

**Suitable for most users, the simplest way:**

```bash
# 1. Build the release version
swift build -c release

# 2. Run directly
./.build/release/TeslaCamViewer
```

**Optional: Create shortcut**

```bash
# Copy executable to /usr/local/bin (requires sudo)
sudo cp ./.build/release/TeslaCamViewer /usr/local/bin/

# Afterwards, run from anywhere by typing
TeslaCamViewer
```

### Method 2: Using Xcode (For Developers)

**If you want to modify code or develop:**

```bash
# 1. Open the project in Xcode
xed .

# or
open Package.swift
```

Then in Xcode:  
1. Select `TeslaCamViewer` scheme  
2. Click Run `⌘ R` or Build `⌘ B`  
3. Edit code with live debugging

### Method 3: Create App Bundle (Double-click Launch)

**If you want a macOS app you can open by double-clicking:**

1. First build the project:  
```bash
swift build -c release
```

2. Manually create App Bundle:  
```bash
# Create app directory structure
mkdir -p TeslaCamViewer.app/Contents/MacOS
mkdir -p TeslaCamViewer.app/Contents/Resources

# Copy executable
cp ./.build/release/TeslaCamViewer TeslaCamViewer.app/Contents/MacOS/

# Copy Info.plist
cp Info.plist TeslaCamViewer.app/Contents/

# Sign the app (optional but recommended)
codesign --force --deep --sign - TeslaCamViewer.app
```

3. Now you can open by double-clicking:  
```bash
open TeslaCamViewer.app
```

### First-time Dependency Installation

If it says Swift compiler not found, install Xcode Command Line Tools:

```bash
xcode-select --install
```

**Verify installation:**  
```bash
swift --version
# Should output something like: swift-driver version: 1.xx.x
```

## 🎬 Usage

### Step 1: Launch the app

Depending on how you built it, launch by one of:

```bash
# Method A: Run executable directly
./.build/release/TeslaCamViewer

# Method B: If App Bundle created
open TeslaCamViewer.app

# Method C: If installed to system path
TeslaCamViewer
```

### Step 2: Open Tesla video folder

1. Click the **"Open Folder"** button at top left  
2. In the file selector, navigate to your Tesla USB drive  
3. Select an event folder (usually under `TeslaCam/SavedClips/` or `TeslaCam/SentryClips/`)

**Typical Tesla folder path:**  
```
/Volumes/TeslaCam/
├── SavedClips/           # Manually saved clips
│   └── 2025-10-01_14-10-32/
├── SentryClips/          # Sentry mode recordings
│   └── 2025-10-05_09-30-15/
└── RecentClips/          # Recent dashcam clips
```

**Example folder contents:**  
```
2025-10-01_14-10-32/
├── 2025-10-01_13-59-49-back.mp4
├── 2025-10-01_13-59-49-front.mp4
├── 2025-10-01_13-59-49-left_pillar.mp4
├── 2025-10-01_13-59-49-left_repeater.mp4
├── 2025-10-01_13-59-49-right_pillar.mp4
├── 2025-10-01_13-59-49-right_repeater.mp4
├── 2025-10-01_14-00-49-back.mp4          # Next segment
├── 2025-10-01_14-00-49-front.mp4
├── ... (more segments)
└── event.json (optional, contains event metadata)
```

### Step 3: Playback Controls

The app automatically loads all videos and starts playback. You can use the following controls:

#### Basic Playback Controls  
- **Play/Pause**: Click the ▶️/⏸ button  
- **Seek Progress Bar**: Jump to any time point, automatically switching to the correct video segment  
- **Adjust Playback Speed**:  
  - Preset speeds: 0.5x, 1x, 2x, 4x, 8x  
  - Custom speed: Enter any speed between 0.1x-16x in the "Speed" input box

#### Advanced Features  
- **⚡ Jump to Event**: If folder contains `event.json`, click this button to jump automatically to 10 seconds before event  
- **Event Info Display**: Shows event time, location, and trigger reason at the top  
- **Red Event Marker**: Red dot on progress bar marks event timestamp

### Step 4: Browsing Multiple Folders

If you want to view other events:  
1. Click the "Open Folder" button  
2. Select another event folder  
3. The app will automatically clear old videos and load the new ones

**Tip:** The app supports missing cameras. If a camera’s video is missing, the corresponding position will be blank.

### 4. Video Layout

6 camera angles are laid out in a 3x2 grid aligned with vehicle spatial orientation:

```
┌─────────────┬─────────────┬──────────────┐
│ Left Pillar │    Front    │ Right Pillar │
├─────────────┼─────────────┼──────────────┤
│Left Repeater│    Back     │Right Repeater│
└─────────────┴─────────────┴──────────────┘
```

**Smart Layout:**  
- ✅ **Fixed positions:** Each camera always displayed in its fixed spot, no shifting forward  
- ✅ **Partial camera support:** Even with some cameras missing, shows at correct positions  
- ✅ **Blank handling:** Missing camera spots show blank to maintain consistent layout

## 🏗️ Project Structure

```
TeslaCamViewer/
├── Package.swift              # Swift Package configuration
├── Sources/
│   └── TeslaCamViewer/
│       ├── main.swift                    # Application entry point
│       ├── AppDelegate.swift             # App delegate
│       ├── Models.swift                  # Data models (EventInfo, VideoSegment, CameraView)
│       ├── TeslaCamViewController.swift  # Main view controller (UI and playback logic)
│       ├── TeslaFolderParser.swift       # Tesla folder parser
│       ├── Utilities.swift               # Utility functions and extensions
│       └── Resources/
│           └── Info.plist                # Resource configuration
├── Info.plist                 # macOS app configuration
└── README.md                  # This file
```

**Code Organization Notes:**  
- **main.swift**: Minimal app entry (~10 lines)  
- **AppDelegate.swift**: Application lifecycle management  
- **Models.swift**: Data structures separated from business logic  
- **TeslaCamViewController.swift**: Core UI & video playback (~600 lines)  
- **TeslaFolderParser.swift**: Independent folder parsing module, easy to test  
- **Utilities.swift**: Helper functions and extensions for DRY code

## 🔧 Development

### Debug Mode Build

Build debug version with debug symbols for development and debugging:

```bash
# Build debug version
swift build

# Run debug version
./.build/debug/TeslaCamViewer

# View detailed compile info
swift build -v
```

### Release Mode Build

Build optimized release version, smaller size, better performance:

```bash
# Build release version (with optimization)
swift build -c release

# Run release version
./.build/release/TeslaCamViewer

# Check binary size
ls -lh ./.build/release/TeslaCamViewer
```

### Clean Build

If build problems occur, clean then rebuild:

```bash
# Method 1: Clean using Swift Package Manager
swift package clean

# Method 2: Remove build directory completely
rm -rf .build

# Method 3: Clean and rebuild
swift package clean && swift build -c release
```

### Developing in Xcode

Using Xcode provides code completion, debugger, profiler and more:

```bash
# Open project in Xcode
xed .

# Or double-click to open
open Package.swift
```

## 🐛 Troubleshooting

### Problem: Application Won’t Launch

**Solution:**  
```bash
# Check Swift compiler
swiftc --version

# If missing, install Xcode Command Line Tools
xcode-select --install
```

### Problem: macOS Says App Is Damaged or Incomplete

**Symptom:** "Cannot open app because it may be damaged or incomplete"

**Solution:**  
```bash
# Remove quarantine attribute and re-sign
xattr -cr TeslaCamViewer.app
codesign --force --deep --sign - TeslaCamViewer.app

# Then reopen
open TeslaCamViewer.app
```

Or right-click app and choose "Open".

### Problem: Cannot Parse Folder

**Checklist:**  
- [ ] Folder contains `.mp4` files  
- [ ] Filenames include datetime stamp (`YYYY-MM-DD_HH-MM-SS`)  
- [ ] Filenames include camera identifiers (`front`, `back`, `left_pillar`, `left_repeater`, `right_pillar`, `right_repeater`)

### Problem: Playback Stutters

**Possible causes and fixes:**  
1. **Videos stored on slow hard drive** - Copy videos to SSD  
2. **Too many apps running simultaneously** - Close unnecessary apps  
3. **Playback speed too high** - Reduce to 2x or 1x speed

## 🎯 Performance Metrics

Tested on M1 Pro MacBook Pro:  
- ✅ Smooth simultaneous playback of 6 videos at up to 16x speed  
- ✅ Seamless segment switching

## 🔮 Future Plans

- [ ] Keyboard shortcut support  
- [ ] Playlist (batch view multiple events)  
- [ ] Customizable view layouts

## 📝 Tech Stack

- **Language**: Swift 5.9+  
- **Build System**: Swift Package Manager  
- **UI Framework**: AppKit (Cocoa)  
- **Video Framework**: AVFoundation + AVKit  
- **Hardware Acceleration**: VideoToolbox (automatic)

## 📄 License

This project is developed for personal learning and usage.

## 🙏 Acknowledgments

Thanks to Tesla for providing excellent Sentry Mode and dashcam functionality.