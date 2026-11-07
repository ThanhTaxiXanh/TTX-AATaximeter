# GPS auto-centering and background location — 0.6.0

## Android permission steps (user-controlled)
1. On first app launch, show a one-time disclosure explaining GPS for taximeter and request foreground precise location **only after the user taps** “Cấp quyền vị trí”.
2. If foreground access is granted, automatically query current GNSS position and center the Flutter Map without pressing the map button. On subsequent launches and activity resumes, refresh position again when permission is already granted.
3. Separately explain background location usage and offer **Mở cài đặt quyền**. On Android 11+, **Luôn cho phép / Allow all the time** is enabled by the USER on the OS permission Settings page. Do not attempt to auto-select or force this setting, and do not repeatedly nag on each launch.
4. Manifest declares ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_BACKGROUND_LOCATION, FOREGROUND_SERVICE, FOREGROUND_SERVICE_LOCATION, WAKE_LOCK. GitHub Actions verifies these in the **merged APK manifest**.
5. The trip's Geolocator Android Foreground Service begins only when app is visible and a driver explicitly starts/resumes a trip. It shows a persistent GPS notification; GPS is not secretly streamed when no trip exists.
6. Android 14+ restrictions on starting a location foreground service from the background still apply. Background permission does not grant arbitrary FGS starts. Never promise continuous metering after Android force-stop or process kill; SQLite restores the last checkpoint paused without billing missing time/km.
7. Mobile data is **NOT** needed to compute fares from GNSS coordinates locally. However assisted GNSS acquisition can be slower offline, maps from online OpenStreetMap tiles will not load without internet unless previously cached (no offline guarantee), and physical obstructions, GNSS outages or phone battery policies can suspend meter.
8. If location is denied/disabled, the map remains on Vietnam overview; there is no invented user position. Permission can be granted from app settings via the overflow menu or the map location button.
9. For broad Google Play distribution, background location access requires disclosure and Google Play's permissions policy review. This experimental APK has not undergone that approval.

Sources:
- https://developer.android.com/develop/sensors-and-location/location/permissions/background
- https://developer.android.com/develop/sensors-and-location/location/permissions
- https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- https://pub.dev/packages/geolocator
