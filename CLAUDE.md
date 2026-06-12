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
│   ├── GarminBadgesApp.mc                   # AppBase entry point; creates view + delegate, getGlanceView() for the glance
│   ├── GarminBadgesView.mc                  # Main page: UI rendering (programmatic via dc.draw*) + HTTP fetch + UP/DOWN selection state
│   ├── GarminBadgesDelegate.mc              # Input for the main page (see "Navigation & selection")
│   ├── GarminBadgesAllChallengesView.mc     # Second page: all challenges sorted most-urgent first, scrollable
│   ├── GarminBadgesAllChallengesDelegate.mc # Input for the all-challenges page (see "Navigation & selection")
│   ├── GarminBadgesChallengeDetailView.mc   # Detail page for a single challenge (progress, status, duration)
│   ├── GarminBadgesUpcomingDetailView.mc    # Detail page for an upcoming badge (starts-in, duration)
│   ├── GarminBadgesMenuDelegate.mc          # Options menu (Refresh / All Challenges)
│   ├── GarminBadgesGlanceView.mc            # Glance widget preview: title + progress bar + "behind" count
│   ├── ScrollableView.mc                    # Shared scroll/momentum/page-flip-ticker state for the main and all-challenges pages
│   ├── ScrollDelegate.mc                    # Shared drag/flick/button scrolling for the main and all-challenges delegates
│   ├── BadgeFormat.mc                       # Shared formatting/drawing helpers (row layout, unit formatting, text wrapping/ticker, selection highlight)
│   └── BadgeCache.mc                        # Persists the latest /api/watch response for instant display on launch
└── resources/
    ├── drawables/
    │   ├── drawables.xml
    │   └── launcher_icon.svg
    └── properties.xml             # Combined properties/strings/settings: ApiKey, ApiUrl, MaxDurationDays
```

## Build

```powershell
$SDK = "C:\Users\e7and\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2"
& "$SDK\bin\monkeyc.bat" -f jungle.xml -d fenix7 -o bin\GarminBadges.prg -y "C:\Users\e7and\My Drive\Backup\garmin\developer_key" -l 2
```

Output goes to `bin/GarminBadges.prg` (ignored by `.gitignore`).

## Publishing to the Connect IQ Store

Until the app is published, sideloaded builds can't show a Settings screen in Garmin Connect Mobile (see "Settings on a real device" below) — publishing (even just submitting, before approval) registers the app's settings schema with Garmin's backend.

1. **Garmin Connect IQ Developer account** — as of late 2025, `apps.garmin.com` no longer hosts developer/upload functionality (it now redirects end users to the Connect IQ Store mobile app). Developer app management has moved to **[apps-developer.garmin.com](https://apps-developer.garmin.com)** — sign in there with the same Garmin account as `developer_key`'s registered public key. If `developer_key` was generated fresh, upload the matching public key (`developer_key.pub` / `.der`) under your account's profile so builds signed with it are accepted.
2. **Create the app listing** — "My Apps" → "Create App". Use the **same app ID** as `<iq:application id="...">` in `manifest.xml` (`a8e4c3b2-7f61-4d8e-9c2a-1b5f3e7d9a0c`) if the listing was created from this manifest; otherwise the portal assigns one and `manifest.xml` must be updated to match.
3. **Build a release package** covering all supported devices (the full `<iq:products>` list in `manifest.xml`), with debug info stripped:
   ```powershell
   $SDK = "C:\Users\e7and\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2"
   & "$SDK\bin\monkeyc.bat" -f jungle.xml -o bin\GarminBadges.iq -y "C:\Users\e7and\My Drive\Backup\garmin\developer_key" -e -r
   ```
   `-e`/`--package-app` produces an `.iq` store package (instead of a single-device `.prg`); `-r`/`--release` strips debug info. Omit `-d` — `-d` doesn't accept a comma-separated device list in this SDK version, so leaving it out builds for every device in `manifest.xml`'s `<iq:products>` automatically (prints "N OUT OF 101 DEVICES BUILT" progress).
4. **Upload `bin/GarminBadges.iq`** to the app listing via the Developer Portal's "Upload App" / App Versions tab.
5. **Fill in store listing details**: name, description, category, supported devices (should match `manifest.xml`), screenshots, app store icon, and a privacy policy URL — use `https://garminbadges.com/privacy`. See "Store listing content" and "Required images" below.
6. **Submit for review.** Garmin reviews submissions (can take days). Once approved and published, users install via the Connect IQ Store / Garmin Connect Mobile app, and Connect Mobile's Settings screen will work (pulling `ApiKey`/`ApiUrl`/`MaxDurationDays` from the now-registered schema).
7. **Future updates** — repeat steps 3–4 (build + upload a new `.iq`); the portal auto-increments the version on each upload, no manifest version field to bump.

### Store listing content

- **Name**: `Badge Tracker` (matches `AppName` in `resources/properties.xml`; "Garmin Badges" is not allowed by the Connect IQ Store's trademark policy).
- **Description** (draft — adjust to fit the portal's character limit):

  > Track your [garminbadges.com](https://garminbadges.com) challenge progress right from your wrist.
  >
  > - See your most urgent in-progress challenges, ranked by how far ahead or behind schedule you are, each with a live progress bar (e.g. 7/10 km).
  > - An UPCOMING section gives you a heads-up on challenges starting in the next 7 days.
  > - Select or tap any challenge for full details: progress, percentage, schedule status, and duration.
  > - A glance widget on your watch face loop shows your next challenge (or the most urgent one) and how many challenges you're currently behind on.
  > - Optionally hide long-running challenges by setting a maximum duration in Settings.
  >
  > Requires a free GarminBadges account — get your API key at garminbadges.com/dashboard (Settings → API Key) and enter it in this app's settings in Garmin Connect.

- **Category**: a "Tools" / "Data" style category (exact options are set by the portal at submission time).
- **Settings copy** (if the portal asks for per-setting descriptions, see "Setup" in `README.md` for the `ApiKey`/`ApiUrl`/`MaxDurationDays` wording).

### Required images

These are uploaded directly via the developer portal — they are not part of the build/`.iq` package.

- **App Store icon** — 500x500px, sRGB. Shown in store listings and search results. Allow ~10px padding, center the icon, and use a simple **solid (non-black, non-transparent) background** — this is a different design from `resources/drawables/launcher_icon.svg` (the small in-app icon, which has a black background and is fine as-is for that purpose).
- **On-device icons** (optional) — 128x128px, sRGB, two variants: a full-color one for OLED displays and a low-color one (64-color palette) for memory-in-pixel displays.
- **Hero/banner image** (optional, promotional) — 1440x720px.
- **Screenshots** — each ≤500x500px and ≤150KB, captured from the simulator (`connectiq.bat` + `monkeydo.bat`, then Win+Shift+S to capture and crop/resize). Cover the app's main views, on at least one round device (most of `manifest.xml`'s targets are round):
  - Glance preview
  - Main page (UPCOMING + challenges list)
  - All-challenges page
  - A detail page (challenge or upcoming)

## Simulator

```powershell
# Launch simulator
& "$SDK\bin\connectiq.bat"

# Sideload after building
& "$SDK\bin\monkeydo.bat" bin\GarminBadges.prg fenix7
```

Set `ApiKey` in the simulator via **File → Edit Persistent Storage → Edit Application.Properties data**. The app shows an error message until a key is provided.

`MaxDurationDays` (numeric, 0-365, default 0) hides any challenge/upcoming badge whose `duration_days` exceeds it. `0` means no limit.

Since the app defines a glance (`getGlanceView()`), the simulator opens directly to the glance preview rather than the main view. Press **Enter** (or click the screen) to invoke the default `GlanceViewDelegate` and launch the full app — this is also how it works on a real device. Pressing BACK from there exits the app in the simulator rather than returning to the glance; that's a simulator-only limitation (the glance↔app handoff is OS-managed on a real device).

## Real device

1. Build the `.prg` (same command as above — it's signed with the developer key).
2. Connect the watch via USB; it mounts as a USB drive ("GARMIN").
3. Copy `bin/GarminBadges.prg` into `GARMIN/APPS/` (create the folder if it doesn't exist).
4. Eject/disconnect — the watch shows "Installing..." then the app appears in the apps list.
5. To add it to the glance loop, hold the menu button on the app in the apps list and choose "Add to Glances" (wording varies by device), then swipe up from the watch face.

**Settings on a real device**: Garmin Connect Mobile's Apps → Badge Tracker → Settings screen pulls the settings schema (`ApiKey`/`ApiUrl`/`MaxDurationDays`) from Garmin's Connect IQ Store backend, keyed by the app ID in `manifest.xml`. A sideloaded `.prg` has no schema registered there, so it shows "No Settings" and there's no on-watch way to edit `Application.Properties`. Until the app is registered/uploaded in the Connect IQ Developer Portal, the only way to test on a real device is to **temporarily hardcode your API key as the default value of `ApiKey` in `resources/properties.xml`**, build, and sideload — then revert it back to an empty string before committing.

## Key gotchas

- **Manifest `type`** must be `watch-app` (hyphenated), not `watchApp`. The SDK's `projectInfo.xml` is authoritative.
- **`resources/properties.xml`** must be a single combined file with a `<resources>` root containing `<properties>`, `<strings>`, and `<settings>` together — separate files (e.g. `resources/settings/properties.xml` + `settings.xml`) cause the compiler to silently skip generating the `-settings.json` file. Property values are inline text on the `<property>` element — no `<default>` child element. Setting type is `alphaNumeric` (capital N).
- **`onReceive` callback** type signature must exactly match `Lang.Dictionary or Lang.String or PersistedContent.Iterator or Null` — the generic `Lang.Object?` is rejected by the type checker.
- **`Communications` permission** covers HTTP; there is no separate `InternetConnection` permission.
- **No layout XML** — all drawing is programmatic in `onUpdate()` using `dc.drawText()` / `dc.drawLine()`. Coordinates use fractional screen height (e.g. `h * 0.31`) to scale across device sizes.
- **Scrolling** — the challenges list is clipped with `dc.setClip()`/`dc.clearClip()` and offset by `_scrollOffset` (pixels). `_maxScroll` is recomputed each `onUpdate()` from row count vs. viewport height. The delegate's `onNextPage()`/`onPreviousPage()` (UP/DOWN buttons) call `view.scrollBy()`. Touch dragging uses `onDrag()` (`DragEvent`, requires `minApiLevel 3.3.0`) for 1:1 finger tracking via `view.scrollBy(-deltaY)`, and `onFlick()` (`FlickEvent`) calls `view.startMomentum(velocity)` to keep scrolling with deceleration (`onMomentumTick()`, 30ms `Timer`, 5% friction per tick, stops below 10px/s or at a list edge).
- **Long badge names** — `BadgeFormat.pagedText()` shows the full name if it fits, otherwise a page-flip ticker (alternating whole-word chunks, `BadgeFormat.PAGE_DURATION_TICKS` ticks per page). `ScrollableView` drives this via a 1Hz `_tickerTimer` started in `onShow()`/stopped in `onHide()` (`_tickCount`, `tickCount()`). Used for challenge row names (`BadgeFormat.drawChallengeRow()`, on the main and all-challenges pages) and "UPCOMING" row names on the main page.
- **`$message` is reserved in Monkey C** if using Monkey C templates — use a different variable name.
- **Developer key** is at `C:\Users\e7and\My Drive\Backup\garmin\developer_key`.

## API endpoint

`GET /api/watch` — authenticated via `Authorization: Bearer <api_key>`.

Response shape:
```json
{
  "challenges": [
    { "name": "Challenge Name", "progress_value": 7000, "target_value": 10000, "unit_key": "mi_km", "days_behind": 2, "duration_days": 30, "started": true, "days_until_start": 0 }
  ],
  "upcoming": [
    { "name": "New Challenge", "days_until": 3, "duration_days": 7 }
  ]
}
```

`challenges` is up to 20 in-progress, time-limited badges (earned_date IS NULL, with both `start_date` and `end_date` set). They're sorted with started badges (`start_date <= now`) first — ranked descending by "days behind schedule", `days_behind` = `(elapsed_fraction - progress_fraction) * total_days` of the challenge window — followed by badges whose `start_date` is still in the future, last. `started` is `start_date <= now`; for not-yet-started badges, `days_until_start` is `ceil(hours until start_date / 24)` (`0` for already-started badges). `upcoming` is up to 3 badges with `start_date` in the next 7 days, sorted by `start_date` ascending. Either array may be empty.

`duration_days` is the challenge window length (`end_date - start_date`, in days). For `upcoming` badges with no `end_date`, it's `0`. The view filters out any item whose `duration_days` exceeds the `MaxDurationDays` setting (`0` = no limit) via `filterByDuration()` in `onReceive()`.

Some challenges (e.g. "finish in the top 3" podium challenges) have no numeric target — `target_value` is `0` and `unit_key` is `null` for these. The view skips the progress bar/fraction and shows "No target" instead.

`progress_value`/`target_value` are in the badge's raw storage units (meters for `mi_km`, seconds for `seconds`) — formatting/unit conversion happens on-device in `formatFraction()`/`formatTime()`, not in the API. `days_behind` is a rounded integer; positive = behind schedule, negative = ahead, 0 = on track.

**JSON number gotcha**: `progress_value`/`target_value`/`days_behind` decode as `Lang.Number` when the JSON has no decimal point (e.g. `92901`) and `Lang.Float` when it does (e.g. `283686.49`). Mixing the two in arithmetic without converting causes integer division (silently truncates a fraction to `0`). Always go through `toFloatVal()` before doing math on these fields.

The view shows "UPCOMING" at the top only when `upcoming` is non-empty. The main page shows only the first 5 `challenges` (already sorted most-urgent first); if more than 5 are returned, a "MORE" row is appended. The `challenges` list is scrollable (UP/DOWN buttons or swipe) when more rows exist than fit on screen. Each row shows the badge name and a "+Nd"/"-Nd"/"0d" `days_behind` indicator (red/green/gray) alongside the progress bar.

## Navigation & selection

The main page has a single UP/DOWN selection cursor spanning the "UPCOMING" rows and the challenges/MORE list:

- `GarminBadgesView._selectedUpcomingIdx` is `>= 0` when an "UPCOMING" row is selected (its index), or `-1` when a challenge/MORE row is selected (the row at `viewportTop()`, via `rowIndexAt()`).
- `GarminBadgesDelegate.onNextPage()`/`onPreviousPage()` (DOWN/UP) implement the state machine: from the last "UPCOMING" row, DOWN moves to the challenges list (`_selectedUpcomingIdx = -1`); from the top of the challenges list (`isScrolledToTop()`), UP moves back to the last "UPCOMING" row.
- The selected row gets `BadgeFormat.drawSelectionTint()` (full-row background tint) plus, for challenge/MORE rows, `drawSelectionMarker()` (left accent bar). "UPCOMING" rows only show this highlight when selected via UP/DOWN — not on touch.
- `_scrollOffset`/`_selectedUpcomingIdx` persist across pushing/popping detail pages — `applyData()` only resets them on the initial load (`!_hasData`), not on subsequent refreshes.

SELECT/tap opens a detail page or the all-challenges page, depending on what's selected/tapped:

- An "UPCOMING" row → `GarminBadgesUpcomingDetailView` via `showUpcomingDetail()`.
- The "MORE" row (`atMoreRow()`/`moreRowAt()`, shown when `hasMoreChallenges()`) → `GarminBadgesAllChallengesView` via `showAllChallenges()`.
- A challenge row → `GarminBadgesChallengeDetailView` via `showChallengeDetail()`.
- On the all-challenges page, SELECT/tap on a row → `GarminBadgesChallengeDetailView`. BACK pops back to the main page (default `BehaviorDelegate` behavior).

Input dispatch:

- `ScrollDelegate.onSelect()` (shared base) always returns `false`. A touchscreen tap is translated by the system into a coordinate-less `onSelect()` call before `onTap(clickEvent)`; returning `false` lets `onTap()` run with real coordinates.
- The physical START/STOP button (`KEY_ENTER`) is handled directly via `onKeyPressed()`/`onKeyReleased()`, independent of `onSelect()`/`onTap()`. On the main page, `onKeyPressed()` starts a 700ms (`MENU_HOLD_MS`) `_menuHoldTimer`. If released first, `onKeyReleased()` cancels the timer and runs the same SELECT navigation as a tap (above). If held past 700ms, `onMenuHoldTimer()` fires `onMenu()` instead (and `onKeyReleased()` then no-ops).
- MENU button, tapping the hamburger icon (top-right, `BadgeFormat.isMenuIconHit()`), or holding START/STOP all call `onMenu()`, which pushes `GarminBadgesMenuDelegate`'s `Menu2` (Refresh, plus "All Challenges" if `hasMoreChallenges()`).

## All-challenges page

When more than 5 challenges are returned, `GarminBadgesView` shows a "MORE" row after the 5th challenge. Selecting it, or pressing MENU from the main page (when `hasMoreChallenges()` is true), pushes `GarminBadgesAllChallengesView` via `WatchUi.pushView()` — it lists *all* challenges from the same response, in the same sorted order, using the same row layout/scrolling as the main page.

## Detail pages

`GarminBadgesChallengeDetailView` and `GarminBadgesUpcomingDetailView` are pushed via `ScrollableView.showChallengeDetail()`/`showUpcomingDetail()` with a plain `WatchUi.BehaviorDelegate()` (BACK pops back). Both:

- Wrap the badge name across multiple lines with `BadgeFormat.wrapText()`, sized to `BadgeFormat.textMaxWidth(w, h, y)` (the chord width at `y` on round/semi-round screens, so wrapped lines don't run under the bezel).
- Space lines using `dc.getFontHeight(font)` plus a `textGap` (`h * 0.02`), not fixed `h * 0.0X` fractions, so wrapped names and the lines below them don't crowd together.

`GarminBadgesChallengeDetailView` additionally shows a progress bar + percentage + fraction (or "No target"), then a status line ("Nd behind/ahead of schedule", "On track", or "Starts Nd" if `started` is `false`), then the duration line. `GarminBadgesUpcomingDetailView` shows "Starts Today"/"Starts Nd" and the duration line.

## Glance

`GarminBadgesGlanceView` (registered via `GarminBadgesApp.getGlanceView()`) is the small preview shown in the watch's widget glance loop. It makes its own `/api/watch` request (same auth/fetch pattern as the main view) and shows:

- **Line 1** — the title of the closest upcoming item: `upcoming[0].name` if `upcoming` is non-empty, otherwise the most urgent `challenges[0].name` (already sorted most-behind-first), otherwise "No challenges". If the shown item hasn't started yet (`upcoming[0]` always, or `challenges[0]` when `started` is `false`), "Today"/"Nd" (`days_until`/`days_until_start`) is appended to the title. If the text is wider than the glance, it's shown as a page-flip ticker via `BadgeFormat.pagedText()` (alternating whole-word chunks, `BadgeFormat.PAGE_DURATION_TICKS` ticks per page, driven by a 1Hz `Timer.Timer` started in `onShow()`/stopped in `onHide()`).
- **Middle** — a progress bar for that same item, filled by `progress_value/target_value` (clamped 0–1). Fill color follows `days_behind` like the main page's offset indicator: green if ahead (`<= -0.5`), red if behind (`>= 0.5`), gray if on track. Empty if the item is an upcoming badge or has no numeric target (`target_value == 0`).
- **Line 2** — count of `challenges` with `days_behind > 0`, shown as "`N` behind" (red if `N > 0`, gray otherwise).

Selecting/tapping the glance uses the default `GlanceViewDelegate` behavior (no custom delegate registered), which opens the app's `getInitialView()`.

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
