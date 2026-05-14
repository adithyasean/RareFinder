# Backend Integration

The RareFinder iOS app communicates with a FastAPI-based backend. This document outlines the key integration points, data structures, and communication protocols.

## 📡 Protocol & Format

- **Base URL**: Defaults to `http://localhost:8000`.
- **Format**: JSON (UTF-8).
- **Authentication**: Bearer Token in the `Authorization` header.

## 🔐 Authentication Flow

RareFinder uses an OTP-based authentication system.

1.  **Request OTP**: The hunter enters their identifier (email/handle).
2.  **Verify OTP**: The hunter enters the received code.
3.  **Token Issuance**: Upon successful verification, the backend returns a JWT Bearer token.
4.  **Session Persistence**: The token and hunter details are stored in `UserDefaults` (keys: `rf.authToken` and `rf.authSession`) and attached to subsequent requests by `BackendClient`.

### Important Endpoints
- `POST /auth/request-otp`: Request a login code.
- `POST /auth/login`: Exchange identifier and password/code for a token.
- `POST /auth/signup`: Register a new hunter.
- `POST /auth/logout`: Invalidate the current session.

## 🏹 Core Entities & DTOs

The app uses DTOs (Data Transfer Objects) to map backend JSON to local Swift structures.

### Bounties (`BountyDTO`)
Bounties are the primary objectives.
- `id`: Unique identifier.
- `title`, `summary`, `detail`: Description of the objective.
- `latitude`, `longitude`, `radius_km`: Geofence data.
- `is_bounty`: Boolean indicating if this is a search area (radius) or an exact marker.
- `intel_score`: Points awarded for successful reports.

### Intel Reports (`IntelReportDTO`)
Submissions made by hunters.
- `bounty_id`: Reference to the parent bounty.
- `hunter_name`, `hunter_seed`: Identity of the reporter.
- `note`: Textual details from the field.
- `status`: "verified", "pending", or "quarantined".
- `points_awarded`: Points earned for this submission.
- `image_url`: Optional link to a captured photo.
- `replies`: Optional list of comments on the report.

### Hunters (`HunterDTO`)
Profile data for the authenticated user.
- `display_name`, `handle`: Public identity.
- `points`: Total accumulated balance.
- `rank`, `streak`: Competitive statistics.
- `is_moderator`: Boolean granting access to moderation tools.

## 🛰️ Geofence Verification

To ensure reports are genuine, the app performs a geofence check:
- The app compares the hunter's current location with the bounty's geofence.
- A boolean `is_geofence_verified` is sent in the `SubmitReportRequest`.
- The backend may also perform server-side verification using the provided coordinates.

## 🖼️ Media Handling

Images are uploaded as `multipart/form-data` to the `/storage/upload` endpoint.
1.  Hunter captures a photo.
2.  App sends the raw JPEG data.
3.  Backend returns a permanent URL.
4.  App includes this URL in the report submission.

## 🔄 Synchronization

Synchronization is handled by `SyncService`.
- **Fetch**: On app launch and when the scene becomes active, the app fetches all active bounties, reports, and hunter stats.
- **Merge**: Local SwiftData models are updated or created based on the fetched DTOs.
- **Push**: Local reports are pushed to the backend immediately upon submission.

---

> [!IMPORTANT]
> If you are setting up the backend for the first time, ensure the database is seeded with initial categories and bounties to provide a functional testing environment for the iOS app.
