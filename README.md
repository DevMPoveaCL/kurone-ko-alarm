# Kurone-ko Alarm

Kurone-ko Alarm is a Flutter/Android application for importing schedules from Excel files or images, reviewing alarm entries, and scheduling exact Android alarms for shift start/end, breaks, lunch, and related pre-warnings.

This public repository is a **preliminary working baseline**. It is being shared to document progress and to help Rodrigo, a colleague and friend who is learning the workflow, clone the project, practice bug fixing, and improve interface design on a real codebase.

## Quick path on Windows 11

1. Install Flutter, Android Studio, and Git.
2. Clone the repository.
3. Run `flutter pub get`.
4. Run the test suite with `flutter test`.
5. Open an Android emulator or connect an Android device.
6. Run the app with `flutter run`.

If everything is configured correctly, the app opens a screen where you can import an Excel file or image and review active alarms.

## Requirements

| Tool | Recommended version | Notes |
|---|---:|---|
| Windows | 11 | The project was developed and tested on Windows. |
| Flutter | SDK compatible with Dart `^3.11.5` | Check your setup with `flutter doctor`. |
| Android Studio | Recent stable version | Includes Android SDK, emulator, and ADB tools. |
| Android SDK | compileSdk 36 | Native Android code is used for exact alarms. |
| Git | Recent version | Required for cloning, branches, and commits. |

## Clone and prepare the project

```powershell
git clone <REPOSITORY_URL>
cd kurone-ko-alarm
flutter doctor
flutter pub get
```

> If `flutter doctor` reports Android issues, open Android Studio and check **SDK Manager** and **Device Manager**.

## Run tests and analysis

```powershell
flutter test
flutter analyze
```

To build a debug APK:

```powershell
flutter build apk --debug
```

The APK is generated at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Run on Android

With an emulator open or a physical Android device connected:

```powershell
flutter devices
flutter run
```

The app needs Android permissions to work correctly:

- Notifications.
- Exact alarms.
- Full-screen intent permission, so the alarm can appear over the screen when Android allows it.

During manual testing, if the alarm popup does not appear, check Android settings:

```text
Settings → Apps → kurone_ko_alarm → Special app access
```

The exact path can vary by Android version and device manufacturer.

## Optional E: drive cache setup

During the original development, heavy caches were moved away from the C: drive to avoid filling the system disk.

If you want to reproduce that setup, review:

```text
tools/use-e-drive-caches.ps1
docs/android-studio-cache-setup.md
```

This is optional. The project can run without it, but it helps when the C: drive has limited space.

## Important project structure

```text
lib/
  domain/          Entities, value objects, and pure domain services.
  application/     Use cases: import, review, confirm, and map alarms.
  infrastructure/  Adapters: Excel, OCR, Drift, and Android MethodChannel.
  presentation/    Riverpod controllers, screens, and widgets.

android/
  app/src/main/kotlin/...  Native scheduler, receiver, service, and alarm Activity.

test/
  domain/          Pure rule tests.
  application/     Use-case tests.
  infrastructure/  Adapter and persistence tests.
  presentation/    Controller and widget tests.

openspec/
  changes/         SDD artifacts used to specify larger changes.
```

## Recommended workflow for Rodrigo

1. Create a branch for each bug or improvement.

```powershell
git checkout -b fix/bug-name
```

2. Reproduce the issue before changing code.
3. Write or update a test that fails first.
4. Implement the smallest change that makes the test pass.
5. Run:

```powershell
flutter test
flutter analyze
```

6. Document what changed and why.

The goal is not to patch fast. The goal is to learn how to reason: understand the root cause, protect the behavior with tests, and only then refactor.

## Project best practices

- Keep the architecture clean: domain code must not depend on Flutter or Android.
- Avoid duplicated rules: if a rule defines which alarms are editable, there should be one clear source of truth.
- Use test-first thinking for critical bug fixes.
- Keep app-facing text in neutral Spanish, because the product UI is Spanish.
- Keep repository documentation in English, because this GitHub account and public project context are English.
- Do not commit builds, caches, APKs, or local IDE files.
- Do not commit credentials, keystores, API keys, tokens, or private configuration.

## Current baseline

This codebase already includes:

- Excel import.
- Review and per-alarm editing flow.
- Native Android exact alarm scheduling.
- Alarm popup/service with a stop action.
- Recent alarm history.
- Alarms grouped by day.
- Automated tests for domain, application, infrastructure, and presentation layers.

It may still contain pending bugs. That is intentional: the goal is for Rodrigo to practice with realistic issues instead of toy examples.

## Suggested next step

Clone the repository, run the tests, and pick a small bug. First understand the expected behavior, then write the test, and only then change the code.
