# Configures heavy Flutter/Android build caches outside C: for this Windows user.
# This is intentionally GLOBAL, not project-local: every Flutter/Gradle project
# opened by this user can reuse these caches on E:.
# Run from PowerShell, then restart Android Studio and terminals.

$CacheRoot = "E:\DevCache\global"

if (-not (Test-Path -LiteralPath "E:\")) {
    throw "Drive E: was not found. Connect or mount it before configuring caches."
}

New-Item -ItemType Directory -Force -Path `
    "$CacheRoot\gradle", `
    "$CacheRoot\android-user", `
    "$CacheRoot\pub-cache", `
    "$CacheRoot\tmp" | Out-Null

[Environment]::SetEnvironmentVariable("GRADLE_USER_HOME", "$CacheRoot\gradle", "User")
[Environment]::SetEnvironmentVariable("ANDROID_USER_HOME", "$CacheRoot\android-user", "User")
[Environment]::SetEnvironmentVariable("PUB_CACHE", "$CacheRoot\pub-cache", "User")
[Environment]::SetEnvironmentVariable("TEMP", "$CacheRoot\tmp", "User")
[Environment]::SetEnvironmentVariable("TMP", "$CacheRoot\tmp", "User")

"Configured cache root: $CacheRoot"
"Restart Android Studio and all terminals before building again."
