# RareFinder iOS 🏹

[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)](https://swift.org)
[![SwiftData](https://img.shields.io/badge/Storage-SwiftData-red.svg)](https://developer.apple.com/documentation/swiftdata)

**RareFinder** is a next-generation "Bounty Hunter" application designed for decentralized intel gathering. Hunters track down "Rare" items, locations, or entities across various districts, submit verified reports, and earn rewards.

Built with a modern iOS stack, RareFinder leverages the latest Apple technologies to provide a high-performance, accessible, and secure experience for hunters in the field.

---

## ✨ Key Features

- 📍 **Interactive Intel Map**: Real-time tracking of active bounties and reports.
- 🛡️ **Verified Reports**: Geofence-verified submissions with image support.
- 💰 **Hunter Economy**: Earn points for successful tracks and redeem them for rewards.
- 🔔 **Real-time Radar**: Get notified when you're near a high-value bounty.
- 👤 **Hunter Profiles**: Build your reputation, track your streak, and climb the leaderboards.
- 🕶️ **Dark Mode & Accessibility**: Fully optimized for field conditions with rich accessibility support.

## 🚀 Getting Started

To get the project up and running on your local machine, follow these steps:

1.  **Prerequisites**: Ensure you have a Mac with **Xcode 15.0+** installed.
2.  **Clone the Repository**:
    ```bash
    gh repo clone adithyasean/RareFinder
    cd RareFinder
    ```
3.  **Open the Project**:
    ```bash
    open RareFinder.xcodeproj
    ```
4.  **Run**: Select a simulator (iPhone 15 or later recommended) and press `Cmd + R`.

> [!TIP]
> For a detailed guide on environment setup and backend integration, see [docs/SETUP.md](docs/SETUP.md).

## 📚 Documentation

Detailed documentation is available in the `docs/` directory:

- 🛠️ **[Setup Guide](docs/SETUP.md)**: Prerequisites, installation, and environment configuration.
- 🏗️ **[Architecture](docs/ARCHITECTURE.md)**: Deep dive into the project structure, state management, and design patterns.
- 🌐 **[Backend Integration](docs/BACKEND.md)**: API documentation, authentication flows, and data structures.
- 📖 **[Documentation Overview](docs/README.md)**: A complete map of the project documentation.

## 🛠️ Tech Stack

- **UI Framework**: SwiftUI
- **Persistence**: SwiftData (Core Data evolution)
- **State Management**: Observation Framework (`@Observable`)
- **Networking**: `URLSession` with async/await
- **Authentication**: OTP-based Auth with Bearer tokens
- **Design System**: Custom-built for field readability

---

© 2026 RareFinder Team. Built with 🏹 for hunters everywhere.
