# TinyIce Admin Client

Flutter admin client for TinyIce streaming server.

## Features

- Dashboard with real-time stats (listeners, streams, AutoDJs)
- Streams management (add/kick/toggle mounts, edit, visible, kick all)
- AutoDJ control (play/pause, next, shuffle, loop, restart, scan, save playlist)
- Relays management (add/edit/delete/toggle/restart)
- Transcoders management
- Go Live - WebRTC streaming from device
- History viewing
- Security management (IP banning/whitelisting, lockout clearing)
- Webhooks management
- Multi-server support

## Getting Started

```bash
flutter pub get
flutter run
```

## Build

### iOS Simulator
```bash
flutter build ios --simulator --no-codesign
```

### iOS Device (requires Apple Developer account)
```bash
flutter build ios --device
```

### macOS
```bash
flutter build macos
```

## Configuration

- Add servers via the login screen
- Server URL should point to your TinyIce admin interface
- Session-based authentication with CSRF token
