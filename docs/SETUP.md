# Setup Guide

This guide provides instructions for setting up the RareFinder iOS development environment.

## 📋 Prerequisites

- **macOS**: Latest stable version recommended.
- **Xcode**: 15.0 or later (required for SwiftData and Observation framework).
- **iOS**: 17.0+ for running on physical devices or simulators.

## ⚙️ Initial Setup

1.  **Clone the project**:
    ```bash
    gh repo clone adithyasean/RareFinder
    cd RareFinder
    ```
2.  **Open in Xcode**:
    Double-click `RareFinder.xcodeproj` or run `open RareFinder.xcodeproj`.
3.  **Dependencies**:
    The project uses native Apple frameworks (SwiftData, SwiftUI) and does not currently require CocoaPods or Swift Package Manager for external dependencies.

## 🌐 Backend Configuration

By default, the app points to a local backend instance.

1.  **API Base URL**:
    The `baseURL` is defined in `Services/BackendClient.swift`.
    ```swift
    init(baseURL: URL = URL(string: "http://localhost:8000")!, ...)
    ```
2.  **Running Locally**:
    If you are running the backend on the same machine, `localhost:8000` is the default. If testing on a physical device, ensure the device can reach your Mac's IP (e.g., `http://192.168.1.XX:8000`).

## 🧪 Testing and Launch Flags

The app supports several launch arguments for development and UI testing:

- `-RFUITestsReset`: Resets `UserDefaults` (onboarding and auth session) on launch.
- `-RFUITestsSkipOnboarding`: Forces the app to skip the onboarding flow and show the main tab view.

To set these in Xcode:
1.  Click on the Scheme (RareFinder) > **Edit Scheme...**
2.  Select **Run** > **Arguments** tab.
3.  Add the flag to **Arguments Passed On Launch**.

## 📱 Running on Device

1.  Connect your iPhone via USB or network.
2.  Select your device in the Xcode target selector.
3.  Ensure your **Signing & Capabilities** are configured with a valid Developer Profile.
4.  Press `Cmd + R`.

---

> [!WARNING]
> SwiftData requires a persistent store. If you encounter crashes during development related to `ModelContainer`, try cleaning the build folder (`Cmd + Shift + K`) or deleting the app from the simulator to reset the local database.
