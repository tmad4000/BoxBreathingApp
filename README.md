# Box Breathing

**Free. Open source. A little space to breathe.**

A simple Flutter breathing timer for iPhone and iPad, licensed under MIT.
No account, ads, subscriptions, analytics, microphone access or session history.

- Four equal phases: inhale, hold, exhale, hold; four seconds each.
- A completed-round counter and four progress markers.
- A quiet checkpoint after four full rounds (64 seconds). Finish or continue
  for another four; the session total is preserved.
- Pause/Resume preserves the current phase and fractional progress.
- Keeps the screen awake during practice and pauses when backgrounded or interrupted.
- Independent sound and haptics settings. Sound uses media playback rather than
  keyboard clicks; Settings includes Test sound.
- Reduced Motion support, labeled controls, phase announcements and scrollable large-text layouts.
- Version/build and an optional, local Copy diagnostics snapshot in Settings.

Keep your breathing comfortable. Stop and breathe normally if you feel dizzy or
uncomfortable. This is a general wellness timer, not medical treatment.

## Develop and test from the CLI

Verified toolchain: Flutter 3.32.6 / Dart 3.8.1 and Xcode 26.2.

```sh
flutter pub get
flutter analyze
flutter test --reporter expanded
flutter test --machine > test-results.jsonl
flutter build ios --simulator --debug
# Capture actual iOS screens and run the native checks:
flutter drive --driver=test_driver/screenshots.dart --target=integration_test/native_test.dart -d DEVICE_UUID
scripts/export-app-store-screenshots.sh release/screenshots
```

Tests cover full-round boundaries, checkpoint stop/continue, real pause/resume,
backgrounding, large text, small screens, Reduce Motion, sound toggling and native
channel requests. Native tests run with `scripts/check-ios.sh DEVICE_UUID` on a Mac
with Xcode and an available iOS simulator. Simulator playback state verifies that
native media decoding and playback starts; it does not prove a physical phone's
speaker or headset can be heard with every microphone/route combination.

The short original sound is reproducible with `python3 scripts/generate_sound.py`.
No downloaded audio or additional audio dependency is needed.

## Agent-friendly support

Settings → Copy diagnostics produces versioned JSON without recording history or
sending it anywhere. It includes current phase/round state and native audio
routing/playback status. CLI tests produce structured Flutter test events using
`--machine`; no production automation server, analytics or background logger runs.

## Design and future ideas

The app keeps one primary action on the practice screen. Settings contains
secondary controls, version/build, source, support and privacy. Existing indigo
branding is retained with restrained contrast and a 4-point spacing system.

See [the design notes](.interface-design/system.md) and
[future timing ideas](docs/timing-options.md). Adjustable pacing and automatic
slowing are intentionally planned, not implemented in this release.

[Privacy policy](PRIVACY.md) · [Support](https://github.com/tmad4000/BoxBreathingApp/issues) · [MIT license](LICENSE)
