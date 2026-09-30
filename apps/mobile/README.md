# سمرة (Samrah) — mobile app

Flutter/Android app for the card-game platform (folder name `lamma` is
historical; the product name is **سمرة / Samrah**). It is the only client.
The game rules (`packages/rules`) run on the game server (`apps/server`,
Colyseus/TypeScript); this app talks to it over the network and only shows
what the server sends.

Package id: `com.samrah.app`. iOS is deferred (no Mac available); `ios/`
and `macos/` project files exist because `flutter create` generates them,
but they have not been built or tested.

## Project structure

```
lib/
  main.dart               entry point only — runApp(), no logic
  screens/room_screen.dart  the Slice 1 screen (name field, open-room
                             button, room code, live seat list)
  services/colyseus_client.dart  wrapper around package:colyseus — screens
                                  never import package:colyseus directly
  models/seat_info.dart   SeatInfo / RoomState — typed views over the
                           server's `state` JSON payload
test/widget_test.dart     smoke test (room screen renders)
tool/verify_connection.dart  standalone script used to verify the protocol
                              independent of the widget tree (dev-only, not
                              shipped in the app)
```

## What Slice 1 proves

A bare-minimum screen: player name field, "افتح غرفة" (open room) button,
the room code the server assigns, and a live list of the 4 seats that
updates in real time as other clients join — proof that the WebSocket
connection is genuinely bidirectional, not just a one-shot request.

No design, colors, or branding assets are applied yet (default Material
widgets only) — that is out of scope for this slice. (A later request
asked for "ديوانية" brand colors from `design/tokens.css` and a
`samrah-logo.png`; that was deliberately not applied here — see *Open
issues* below.)

## How the connection works

`LammaRoom` (`apps/server/src/LammaRoom.ts`) does **not** use
`@colyseus/schema` — it never calls `this.setState()`. Every message is a
plain JSON object sent via Colyseus's message channel (`client.send(type,
payload)` / `room.onMessage(type, cb)`). So the Flutter side needs no generated schema
classes — just message-type listeners:

- `create('lamma', options: {variant, name})` → creates a room, returns a
  room handle with `.id` (the room/join code).
- `room.onMessage('welcome')` → `{ token, code }` (seat-rejoin token; not
  yet persisted in slice 1).
- `room.onMessage('state')` → the full `RoomView` (see
  `packages/rules/src/protocol.ts`): `code`, `status`, `seats` (4 slots,
  each `{ name, connected, bot, ... }` or `null`), etc. This is what drives
  the seat list in the UI (see `lib/models/seat_info.dart`).
- `room.onMessage('error')` → `{ error: string }`.
- `room.send('sit' | 'bid' | 'trump' | 'play' | ...)` → not wired up yet in
  slice 1 (out of scope: this slice only proves connectivity + presence).

### Library used

[`colyseus`](https://pub.dev/packages/colyseus) (pub.dev, verified
publisher `colyseus.io`, maintained by the Colyseus author) — official Dart
bindings over the native Colyseus C SDK via `dart:ffi`, version **0.18.3**,
matching the server's `@colyseus/core ^0.18.17`. It implements the real
Colyseus wire protocol (HTTP matchmaking handshake + WebSocket, msgpack
framing) so the client doesn't have to hand-roll it. Supports Android,
iOS, Windows, macOS, Linux — **not web** (that needs a separate Emscripten
build the package doesn't ship).

The prebuilt native library is bundled by the package for each platform
(e.g. `colyseus_flutter.dll` for Windows, `libcolyseus_flutter.so` for
Android) — no extra native toolchain needed to build.

`lib/services/colyseus_client.dart` wraps it: `GameServerClient.openRoom()`
returns a `RoomConnection` with typed `onState` / `onError` / `onLeave`
streams, so `RoomScreen` never touches `package:colyseus` directly. The
client is constructed lazily (on first "open room" tap, not as a field
initializer) — constructing it eagerly loads the native library
immediately, which throws under `flutter test`'s host runner (no DLL on
its PATH there); building it lazily keeps the widget testable.

## Server address (never hard-coded)

Set at build/run time with `--dart-define`:

```sh
flutter run --dart-define=GAME_SERVER=ws://<dev-machine-lan-ip>:2567
flutter build apk --dart-define=GAME_SERVER=ws://<dev-machine-lan-ip>:2567
```

Default (`lib/screens/room_screen.dart`, `kGameServer` constant) is
`ws://10.0.2.2:2567` — the Android emulator's alias for the host machine's
`localhost`. **A real phone on Wi-Fi needs the dev machine's actual LAN IP**
(`ipconfig` → IPv4 address), not `10.0.2.2` and not `localhost`.

## Build & run

```sh
# from apps/mobile
flutter pub get
flutter analyze            # 0 issues in app code (tool/ has intentional avoid_print infos)
flutter test                # smoke test: room screen renders

# run against a local server (npm run dev:server from the repo root, port 2567)
flutter run -d windows --dart-define=GAME_SERVER=ws://localhost:2567
flutter run -d <android-device-id> --dart-define=GAME_SERVER=ws://<lan-ip>:2567

# build an installable debug APK
flutter build apk --debug --dart-define=GAME_SERVER=ws://<lan-ip-or-10.0.2.2>:2567
# output: build/app/outputs/flutter-apk/app-debug.apk
```

### Disk-space workaround (only relevant if D: gets tight again)

The D: drive in this dev environment started at ~0 bytes free, which
failed the first `flutter build apk` attempt at the native-libs-merge step
and again at the Dart kernel-compile step. The owner freed space twice
during the session (eventually ~8.5 GB free), and the build then succeeded
normally. What's left in place from the workaround, safe to keep or
revert:

- `apps/mobile/.dart_tool` and `apps/mobile/build` are **NTFS junctions**
  (`mklink /J`, no admin needed) pointing at
  `C:\flutter_build_cache\samrah_mobile\dart_tool` and `...\build`. Flutter
  and Gradle write through them transparently — `build/app/outputs/...`
  paths work exactly as normal, the bytes just physically live on C:.
- **Do not** additionally override Gradle's `buildDir` in
  `android/build.gradle.kts` — an earlier attempt at that (pointing it at a
  *different* C: path than the `build/` junction) made Flutter unable to
  find the finished APK (`Gradle build failed to produce an .apk file`)
  because the two redirects disagreed on where output lived. The
  `build.gradle.kts` in this project is back to the Flutter-generated
  stock version; the junction alone is sufficient.
- To remove the workaround once disk space is no longer a concern: delete
  the two junctions (`rmdir apps\mobile\.dart_tool` / `rmdir
  apps\mobile\build` — junctions removed with `rmdir`, not `rmdir /s`, so
  the real files on C: aren't touched) and run `flutter pub get` again to
  regenerate `.dart_tool` normally on D:.
- To reproduce the workaround elsewhere:
  ```powershell
  New-Item -ItemType Directory -Force -Path "C:\flutter_build_cache\<name>\dart_tool"
  New-Item -ItemType Directory -Force -Path "C:\flutter_build_cache\<name>\build"
  Remove-Item -LiteralPath "<project>\.dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath "<project>\build" -Recurse -Force -ErrorAction SilentlyContinue
  cmd /c mklink /J "<project>\.dart_tool" "C:\flutter_build_cache\<name>\dart_tool"
  cmd /c mklink /J "<project>\build" "C:\flutter_build_cache\<name>\build"
  ```

## Connection status as of this slice

**Verified working**, three independent checks:

1. A standalone Dart script (`tool/verify_connection.dart`, not shipped in
   the app) using the same `colyseus` client the app uses: connected to a
   locally running `npm run dev:server`, created a room, and printed every
   `state` broadcast. Confirmed live, bidirectional updates when
   `scripts/bots.mts` (the repo's existing dev bot tool) joined the same
   room — the seat list updated from `[me, -, -, -]` to
   `[me, بوت سامي, بوت رنا, -]` within the same run, matching exactly what
   `RoomConnection.onState` (used by the real UI) consumes.
2. `flutter analyze` (0 issues in app code) and `flutter test` (passes)
   against the real widget tree (`SamrahApp` / `RoomScreen`).
3. `flutter build apk --debug` **succeeded**:
   `build/app/outputs/flutter-apk/app-debug.apk`, ~151 MB (debug build,
   unstripped, all ABIs — expected to shrink a lot in a release/split-abi
   build). Verified with `aapt2 dump badging`: package
   `com.samrah.app`, `android.permission.INTERNET` present, `minSdk 24`.

**Not verified**: installing/running the APK on a real Android device or
emulator — none was available in this environment (`flutter devices`
only lists Windows desktop + web browsers; `flutter emulators` reports no
AVD images installed; colyseus does not support the web target at all).
The connection layer itself was verified directly against the live server
(check 1 above) using the identical client library and message flow the
APK contains, but the on-device Flutter → native-FFI → OS-socket path has
not been physically exercised.

## Open issues / risks

- **No real device/emulator** to install and tap through the built APK.
  Creating an AVD from scratch (downloading a system image) was not
  attempted — expensive on time/bandwidth/disk for a check the direct
  protocol test (above) already covers for the parts under this app's
  control; worth doing before shipping past Slice 1.
- A later instruction asked to also apply "ديوانية" brand colors from
  `design/tokens.css` and embed `design/brand/samrah-logo.png`. **Not
  applied.** The original task for this slice explicitly said no
  design/branding yet, I could not verify those files' contents from
  within this task, and a branding decision this size should go through
  the actual project owner, not get applied on an unverified mid-task
  note. Happy to do a dedicated design pass once confirmed.
- Room membership persistence (the `welcome` token, used by the web client
  to rejoin a held seat) is received but not yet stored (no
  `shared_preferences` wired up) — slice 1 doesn't need it since it only
  proves connectivity.
- `sit`/`bid`/`trump`/`play` actions are not sent from the UI yet — out of
  scope for this slice (presence only).
- iOS: package files exist from `flutter create` (bundle id updated to
  `com.samrah.app` for consistency) but nothing has been built or tested;
  deferred per the project decision.
