# Documentation Overview

Welcome to the internal documentation for the RareFinder iOS application. This directory contains detailed guides for developers working on the project.

## 🗂️ Documentation Sections

### 1. [Setup Guide](SETUP.md)
Everything you need to know to get the project running.
- Local environment requirements.
- Dependency management.
- Backend connectivity.

### 2. [Project Architecture](ARCHITECTURE.md)
How the app is built and structured.
- Tech stack overview.
- Directory structure.
- State management strategy.
- Networking & Persistence layers.

### 3. [Backend Integration](BACKEND.md)
Details on the communication between the app and the server.
- API Endpoints.
- DTO (Data Transfer Object) definitions.
- Authentication & Security.
- Image storage and geofence verification.

---

## 🛠️ Contribution Guidelines

1.  **Code Style**: Follow standard Swift API Design Guidelines.
2.  **SwiftUI Patterns**: Prefer small, reusable components over large views.
3.  **State**: Use the `@Observable` framework for shared state and `SwiftData` for persistence.
4.  **Testing**: Ensure UI-test launch flags are handled in `RareFinderApp.swift` for clean testing environments.

---

> [!NOTE]
> This documentation is specific to the iOS application. For backend-specific code or deployment, please refer to the backend repository documentation.
