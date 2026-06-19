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
│   ├── GarminBadgesView.mc                  # Main page: UI rendering (programmatic via dc.draw*) + HTTP fetch + 3-section selection state
│   ├── GarminBadgesDelegate.mc              # Input for the main page (see "Navigation & selection")
│   ├── GarminBadgesAllUpcomingView.mc       # "Next Badges" page: next upcoming badges (up to 10), scrollable
│   ├── GarminBadgesAllUpcomingDelegate.mc   # Input for the "Next Upcoming" page (see "Navigation & selection")
│   ├── GarminBadgesAllEndingSoonView.mc     # "Ending Soon" page: all challenges ending within 7 days, scrollable
│   ├── GarminBadgesAllEndingSoonDelegate.mc # Input for the "Ending Soon" page (see "Navigation & selection")
│   ├── GarminBadgesAllChallengesView.mc     # "All Challenges" page: all challenges sorted most-urgent first, scrollable
│   ├── GarminBadgesAllChallengesDelegate.mc # Input for the "All Challenges" page (see "Navigation & selection")
│   ├── GarminBadgesChallengeDetailView.mc   # Detail page for a single challenge (progress, status, duration)
│   ├── GarminBadgesUpcomingDetailView.mc    # Detail page for an upcoming badge (starts-in, duration)
│   ├── GarminBadgesDetailDelegate.mc        # Input for both detail pages: MENU/tap-icon opens the "View Online" menu
│   ├── GarminBadgesDetailMenuDelegate.mc    # Handles the detail pages' "View Online" menu selection
│   ├── GarminBadgesMenuDelegate.mc          # Options menu (Refresh)
│   ├── GarminBadgesGlanceView.mc            # Glance widget preview: title + progress bar + "behind" count
│   ├── ScrollableView.mc                    # Shared scroll/momentum/page-flip-ticker state for the scrollable pages
│   ├── ScrollDelegate.mc                    # Shared drag/flick/button scrolling for the scrollable pages' delegates
│   ├── BadgeFormat.mc                       # Shared formatting/drawing helpers (row layout, unit formatting, text wrapping/ticker, selection highlight, section titles/dividers)
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
& "$SDK\bin\monkeyc.bat" -f jungle.xml -d fenix7 -o bin\BadgeTracker.prg -y "C:\Users\e7and\My Drive\Backup\garmin\developer_key" -l 2
```

Output goes to `bin/BadgeTracker.prg` (ignored by `.gitignore`).

## Publishing to the Connect IQ Store

Until the app is published, sideloaded builds can't show a Settings screen in Garmin Connect Mobile (see "Settings on a real device" below) — publishing (even just submitting, before approval) registers the app's settings schema with Garmin's backend.

1. **Garmin Connect IQ Developer account** — as of late 2025, `apps.garmin.com` no longer hosts developer/upload functionality (it now redirects end users to the Connect IQ Store mobile app). Developer app management has moved to **[apps-developer.garmin.com](https://apps-developer.garmin.com)** — sign in there with the same Garmin account as `developer_key`'s registered public key. If `developer_key` was generated fresh, upload the matching public key (`developer_key.pub` / `.der`) under your account's profile so builds signed with it are accepted.
2. **Create the app listing** — "My Apps" → "Create App". Use the **same app ID** as `<iq:application id="...">` in `manifest.xml` (`a8e4c3b2-7f61-4d8e-9c2a-1b5f3e7d9a0c`) if the listing was created from this manifest; otherwise the portal assigns one and `manifest.xml` must be updated to match.
3. **Build a release package** covering all supported devices (the full `<iq:products>` list in `manifest.xml`), with debug info stripped:
   ```powershell
   $SDK = "C:\Users\e7and\AppData\Roaming\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2"
   & "$SDK\bin\monkeyc.bat" -f jungle.xml -o bin\BadgeTracker.iq -y "C:\Users\e7and\My Drive\Backup\garmin\developer_key" -e -r
   ```
   `-e`/`--package-app` produces an `.iq` store package (instead of a single-device `.prg`); `-r`/`--release` strips debug info. Omit `-d` — `-d` doesn't accept a comma-separated device list in this SDK version, so leaving it out builds for every device in `manifest.xml`'s `<iq:products>` automatically (prints "N OUT OF 101 DEVICES BUILT" progress).
4. **Upload `bin/BadgeTracker.iq`** to the app listing via the Developer Portal's "Upload App" / App Versions tab.
5. **Fill in store listing details**: name, description, category, supported devices (should match `manifest.xml`), screenshots, app store icon, and a privacy policy URL — use `https://garminbadges.com/privacy`. See "Store listing content" and "Required images" below.
6. **Submit for review.** Garmin reviews submissions (can take days). Once approved and published, users install via the Connect IQ Store / Garmin Connect Mobile app, and Connect Mobile's Settings screen will work (pulling `ApiKey`/`ApiUrl`/`MaxDurationDays` from the now-registered schema).
7. **Future updates** — repeat steps 3–4 (build + upload a new `.iq`); the portal auto-increments the version on each upload, no manifest version field to bump.

### Store listing content

- **Name**: `Badge Tracker` (matches `AppName` in `resources/properties.xml`; "Garmin Badges" is not allowed by the Connect IQ Store's trademark policy).
- **Description** (draft — adjust to fit the portal's character limit):

  > Track your [garminbadges.com](https://garminbadges.com) challenge progress right from your wrist.
  >
  > - NEXT BADGES gives you a heads-up on badges starting within 7 days.
  > - ENDING SOON surfaces your in-progress challenges that wrap up within a week, soonest first, each with an ahead/behind-schedule indicator.
  > - CHALLENGES lists your most urgent in-progress challenges, ranked by how far ahead or behind schedule you are, each with a live progress bar (e.g. 7/10 km).
  > - Select or tap any row for full details: progress, percentage, schedule status, and duration.
  > - A glance widget on your watch face loop shows your next badge or most urgent challenge with a progress bar, plus how many challenges are ending soon and how many you're behind on.
  > - Optionally hide long-running challenges by setting a maximum duration in Settings.
  >
  > Requires a free GarminBadges account — get your API key at garminbadges.com/dashboard (Settings → API Key) and enter it in this app's settings in Garmin Connect.

- **Category**: a "Tools" / "Data" style category (exact options are set by the portal at submission time).
- **Settings copy** (if the portal asks for per-setting descriptions, see "Setup" in `README.md` for the `ApiKey`/`ApiUrl`/`MaxDurationDays` wording).

### Required images

These are uploaded directly via the developer portal — they are not part of the build/`.iq` package.

- **App Store icon** — 500x500px, sRGB. Shown in store listings and search results. Allow ~10px padding, center the icon, and use a simple **solid (non-transparent) background** — this is a different design from `resources/drawables/launcher_icon.svg` (the small in-app/glance icon, which has a transparent background so it blends with the device's launcher/glance UI).
- **On-device icons** (optional) — 128x128px, sRGB, two variants: a full-color one for OLED displays and a low-color one (64-color palette) for memory-in-pixel displays.
- **Hero/banner image** (optional, promotional) — 1440x720px.
- **Screenshots** — each ≤500x500px and ≤150KB, captured from the simulator (`connectiq.bat` + `monkeydo.bat`, then Win+Shift+S to capture and crop/resize). Cover the app's main views, on at least one round device (most of `manifest.xml`'s targets are round):
  - Glance preview
  - Main page (UPCOMING / ENDING SOON / CHALLENGES sections)
  - An "All <Section>" page (e.g. All Challenges)
  - A detail page (challenge or upcoming)

## Simulator

```powershell
# Launch simulator
& "$SDK\bin\connectiq.bat"

# Sideload after building
& "$SDK\bin\monkeydo.bat" bin\BadgeTracker.prg fenix7
```

Set `ApiKey` in the simulator via **File → Edit Persistent Storage → Edit Application.Properties data**. The app shows an error message until a key is provided.

`MaxDurationDays` (numeric, 0-365, default 0) hides any challenge/upcoming badge whose `duration_days` exceeds it. `0` means no limit.

Since the app defines a glance (`getGlanceView()`), the simulator opens directly to the glance preview rather than the main view. Press **Enter** (or click the screen) to invoke the default `GlanceViewDelegate` and launch the full app — this is also how it works on a real device. Pressing BACK from there exits the app in the simulator rather than returning to the glance; that's a simulator-only limitation (the glance↔app handoff is OS-managed on a real device).

## Real device

1. Build the `.prg` (same command as above — it's signed with the developer key).
2. Connect the watch via USB; it mounts as a USB drive ("GARMIN").
3. Copy `bin/BadgeTracker.prg` into `GARMIN/APPS/` (create the folder if it doesn't exist).
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
- **Long badge names** — `BadgeFormat.pagedText()` shows the full name if it fits, otherwise a page-flip ticker (alternating whole-word chunks, `BadgeFormat.PAGE_DURATION_TICKS` ticks per page). `ScrollableView` drives this via a 1Hz `_tickerTimer` started in `onShow()`/stopped in `onHide()` (`_tickCount`, `tickCount()`). Used for challenge row names (`BadgeFormat.drawChallengeRow()`/`drawCompactRow()`, on the main page and the "All <Section>" pages) and "NEXT BADGES" row names on the main and "Next Badges" pages.
- **`$message` is reserved in Monkey C** if using Monkey C templates — use a different variable name.
- **Cross-class const access** — a `const` declared at class level (e.g. `const SECTION_UPCOMING = 0;` inside `class GarminBadgesView`) can't be referenced from another class as `GarminBadgesView.SECTION_UPCOMING` (`Cannot find symbol ':SECTION_UPCOMING' on class definition`). Put consts that need to be shared across classes in a `module` (e.g. `BadgeFormat.SECTION_UPCOMING`) instead — `Module.CONST` access works reliably.
- **Developer key** is at `C:\Users\e7and\My Drive\Backup\garmin\developer_key`.

## API endpoint

`GET /api/watch` — authenticated via `Authorization: Bearer <api_key>`.

Response shape:
```json
{
  "challenges": [
    { "id": 42, "name": "Challenge Name", "progress_value": 7000, "target_value": 10000, "unit_key": "mi_km", "days_behind": 2, "duration_days": 30, "started": true, "days_until_start": 0, "days_until_end": 5 }
  ],
  "upcoming": [
    { "id": 99, "name": "New Challenge", "days_until": 3, "duration_days": 7 }
  ]
}
```

`challenges` is up to 20 in-progress, time-limited badges in the **Challenges** category (`badge_categories.key == 'challenges'`, or `id == 4` as a fallback) — earned_date IS NULL, with both `start_date` and `end_date` set. Plain (non-Challenges) badges the user has joined with a start/end window are excluded, even though they'd otherwise match; only `upcoming` surfaces those (see below). A user can end up with more than one `user_badges` row for the same `badge_id` (`earned_number` 1, 2, ...) even for a non-repeatable badge (e.g. a duplicate row from a sync re-run) — if *any* row for a badge is already earned, the badge is excluded entirely (`whereNotIn`), even if a newer row with `earned_date IS NULL` exists for it; otherwise an already-completed badge could still show as "in progress" via that newer row. They're sorted with started badges (`start_date <= now`) first — ranked descending by "days behind schedule", `days_behind` = `(elapsed_fraction - progress_fraction) * total_days` of the challenge window — followed by badges whose `start_date` is still in the future, last. `started` is `start_date <= now`; for not-yet-started badges, `days_until_start` is `ceil(hours until start_date / 24)` (`0` for already-started badges). `days_until_end` is `ceil(hours until end_date / 24)`, signed: positive = ends in the future, `0` = ends today, negative = overdue.

`upcoming` is up to 10 badges, sorted by `start_date` ascending, drawn from two groups depending on the badge's category (`badge_categories.key == 'challenges'`, i.e. progress-tracked badges vs. plain one-off badges), excluding any badge already earned by the user (any `user_badges` row with `earned_date` set — same `whereNotIn` reasoning as `challenges` above) even if it's a plain badge active today:
- **Challenges-category** badges starting within the next 7 days, but only if the user has already joined (has a `user_badges` row) — these need to be joined to track progress, so an unjoined one isn't actionable here; it'll show up once joined and in progress.
- **Plain (non-Challenges)** badges starting within the next 7 days, or that started within the last 24 hours ("active today"), regardless of join status — these are one-off badges with no progress tracking, so there's nothing to "join" ahead of time in the same sense.

May be empty.

`duration_days` is the challenge window length (`end_date - start_date`, in days). For `upcoming` badges with no `end_date`, it's `0`. The view filters out any item whose `duration_days` exceeds the `MaxDurationDays` setting (`0` = no limit) via `filterByDuration()` in `onReceive()`.

`id` is the badge's numeric primary key, used to build a `https://garminbadges.com/badges/{id}` link via `BadgeFormat.badgeUrl()` (see "Detail pages" below). Stale `BadgeCache` data from before this field existed won't have it — `badgeUrl()` returns `null` in that case, and the "View Online" menu item still shows but no-ops when selected, rather than the menu failing to open at all.

Some challenges (e.g. "finish in the top 3" podium challenges) have no numeric target — `target_value` is `0` and `unit_key` is `null` for these. The view skips the progress bar/fraction and shows "No target" instead.

`progress_value`/`target_value` are in the badge's raw storage units (meters for `mi_km`, seconds for `seconds`) — formatting/unit conversion happens on-device in `formatFraction()`/`formatTime()`, not in the API. `days_behind` is a rounded integer; positive = behind schedule, negative = ahead, 0 = on track.

**JSON number gotcha**: `progress_value`/`target_value`/`days_behind` decode as `Lang.Number` when the JSON has no decimal point (e.g. `92901`) and `Lang.Float` when it does (e.g. `283686.49`). Mixing the two in arithmetic without converting causes integer division (silently truncates a fraction to `0`). Always go through `toFloatVal()` before doing math on these fields.

The main page has three sections, each hidden entirely when its item list is empty:

- **NEXT BADGES** — up to 3 `upcoming` badges (centered rows, name + `formatDaysUntil(days_until)`). `BadgeFormat.drawUpcomingRow()` highlights `days_until == 0` rows in red — plain (non-Challenges-category) badges that started within the last 24 hours ("active today").
- **ENDING SOON** — up to 3 `challenges` whose `days_until_end <= 7` (including overdue), sorted soonest-ending first via `GarminBadgesView.computeEndingSoon()`. Compact rows: name + "Ends Nd"/"Ends today" on the left, the `days_behind` indicator on the right.
- **CHALLENGES** — up to 5 `challenges` (existing most-behind-first sort). Compact rows: name + the `days_behind` indicator only, no progress bar.

Each compact row's `days_behind` indicator is "+Nd"/"-Nd"/"0d" (red/green/gray).

## Navigation & selection

The main page (`GarminBadgesView`) has section-level UP/DOWN selection across its three sections (NEXT BADGES / ENDING SOON / CHALLENGES, in `BadgeFormat.SECTION_UPCOMING/SECTION_ENDING_SOON/SECTION_CHALLENGES`) — not individual rows:

- Each `onUpdate()` rebuilds `_sectionIds`/`_sectionTops`/`_sectionBottoms` (parallel arrays — visible section ids in display order, and the pixel y-bounds of each section's row block), skipping any section whose item list is empty.
- `_selectedSectionIdx` indexes into `_sectionIds`. `GarminBadgesDelegate.onNextPage()`/`onPreviousPage()` (DOWN/UP) call `view.moveSelection(±1)`, which clamps `_selectedSectionIdx` to `[0, _sectionIds.size() - 1]`.
- The selected section's row block gets `BadgeFormat.drawSelectionTint()` (full-block background tint) plus `drawSelectionMarker()` (left accent bar), spanning all of that section's rows.
- `_selectedSectionIdx` persists across pushing/popping pages — `applyData()` only resets it to `0` on the initial load (`!_hasData`), not on subsequent refreshes.

SELECT/tap on any row opens that row's section as a full list page — there's no per-row detail navigation from the main page:

- `GarminBadgesView.sectionAt(y)` returns the section id whose row block contains screen y-coordinate `y`, or `-1`.
- `GarminBadgesView.selectedSection()` returns the currently UP/DOWN-selected section id (`_sectionIds[_selectedSectionIdx]`), or `-1` if no sections are visible.
- `GarminBadgesDelegate.openSection(sectionId)` maps a section id to `view.showAllUpcoming()` / `showAllEndingSoon()` / `showAllChallenges()`, each of which pushes the corresponding "All <Section>" view + delegate via `WatchUi.pushView()`.
- On an "All <Section>" page, SELECT/tap on a row opens `GarminBadgesChallengeDetailView` (Ending Soon / All Challenges) or `GarminBadgesUpcomingDetailView` (Next Badges). BACK pops back to the main page (default `BehaviorDelegate` behavior).

Input dispatch:

- `ScrollDelegate.onSelect()` (shared base) always returns `false`. A touchscreen tap is translated by the system into a coordinate-less `onSelect()` call before `onTap(clickEvent)`; returning `false` lets `onTap()` run with real coordinates.
- The physical START/STOP button (`KEY_ENTER`) is handled directly via `onKeyPressed()`/`onKeyReleased()`, independent of `onSelect()`/`onTap()`. On the main page, `onKeyPressed()` starts a 700ms (`MENU_HOLD_MS`) `_menuHoldTimer`. If released first, `onKeyReleased()` cancels the timer and calls `openSection(view.selectedSection())` — the same navigation as tapping the selected section. If held past 700ms, `onMenuHoldTimer()` fires `onMenu()` instead (and `onKeyReleased()` then no-ops).
- MENU button, tapping the hamburger icon (top-right, `BadgeFormat.isMenuIconHit()`), or holding START/STOP all call `onMenu()`, which pushes `GarminBadgesMenuDelegate`'s `Menu2` (just "Refresh" — there's no "All Challenges" shortcut since every section is directly tappable).

## "All <Section>" pages

Each main-page section has a corresponding full list page, pushed via `WatchUi.pushView(view, delegate, WatchUi.SLIDE_LEFT)` from `GarminBadgesView.showAllUpcoming()`/`showAllEndingSoon()`/`showAllChallenges()`:

- **`GarminBadgesAllUpcomingView`** ("NEXT BADGES") — lists all of `_upcoming` (up to 10, the API's full `upcoming` array), using the same centered single-line row format as the main page's NEXT BADGES rows (name + `formatDaysUntil(days_until)`, paged, with `days_until == 0` rows highlighted in red). Title is "NEXT BADGES" rather than "ALL UPCOMING" since the list isn't exhaustive — just the next 10. Uses its own `ALL_ROW_HEIGHT_FRAC = 0.12` row height. `upcomingAt(y)` maps a tap to an upcoming badge; SELECT/tap pushes `GarminBadgesUpcomingDetailView` via `showUpcomingDetail()`.
- **`GarminBadgesAllEndingSoonView`** ("ENDING SOON") — lists all of `_endingSoon` (every challenge with `days_until_end <= 7`, already sorted soonest-first), using full `BadgeFormat.drawChallengeRow()` rows (progress bar + fraction) at the inherited `ROW_HEIGHT_FRAC = 0.255`. `challengeAt(y)` maps a tap to a challenge; SELECT/tap pushes `GarminBadgesChallengeDetailView` via `showChallengeDetail()`.
- **`GarminBadgesAllChallengesView`** ("ALL CHALLENGES") — lists all of `_challenges` (up to 20, the API's full `challenges` array, most-urgent-first), using the same full-row layout as Ending Soon. `challengeAt(y)`/`showChallengeDetail()` as above.

All three extend `ScrollableView`/`ScrollDelegate` and share the same scroll/clip/selection-highlight/scroll-indicator structure: title + divider at the top, a clipped+scrollable viewport below, `drawSelectionTint()`/`drawSelectionMarker()` on the row at `viewportTop()`, and `BadgeFormat.drawScrollIndicator()`. Each shows its own empty-state message ("Nothing\nupcoming", "Nothing ending\nsoon", "No challenges\nin progress") when its list is empty.

## Detail pages

`GarminBadgesChallengeDetailView` and `GarminBadgesUpcomingDetailView` are pushed via `ScrollableView.showChallengeDetail()`/`showUpcomingDetail()` with `GarminBadgesDetailDelegate` (BACK pops back; MENU button, tapping the menu icon, or holding START/STOP per the platform's default `BehaviorDelegate.onMenu()` dispatch all open a `Menu2` with a single "View Online" item — `GarminBadgesDetailMenuDelegate.onSelect()` pops the menu and opens the badge's `https://garminbadges.com/badges/{id}` page on the phone via `Communications.openWebPage()`, or no-ops if `BadgeFormat.badgeUrl()` returned `null`. `onMenu()` always builds the menu regardless, since returning `false` would let the event fall through to the previously pushed view's delegate — e.g. the main page's "Refresh" menu — which is more confusing than a "View Online" item that no-ops until refreshed). Both:

- Wrap the badge name across multiple lines with `BadgeFormat.wrapText()`, sized to `BadgeFormat.textMaxWidth(w, h, y)` (the chord width at `y` on round/semi-round screens, so wrapped lines don't run under the bezel).
- Space lines using `dc.getFontHeight(font)` plus a `textGap` (`h * 0.02`), not fixed `h * 0.0X` fractions, so wrapped names and the lines below them don't crowd together.
- Draw `BadgeFormat.drawMenuIcon()` in the top-right corner, same as the main page, marking the menu as available.

`GarminBadgesChallengeDetailView` additionally shows a progress bar + percentage + fraction (or "No target"), then a status line ("Nd behind/ahead of schedule", "On track", or "Starts Nd" if `started` is `false`), then the duration line. `GarminBadgesUpcomingDetailView` shows "Starts Today"/"Starts Nd" and the duration line.

`Communications.openWebPage(url, params, options)` asks Garmin Connect Mobile to push a phone notification; if the user accepts, the URL opens in the phone's default browser. It only needs the `Communications` permission (already declared in `manifest.xml` for HTTP) and requires an active Bluetooth connection to the phone — there's no completion callback in this API, so the watch can't detect success/failure.

## Glance

`GarminBadgesGlanceView` (registered via `GarminBadgesApp.getGlanceView()`) is the small preview shown in the watch's widget glance loop. It makes its own `/api/watch` request (same auth/fetch pattern as the main view) and shows:

- **Line 1** — the title of the most urgent badge "to do", in priority order:
  1. `upcoming[0].name` if `upcoming` is non-empty — a badge starting within 7 days. "Nd" (`days_until`) is appended to the title.
  2. Otherwise, the `challenges` entry with the soonest `days_until_end` (`<= 7`, via `findEndingSoon()`), with "Ends Nd"/"Ends today" (`BadgeFormat.formatEndsIn()`) appended.
  3. Otherwise, the most urgent `challenges[0]` (already sorted most-behind-first by the API), with "Today"/"Nd" (`days_until_start`) appended if `started` is `false`.
  4. Otherwise, "No challenges".

  If the text is wider than the glance, it's shown as a page-flip ticker via `BadgeFormat.pagedText()` (alternating whole-word chunks, `BadgeFormat.PAGE_DURATION_TICKS` ticks per page, driven by a 1Hz `Timer.Timer` started in `onShow()`/stopped in `onHide()`).
- **Middle** — a progress bar for that same item, filled by `progress_value/target_value` (clamped 0–1) via the shared `applyChallenge()` helper. Fill color follows `days_behind` like the main page's offset indicator: green if ahead (`<= -0.5`), red if behind (`>= 0.5`), gray if on track. Empty if the item is an `upcoming` badge or has no numeric target (`target_value == 0`).
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
