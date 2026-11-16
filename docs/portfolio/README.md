# PosturePal app captures

The original SettingsView running in an iPhone simulator. Camera and Apple Health remain disconnected; no pose measurement, posture score, or HealthKit result is simulated.

Captured by XCTest from the running SwiftUI application on an iPhone simulator. The screenshot files are format-converted WebP exports, with no recreated UI.

Source revision: 63cd03ac11a8a46ba8c3b837f9c53889b99dc5fd.

[Capture workflow and build log](https://github.com/davincuaso/IndoorNav/actions/runs/43896106879). The build-only fixture setup and UI capture tests are versioned on IndoorNav’s portfolio-native-captures branch under docs/portfolio/capture-support/prepare.py. App views and renderers are retained from the source; fixtures only supply sample model data or select the Scans tab. IndoorNav’s legacy files are excluded to match its Xcode target.

- [Posture and alert settings · simulator](screens/capture-01.webp)
