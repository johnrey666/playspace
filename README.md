# PlaySpace

A free, modern **social gaming** mobile app built with **Flutter** and **Firebase**. Add friends, share stories, chat in PMs & group chats, and battle in four real-time multiplayer games — all wired to a live Firebase backend.

> Firebase project: `playspace-1db5b` (already configured in `lib/firebase_options.dart`).

## Features

- **Auth** — email/password sign up & sign in, unique-username validation, forgot-password reset, persistent session.
- **Home** — `playspace` logo bar, notifications bell with unread dot, story/My-Day row, live game cards, incoming-challenge banner, and a friend activity feed with flame reactions, comment threads, and rematch challenges.
- **4 real-time games** (state synced over **Firebase Realtime Database**):
  - **QuizBlitz** — 1v1 trivia, 5 rounds × 15s, speed-scaled scoring, live opponent score.
  - **SketchWars** — 3–8 players, `CustomPainter` canvas with color/brush/eraser, every stroke synced live, case-insensitive guess detection, drawer rotation over 8 rounds.
  - **CardDuel** — 1v1 turn-based card battle, 30-card deck, energy economy, attack/defense combat, full turn sync.
  - **TypeRacer** — 2–6 players, live progress bars, live WPM/accuracy, atomic finish-order ranking.
  - All games detect opponent disconnects ("Opponent left" → win awarded) via RTDB presence + `onDisconnect`.
- **Friends** — username search, friend requests (accept/decline), friends list.
- **Messaging** — PMs with sent/read receipts, group chats with admin controls (rename, photo, add/remove members), unread badges.
- **Stories / My Day** — photo, gallery, or text stories; 24h auto-expiry; full-screen auto-advancing viewer with seen/unseen rings.
- **Ranks** — global & friends leaderboards by total score.
- **Profile** — editable avatar/name/bio, stats, best scores, recent results grid, sign out.
- **Notifications** — FCM token registration + in-app banners for friend requests, challenges, and messages.
- **UX** — Material 3 with blue accent, light/dark via system setting, shimmer skeletons, friendly error/retry states, `flutter_animate` transitions, online green dots.

## Project structure

```
lib/
  main.dart                 # Firebase init + provider graph
  firebase_options.dart
  app/                      # theme.dart, router.dart (auth gate + bottom nav shell)
  features/
    auth/ home/ games/ friends/ chat/ stories/ leaderboard/ profile/ notifications/
  shared/
    models/ services/ providers/ widgets/
```

## Getting started

```bash
flutter pub get
flutter run
```

State management uses `provider`. Services (`AuthService`, `FirestoreService`, `RealtimeDbService`, `StorageService`, `FcmService`, `PresenceService`, `MatchmakingService`) are provided at the root and consumed by feature screens.

## Firebase setup

The app expects these enabled in the Firebase console:

1. **Authentication** → Email/Password provider.
2. **Cloud Firestore** (collections created on the fly): `users`, `friendRequests`, `stories`, `chats/{id}/messages`, `challenges`, `gameResults/{id}/comments`.
3. **Realtime Database** — used for `matchmaking/`, `matches/`, and `status/` (presence).
4. **Storage** — `profile_photos/`, `stories/`, `group_photos/`.
5. **Cloud Messaging** — client registers FCM tokens to `users/{uid}.fcmTokens`. Sending pushes for friend requests / challenges / messages is intended to be done by a Cloud Function reacting to Firestore writes.

### Suggested Firestore indexes
Composite indexes are needed for some queries (Firestore will print a console link the first time each runs), e.g.:
- `gameResults`: `uid` (in) + `createdAt` desc; `gameId` + `score` desc.
- `friendRequests`: `toUid` + `status`.
- `stories`: `uid` (in) + `expiresAt`.

## Notes

- **Native-assets build on paths with spaces:** `flutter test` / `flutter build` may fail to build the transitive `objective_c` native hook when the project or user path contains a space (e.g. `C:\Users\Asus TUF\...`). This is a Flutter tooling limitation, not an app bug. `flutter analyze` runs clean. Build from a space-free path if you hit it.
- All screens use real Firebase data — no mock/placeholder data.
