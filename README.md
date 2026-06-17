# GarminBadges Watch App

A Garmin Connect IQ watch app that shows your [GarminBadges](https://garminbadges.com) stats at a glance.

## What it shows

The main page has up to three sections, each hidden when it has nothing to show:

- **Next Badges** — up to 3 badges starting within the next 7 days, with a "Nd" countdown.
- **Ending Soon** — up to 3 in-progress challenges ending within the next 7 days (including overdue ones), soonest first, each showing "Ends Nd"/"Ends today" plus a days-ahead/behind indicator.
- **Challenges** — your most urgent in-progress challenges (up to 5), ranked by how many days behind schedule you are, each with a days-ahead/behind indicator.

Long badge names that don't fit are shown as a page-flip ticker.

Data is fetched live from the GarminBadges API using your account's API key, and cached on-device so the last result shows immediately on launch while a fresh copy loads in the background.

## Navigation

- **UP/DOWN** move the highlighted section between Next Badges, Ending Soon, and Challenges (whichever are visible).
- **SELECT** (or tap any row) opens a full list page for that row's section — "Next Badges", "Ending Soon", or "All Challenges" — showing more detail (progress bars, fractions) and letting you scroll with UP/DOWN or drag/flick. From there, SELECT/tap a row opens its detail page (full progress, schedule status, duration). BACK returns to the previous page.
- **MENU** (or hold START/STOP, or tap the menu icon in the top-right corner) opens an options menu to refresh the data.

## Setup

1. Install the app on your watch via the Connect IQ Store (or sideload the `.prg` for development).
2. Open the **Garmin Connect** app on your phone → **Devices** → select your watch → **More** → **Connect IQ Store** (or **Apps**) → **Badge Tracker** → the gear/**Settings** icon.
3. Configure these settings:
   - **API Key** — paste your key from [garminbadges.com/dashboard](https://garminbadges.com/dashboard) (Settings → API Key). Required — the app shows an error until this is set.
   - **API URL** — defaults to `https://api.garminbadges.com/api`. Leave it unless you're pointing at a self-hosted/dev backend.
   - **Max Duration (days, 0 = no limit)** — hides any challenge or upcoming badge whose duration exceeds this many days (e.g. set to `31` to hide quarterly/annual challenges and only track shorter ones). `0` (default) shows everything.
4. Settings save automatically and take effect the next time the app refreshes (open it, or wait for its automatic refresh).

## Supported devices

Fenix 6/7/8, Epix 2, Enduro, Venu 2/3, Vivoactive 4/5/6, Forerunner 245–970, Instinct 3 AMOLED, Marq 2, and variants. (Instinct 2/2X/2S/3 Solar are not supported — their 32KB glance memory limit and/or small screen don't fit the current layout.)

## Development

### Requirements

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) 3.1+ (tested on 9.2.0)
- A developer key — generate one at [developer.garmin.com](https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/)

### Build

```powershell
$SDK = "C:\Users\<you>\AppData\Roaming\Garmin\ConnectIQ\Sdks\<sdk-version>"
& "$SDK\bin\monkeyc.bat" -f jungle.xml -d fenix7 -o bin\BadgeTracker.prg -y <path-to-developer-key> -l 2
```

### Run in simulator

```powershell
# Start the simulator first
& "$SDK\bin\connectiq.bat"

# Then sideload the built .prg
& "$SDK\bin\monkeydo.bat" bin\BadgeTracker.prg fenix7
```

The app will show "Open Garmin Connect app to set API key" until you set the `ApiKey` property via **File → Edit Persistent Storage → Edit Application.Properties data**.

Since the app defines a glance (`getGlanceView()`), the simulator opens directly to the glance preview. Press **Enter** (or click the screen) to launch the full app, the same way selecting the glance does on a real device.

### Run on a real device

1. Build the `.prg` as above (it's signed with your developer key, so it's ready to sideload).
2. Connect the watch via USB — it mounts as a USB drive (usually "GARMIN").
3. Copy `bin/BadgeTracker.prg` into the `GARMIN/APPS/` folder on the device (create it if missing).
4. Safely eject/disconnect the watch — it'll briefly show "Installing...", then the app appears in your apps list.
5. To see the glance, hold the menu button on the app in the apps list and look for "Add to Glances" (wording varies by device), then swipe up from the watch face to find it in the glance loop.

**Note on settings:** Garmin Connect Mobile's Apps → Badge Tracker → Settings screen only works for apps registered in the Connect IQ Developer Portal — a sideloaded `.prg` shows "No Settings" with no on-watch way to enter your API key. To test on a real device, temporarily set your API key as the default value of `ApiKey` in `resources/properties.xml` before building, and revert it afterwards.

### Publishing to the Connect IQ Store

See the "Publishing to the Connect IQ Store" section in `CLAUDE.md` for the full process: registering the app on the [Connect IQ Developer Portal](https://apps.garmin.com), building a release `.iq` package with `monkeyc -e -r` covering all supported devices, and submitting the store listing. Publishing (even pending review) is also what makes Garmin Connect Mobile's Settings screen work, since it pulls the settings schema from Garmin's backend.

### API endpoint

The watch app calls `GET /api/watch` on the GarminBadges backend, authenticated with the user's `api_key` as a Bearer token. The backend source lives in the [garminbadges](https://github.com/andersvan/garminbadges) repo at `backend/app/Http/Controllers/Api/WatchController.php`.

## Project structure

```
garminbadges-watch/
├── manifest.xml                        # App metadata, permissions, target devices
├── jungle.xml                          # Build config
├── source/
│   ├── GarminBadgesApp.mc                   # Entry point (AppBase)
│   ├── GarminBadgesView.mc                  # Main page: UI rendering + API fetch + 3-section selection state
│   ├── GarminBadgesDelegate.mc              # Main page input (SELECT/tap = open that section's list page, UP/DOWN = move section selection, MENU/hold START = options menu)
│   ├── GarminBadgesAllUpcomingView.mc       # "Next Badges" page: next upcoming badges (up to 10)
│   ├── GarminBadgesAllUpcomingDelegate.mc   # "Next Badges" page input (SELECT/tap = open detail page, UP/DOWN/drag/flick = scroll, BACK = pop)
│   ├── GarminBadgesAllEndingSoonView.mc     # "Ending Soon" page: all challenges ending within 7 days
│   ├── GarminBadgesAllEndingSoonDelegate.mc # "Ending Soon" page input (SELECT/tap = open detail page, UP/DOWN/drag/flick = scroll, BACK = pop)
│   ├── GarminBadgesAllChallengesView.mc     # "All Challenges" page: all challenges, most urgent first
│   ├── GarminBadgesAllChallengesDelegate.mc # "All Challenges" page input (SELECT/tap = open detail page, UP/DOWN/drag/flick = scroll, BACK = pop)
│   ├── GarminBadgesChallengeDetailView.mc   # Detail page for a single challenge
│   ├── GarminBadgesUpcomingDetailView.mc    # Detail page for an upcoming badge
│   ├── GarminBadgesMenuDelegate.mc          # Options menu (Refresh)
│   ├── GarminBadgesGlanceView.mc            # Glance preview: title + progress bar + behind count
│   ├── ScrollableView.mc                    # Shared scroll/momentum/ticker state
│   ├── ScrollDelegate.mc                    # Shared drag/flick/button scrolling
│   ├── BadgeFormat.mc                       # Shared formatting/drawing helpers
│   └── BadgeCache.mc                        # On-device cache of the latest API response
└── resources/
    ├── drawables/                      # Launcher icon
    └── properties.xml                  # App properties + settings UI (ApiKey, ApiUrl, MaxDurationDays)
```
