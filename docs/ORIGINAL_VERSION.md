# ROLE & GOAL
You are a Staff Full-Stack Software Engineer building a proprietary, closed-source Chinese Chess (Xiangqi / Cờ Tướng) AI Learning & Multiplayer Mobile Application. 

# ARCHITECTURE & INTELLECTUAL PROPERTY RESTRAINTS (CRITICAL)
- **Code License & Compliance**: The app MUST remain 100% proprietary and closed-source. To comply with GPL-3.0 licensing of the Pikafish Engine, DO NOT compile Pikafish or any GPL code into the Flutter client binary.
- **Engine Isolation**: Pikafish MUST run strictly as an isolated microservice on the backend server. The Flutter client communicates with the backend solely via REST API / WebSockets.

# TECH STACK
- **Client**: Flutter (Dart) - Cross-platform (iOS & Android).
- **Backend API & Realtime**: Node.js (TypeScript) or Go, with Socket.io / WebSockets for online matches.
- **AI Engine Service**: Isolated backend wrapper running Pikafish Engine with UCI protocol.
- **Vision Recognition**: Dual Architecture (Hybrid Vision Pipeline)
  - Strategy A: Local ONNX Runtime / TFLite (YOLOv8 board/piece classifier running locally on device).
  - Strategy B: Cloud Vision Fallback (Server-side OpenAI GPT-4o / Gemini Vision API to convert board photo to FEN string).
  - Include an A/B testing flag & fallback logic (If Local fails/confidence < 80%, fallback to Cloud Vision).

# CORE FEATURE SPECIFICATIONS

1. **Skill Assessment & Placement**:
   - Initial interactive placement test (puzzle solving + trial evaluation match).
   - Dynamic Elo calculation and starting tier assignment (800 - 2000 Elo).

2. **Training & Engine Coach Mode**:
   - Client sends game state (FEN) to `/api/v1/engine/analyze`.
   - Backend queries Pikafish (Multi-PV = 3) and returns top candidate moves + evaluation scores.
   - Visual overlay in Flutter highlighting candidate moves with rank markers.
   - Blunder detection alert when player move score drops drastically compared to top engine move.

3. **Board Import (FEN & Camera Scanner)**:
   - Import via manual FEN string paste.
   - Import via Photo Scan:
     1. Capture photo -> Perspective transform grid alignment.
     2. Attempt local TFLite classification.
     3. Fallback to Cloud Vision API if low confidence.
     4. Present "Interactive Board Correction UI" for user to adjust misplaced pieces before playing against AI or friends.

4. **Multiplayer Engine (Online Realtime)**:
   - Private Room Creation (Generate 6-digit alphanumeric room PIN code & deep share link).
   - Friend Invitation via Username search.
   - Pass & Play (Local 2-player mode on single screen).
   - Real-time match state synchronization over WebSockets, with clock management and move validation.

# INSTRUCTIONS FOR IMPLEMENTATION
- Write modular, clean, clean-architecture Dart code (Bloc/Provider/Riverpod) for Flutter.
- Write robust, scalable backend services with strict error handling.
- Build clean FEN parser and move validation utilities for Xiangqi rules (River crossing, General confinement, Cannon jump, Horse blocking legs).