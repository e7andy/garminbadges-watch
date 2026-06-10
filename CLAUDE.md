# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project

**GarminBadges Watch App** — a Garmin Connect IQ watch app that displays badge stats from [garminbadges.com](https://garminbadges.com). Written in Monkey C (`.mc`), built with the Connect IQ SDK.

The backend API lives in the sibling repo `../garminbadges` (`backend/app/Http/Controllers/Api/WatchController.php`).

## Repo structure

```
garminbadges-watch/
├── manifest.xml                  # App metadata, type, permissions, target devices
├── jungle.xml                    # Build config (source/resource paths)
├── source/
│   ├── GarminBadgesApp.mc                  # AppBase entry point; creates view + delegate
│   ├── GarminBadgesView.mc                 # Main page: UI rendering (programmatic via dc.draw*) + HTTP fetch + scroll state
│   ├── GarminBadgesDelegate.mc             # BehaviorDelegate for main page; SELECT/tap = refresh, UP/DOWN/swipe = scroll, tap MORE / MENU = open all-challenges page
│   ├── GarminBadgesAllChallengesView.mc    # Second page: all challenges sorted most-urgent first, scrollable
│   └── GarminBadgesAllChallengesDelegate.mc # BehaviorDelegate for the all-challenges page; UP/DOWN/swipe = scroll, BACK = pop
└── resources/
    ├── drawables/
    │   ├── drawables.xml
    │   └── launcher_icon.svg
    └── properties.xml             # Combined properties/strings/settings: ApiKey, ApiUrl
```

## Build

```powershell
$SDK = "C:\Users\e7and\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2"
& "$SDK\bin\monkeyc.bat" -f jungle.xml -d fenix7 -o bin\GarminBadges.prg -y "C:\Users\e7and\My Drive\Backup\garmin\developer_key" -l 2
```

Output goes to `bin/GarminBadges.prg` (ignored by `.gitignore`).

## Simulator

```powershell
# Launch simulator
& "$SDK\bin\connectiq.bat"

# Sideload after building
& "$SDK\bin\monkeydo.bat" bin\GarminBadges.prg fenix7
```

Set `ApiKey` in the simulator via **File → Edit Persistent Storage → Edit Application.Properties data**. The app shows an error message until a key is provided.

`MaxDurationDays` (numeric, 0-365, default 0) hides any challenge/upcoming badge whose `duration_days` exceeds it. `0` means no limit.

## Key gotchas

- **Manifest `type`** must be `watch-app` (hyphenated), not `watchApp`. The SDK's `projectInfo.xml` is authoritative.
- **`resources/properties.xml`** must be a single combined file with a `<resources>` root containing `<properties>`, `<strings>`, and `<settings>` together — separate files (e.g. `resources/settings/properties.xml` + `settings.xml`) cause the compiler to silently skip generating the `-settings.json` file. Property values are inline text on the `<property>` element — no `<default>` child element. Setting type is `alphaNumeric` (capital N).
- **`onReceive` callback** type signature must exactly match `Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null` — the generic `Lang.Object?` is rejected by the type checker.
- **`Communications` permission** covers HTTP; there is no separate `InternetConnection` permission.
- **No layout XML** — all drawing is programmatic in `onUpdate()` using `dc.drawText()` / `dc.drawLine()`. Coordinates use fractional screen height (e.g. `h * 0.31`) to scale across device sizes.
- **Scrolling** — the challenges list is clipped with `dc.setClip()`/`dc.clearClip()` and offset by `_scrollOffset` (pixels). `_maxScroll` is recomputed each `onUpdate()` from row count vs. viewport height. The delegate's `onNextPage()`/`onPreviousPage()` (UP/DOWN buttons) and `onSwipe()` (touch) call `view.scrollBy()`.
- **`$message` is reserved in Monkey C** if using Monkey C templates — use a different variable name.
- **Developer key** is at `C:\Users\e7and\My Drive\Backup\garmin\developer_key`.

## API endpoint

`GET /api/watch` — authenticated via `Authorization: Bearer <api_key>`.

Response shape:
```json
{
  "challenges": [
    { "name": "Challenge Name", "progress_value": 7000, "target_value": 10000, "unit_key": "mi_km", "days_behind": 2, "duration_days": 30 }
  ],
  "upcoming": [
    { "name": "New Challenge", "days_until": 3, "duration_days": 7 }
  ]
}
```

`challenges` is up to 20 in-progress, time-limited badges (earned_date IS NULL, with both `start_date` and `end_date` set). They're sorted with started badges (`start_date <= now`) first — ranked descending by "days behind schedule", `days_behind` = `(elapsed_fraction - progress_fraction) * total_days` of the challenge window — followed by badges whose `start_date` is still in the future, last. `upcoming` is up to 2 badges with `start_date` in the next 7 days, sorted by `start_date` ascending. Either array may be empty.

`duration_days` is the challenge window length (`end_date - start_date`, in days). For `upcoming` badges with no `end_date`, it's `0`. The view filters out any item whose `duration_days` exceeds the `MaxDurationDays` setting (`0` = no limit) via `filterByDuration()` in `onReceive()`.

Some challenges (e.g. "finish in the top 3" podium challenges) have no numeric target — `target_value` is `0` and `unit_key` is `null` for these. The view skips the progress bar/fraction and shows "No target" instead.

`progress_value`/`target_value` are in the badge's raw storage units (meters for `mi_km`, seconds for `seconds`) — formatting/unit conversion happens on-device in `formatFraction()`/`formatTime()`, not in the API. `days_behind` is a rounded integer; positive = behind schedule, negative = ahead, 0 = on track.

**JSON number gotcha**: `progress_value`/`target_value`/`days_behind` decode as `Lang.Number` when the JSON has no decimal point (e.g. `92901`) and `Lang.Float` when it does (e.g. `283686.49`). Mixing the two in arithmetic without converting causes integer division (silently truncates a fraction to `0`). Always go through `toFloatVal()` before doing math on these fields.

The view shows "UPCOMING" at the top only when `upcoming` is non-empty. The main page shows only the first 5 `challenges` (already sorted most-urgent first); if more than 5 are returned, a "MORE" row is appended. The `challenges` list is scrollable (UP/DOWN buttons or swipe) when more rows exist than fit on screen. Each row shows the badge name and a "+Nd"/"-Nd"/"0d" `days_behind` indicator (red/green/gray) alongside the progress bar.

## All-challenges page

When more than 5 challenges are returned, `GarminBadgesView` shows a "MORE" row after the 5th challenge. Scrolling down to that row and pressing SELECT/tapping (`atMoreRow()` is true), or pressing MENU from the main page (when `hasMoreChallenges()` is true), pushes `GarminBadgesAllChallengesView` via `WatchUi.pushView()` — it lists *all* challenges from the same response, in the same sorted order, using the same row layout/scrolling as the main page. BACK pops back to the main page (default `BehaviorDelegate` behavior).

## Unit formatting

`formatFraction()` in `GarminBadgesView.mc` formats `progress_value/target_value` per `unit_key`:

- **`mi_km`** — raw value is meters. Shown as km by default; converted to miles if `System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE`.
- **`ft_m`** — raw value is meters. Shown as m by default; converted to feet if `System.getDeviceSettings().distanceUnits == System.UNIT_STATUTE`.
- **`seconds`** — whole hours show as `Nh`; otherwise `hh:mm:ss`.
- **`kilocalories`** — shown as `value/target kcal`.
- All other units — `value/target unit_key`.

## Adding new screens / data

1. Add fields to `GarminBadgesView.mc` and populate them in `onReceive()`.
2. Add drawing calls in `onUpdate()` — use proportional `h * 0.xx` y-coordinates.
3. If the API response needs new fields, update `WatchController.php` in the backend repo.
4. If adding a new setting, update `resources/properties.xml`.
