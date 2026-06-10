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
│   ├── GarminBadgesApp.mc        # AppBase entry point; creates view + delegate
│   ├── GarminBadgesView.mc       # All UI rendering (programmatic via dc.draw*) + HTTP fetch
│   └── GarminBadgesDelegate.mc   # BehaviorDelegate; SELECT button triggers refresh
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

## Key gotchas

- **Manifest `type`** must be `watch-app` (hyphenated), not `watchApp`. The SDK's `projectInfo.xml` is authoritative.
- **`resources/properties.xml`** must be a single combined file with a `<resources>` root containing `<properties>`, `<strings>`, and `<settings>` together — separate files (e.g. `resources/settings/properties.xml` + `settings.xml`) cause the compiler to silently skip generating the `-settings.json` file. Property values are inline text on the `<property>` element — no `<default>` child element. Setting type is `alphaNumeric` (capital N).
- **`onReceive` callback** type signature must exactly match `Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null` — the generic `Lang.Object?` is rejected by the type checker.
- **`Communications` permission** covers HTTP; there is no separate `InternetConnection` permission.
- **No layout XML** — all drawing is programmatic in `onUpdate()` using `dc.drawText()` / `dc.drawLine()`. Coordinates use fractional screen height (e.g. `h * 0.31`) to scale across device sizes.
- **`$message` is reserved in Monkey C** if using Monkey C templates — use a different variable name.
- **Developer key** is at `C:\Users\e7and\My Drive\Backup\garmin\developer_key`.

## API endpoint

`GET /api/watch` — authenticated via `Authorization: Bearer <api_key>`.

Response shape:
```json
{
  "upcoming_badges": [
    { "name": "Challenge Name", "progress_value": 7, "target_value": 10, "unit_key": "km" }
  ]
}
```

`upcoming_badges` is up to 3 in-progress badges (earned_date IS NULL) sorted by `progress_value / target_value` descending. Empty array if there are no in-progress challenges.

## Adding new screens / data

1. Add fields to `GarminBadgesView.mc` and populate them in `onReceive()`.
2. Add drawing calls in `onUpdate()` — use proportional `h * 0.xx` y-coordinates.
3. If the API response needs new fields, update `WatchController.php` in the backend repo.
4. If adding a new setting, update both `properties.xml` (value) and `settings.xml` (UI label).
