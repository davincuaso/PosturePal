# PosturePal: Ergonomic Assistant

## Overview
PosturePal is a real-time health utility designed for desk workers. It uses the device's front-facing camera and on-device machine learning to monitor spinal alignment, gently alerting you when you slouch to help build better ergonomic habits over time.

## Key Features
* **Live Body Tracking:** Uses the Vision framework to track key upper-body landmarks continuously.
* **Smart Alerts:** Provides visual and audio cues only when sustained poor posture is detected.
* **Health Integration:** Logs periods of good posture to Apple Health as Mindful Minutes.
* **Privacy First:** 100% on-device processing. No video feeds are recorded or transmitted.

## Tech Stack
* **Framework:** SwiftUI
* **Camera Input:** AVFoundation
* **Machine Learning:** Vision (VNDetectHumanBodyPoseRequest)
* **Health Data:** HealthKit

## Requirements
* iOS 17.0+
* iPhone with front-facing camera
* Xcode 15.0+

## Project Structure

```
PosturePal/
├── PosturePalApp.swift          # App entry point
├── Views/
│   ├── ContentView.swift        # Main UI with camera preview
│   ├── CameraPreviewView.swift  # UIViewRepresentable for camera layer
│   ├── PostureIndicatorView.swift # Visual feedback (green/red circle)
│   └── SettingsView.swift       # Settings and preferences
├── ViewModels/
│   └── PostureViewModel.swift   # Coordinates camera, detection, analysis
├── Managers/
│   ├── CameraManager.swift      # AVFoundation camera capture
│   ├── PoseDetector.swift       # Vision framework body pose detection
│   ├── PostureAnalyzer.swift    # Angle calculations and slouch detection
│   └── HealthKitManager.swift   # HealthKit integration
├── Assets.xcassets/             # App icons and colors
├── Info.plist                   # Privacy descriptions
└── PosturePal.entitlements      # HealthKit entitlement
```

## How It Works

### Camera Pipeline
AVFoundation captures real-time video frames from the front camera using `AVCaptureVideoDataOutput`. Frames are processed in memory without recording.

### Body Pose Detection
Each frame is analyzed using `VNDetectHumanBodyPoseRequest`, which identifies key body landmarks including ears, shoulders, and neck.

### Posture Analysis
The app calculates the angle between the ear and shoulder positions:
- A perfectly vertical alignment (ear directly above shoulder) results in an angle near 0°
- Forward head posture increases this angle
- When the angle exceeds the threshold (default: 25°) for 5+ seconds, an alert is triggered

### Health Integration
Good posture time is logged to Apple Health as Mindful Minutes, helping users track their wellness progress.

## Privacy

PosturePal requires the following permissions:

| Permission | Usage |
|------------|-------|
| Camera | Monitor posture via front camera (no recording) |
| HealthKit | Log good posture time as Mindful Minutes |

All processing happens on-device. No video, images, or personal data is transmitted externally.

## Setup

1. Open `PosturePal.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run on a physical device (camera required)

## Usage

1. **Grant Permissions:** Allow camera and HealthKit access when prompted
2. **Position Device:** Place your device at eye level, about arm's length away
3. **Start Monitoring:** Tap "Start Monitoring" to begin
4. **Maintain Posture:** Keep your ears aligned above your shoulders
5. **Adjust Threshold:** Use Settings to customize sensitivity

## Configuration

| Setting | Default | Description |
|---------|---------|-------------|
| Angle Threshold | 25° | Lower = stricter posture requirements |
| Audio Alerts | On | Play sound when slouching detected |
| Alert Delay | 5s | Time before alert triggers |

## License

MIT License
