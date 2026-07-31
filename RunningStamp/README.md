# RunStamp HealthKit POC

RunStamp reads Apple Watch running workouts from Apple Health, analyzes heart-rate zone time, and renders a SwiftUI running poster.

## HealthKit Setup

The `RunStamp` target must have HealthKit enabled in Xcode under Signing & Capabilities.

The app also needs this Info.plist key:

- `NSHealthShareUsageDescription`: explains that RunStamp reads running workouts, heart rate, distance, and active energy to generate a running report poster.

This POC requests read access for workouts, heart rate, active energy burned, distance walking/running, and workout routes. Mock/sample data is only used when real HealthKit data is unavailable, denied, or missing heart-rate samples.
