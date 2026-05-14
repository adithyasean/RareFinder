# Project Architecture

RareFinder is built with a focus on modern Swift development patterns, prioritizing readability, maintainability, and responsiveness.

## 🏗️ High-Level Architecture

The app follows a **Feature-based structure** with a central **Service layer** for shared state and logic.

### Directory Structure

- **`RareFinder/`**: Root source folder.
    - **`Features/`**: Contains UI and logic grouped by functional area (Auth, Map, Radar, etc.). Each feature folder typically contains its views and local state helpers.
    - **`Services/`**: Singletons or shared instances that handle global logic.
        - `AppState.swift`: The central "brain" of the app.
        - `BackendClient.swift`: Handles HTTP communication.
        - `AuthService.swift`: Manages user sessions and credentials.
        - `SyncService.swift`: Coordinates data synchronization between local and remote.
    - **`Models/`**: Shared data models, including `SwiftData` persistent entities and `DTOs` for networking.
    - **`Design/`**: Design system tokens, reusable UI components, and theme definitions.
    - **`Assets.xcassets`**: Images, colors, and icons.

## 🧠 State Management

RareFinder uses the **Observation** framework introduced in iOS 17.

- **`AppState`**: A `@Observable` class that is injected into the environment at the root of the app. It provides access to all major services (`location`, `auth`, `sync`, `notifications`, etc.).
- **`Environment`**: Views access shared state using `@Environment(AppState.self)`.
- **`Local State`**: Views use `@State` for UI-only state (e.g., whether a sheet is presented).

## 💾 Persistence (SwiftData)

The app uses **SwiftData** for local storage.

- **Schema**: Defined in `RareFinderApp.swift`, including entities like `Bounty`, `IntelReport`, `HunterProfile`, `Reward`, `AppNotification`, and `ModerationFlag`.
- **ModelContainer**: Shared across the app and passed via `.modelContainer(sharedModelContainer)`.
- **Synchronization**: `SyncService` is responsible for fetching data from the backend and merging it into the `ModelContext`.

## 📈 Economy & Logic

While `AppState` manages shared state, certain logic is partitioned into specialized services:

- **`EconomyService`**: A static rules engine that calculates point rewards, tier progress, and redemption costs.
- **`AccessibilitySettings`**: Manages user preferences for high-contrast UI and haptic feedback.

## 🌐 Networking

The `BackendClient` acts as a thin wrapper around `URLSession`.

- **Async/Await**: All network calls are asynchronous.
- **DTOs**: Data is received as `Decodable` structs (DTOs) and then mapped to `SwiftData` models for persistence.
- **Auth**: The client automatically attaches a Bearer token to requests if one is present in the `tokenProvider`.

## 🎨 Design System

The app utilizes a custom design system located in the `Design/` directory.

- **Accessibility**: RareFinder includes custom modifiers like `.rfAccessibilityOverrides()` to ensure high readability and contrast in varying lighting conditions.
- **Components**: Standardized buttons, cards, and layouts ensure visual consistency across features.

---

> [!TIP]
> When adding a new feature, follow the existing pattern in `Features/` and ensure any shared logic is abstracted into a Service or Model.
