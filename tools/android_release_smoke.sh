#!/usr/bin/env bash
set -euo pipefail
package=com.waqarulmulk.promptvault
apk=build/app/outputs/flutter-apk/app-release.apk
mkdir -p build/release-smoke
adb install -r "$apk"
adb logcat -c
adb shell am force-stop "$package"
adb shell am start -W -n "$package/.MainActivity" | tee build/release-smoke/launch.txt
# Provider and background initialization can fail after am start returns.
for attempt in $(seq 1 10); do
  sleep 3
  adb shell pidof "$package" >/dev/null || {
    adb logcat -d -b crash > build/release-smoke/crash.txt
    cat build/release-smoke/crash.txt
    exit 1
  }
done
adb shell dumpsys activity activities > build/release-smoke/activities.txt
grep -E '(topResumedActivity|mResumedActivity).*com\.waqarulmulk\.promptvault' build/release-smoke/activities.txt
adb logcat -d -b crash > build/release-smoke/crash.txt
if grep -q "Process: $package" build/release-smoke/crash.txt; then
  cat build/release-smoke/crash.txt
  exit 1
fi
adb exec-out screencap -p > build/release-smoke/home.png
echo 'Optimized release stayed alive and resumed for 30 seconds.'
