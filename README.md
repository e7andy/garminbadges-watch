# GarminBadges Watch App

A Garmin Connect IQ watch app that shows your [GarminBadges](https://garminbadges.com) stats at a glance.

## What it shows

- **Upcoming** — badges/challenges starting within the next 7 days (shown only when there are any)
- **Challenges** — your in-progress challenges (up to 3, or 2 when an Upcoming section is shown), sorted by completion percentage, each with a progress bar and fraction (e.g. `7/10 km`)

Data is fetched live from the GarminBadges API using your account's API key. Press the SELECT button to refresh.

## Setup

1. Install the app on your watch via the Connect IQ store (or sideload the `.prg` for development).
2. Open the **Garmin Connect** app on your phone → My Device → Apps → GarminBadges → Settings.
3. Paste your **API key** from [garminbadges.com/dashboard](https://garminbadges.com/dashboard) (Settings → API Key).
4. The **API URL** defaults to `https://api.garminbadges.com/api` — leave it unless you're pointing at a local dev server.

## Supported devices

Fenix 6/7/8, Epix 2, Enduro, Venu 2/3, Vivoactive 4/5/6, Forerunner 245–970, Instinct 2/3, Marq 2, and variants.

## Development

### Requirements

- [Garmin Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/) 3.1+ (tested on 9.2.0)
- A developer key — generate one at [developer.garmin.com](https://developer.garmin.com/connect-iq/connect-iq-basics/getting-started/)

### Build

```powershell
$SDK = "C:\Users\<you>\AppData\Roaming\Garmin\ConnectIQ\Sdks\<sdk-version>"
& "$SDK\bin\monkeyc.bat" -f jungle.xml -d fenix7 -o bin\GarminBadges.prg -y <path-to-developer-key> -l 2
```

### Run in simulator

```powershell
# Start the simulator first
& "$SDK\bin\connectiq.bat"

# Then sideload the built .prg
& "$SDK\bin\monkeydo.bat" bin\GarminBadges.prg fenix7
```

The app will show "Open Garmin Connect app to set API key" until you set the `ApiKey` property via **File → Edit Persistent Storage → Edit Application.Properties data**.

### API endpoint

The watch app calls `GET /api/watch` on the GarminBadges backend, authenticated with the user's `api_key` as a Bearer token. The backend source lives in the [garminbadges](https://github.com/andersvan/garminbadges) repo at `backend/app/Http/Controllers/Api/WatchController.php`.

## Project structure

```
garminbadges-watch/
├── manifest.xml                        # App metadata, permissions, target devices
├── jungle.xml                          # Build config
├── source/
│   ├── GarminBadgesApp.mc              # Entry point (AppBase)
│   ├── GarminBadgesView.mc             # UI rendering + API fetch
│   └── GarminBadgesDelegate.mc         # Input handling (SELECT = refresh)
└── resources/
    ├── drawables/                      # Launcher icon
    └── properties.xml                  # App properties + settings UI (ApiKey, ApiUrl)
```
