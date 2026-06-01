# Android Studio and global E: cache setup

Heavy build caches should live outside the repo, under a user-global E: location:

```text
E:\DevCache\global
```

This keeps generated dependencies, Gradle distributions, Pub packages, and temp files out of `C:` and out of source control. The setting is user-global, so other Flutter/Gradle projects can reuse the same cache.

## Quick path

1. Run once in PowerShell:

   ```powershell
   .\tools\use-e-drive-caches.ps1
   ```

2. Restart Android Studio and terminals.
3. Open the project:

   ```text
   E:\Projects\Programacion\kurone-ko-alarm
   ```

4. Run `lib/main.dart` on an Android emulator/device.

## What was moved

| Cache | Environment variable | Location |
|---|---|---|
| Gradle user home | `GRADLE_USER_HOME` | `E:\DevCache\global\gradle` |
| Android user home | `ANDROID_USER_HOME` | `E:\DevCache\global\android-user` |
| Dart/Pub package cache | `PUB_CACHE` | `E:\DevCache\global\pub-cache` |
| Temporary files | `TEMP`, `TMP` | `E:\DevCache\global\tmp` |

## What stays on C: for now

The Android SDK is still configured at:

```text
C:\Users\dream\AppData\Local\Android\Sdk
```

That is safe for now. Moving the SDK itself should be done through Android Studio SDK Manager, not by dragging folders manually.

## If Android Studio still uses C:

Android Studio reads environment variables only on startup. Fully close Android Studio and reopen it.

If needed, set Gradle manually:

```text
Settings > Build, Execution, Deployment > Build Tools > Gradle > Gradle user home
```

Use:

```text
E:\DevCache\global\gradle
```
