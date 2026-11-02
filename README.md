# Marquee

An iPhone app for finding live music in Los Angeles: what's on tonight, this week
or this month, at the venues you follow, plus shows it thinks you'd like. Every
act links to Spotify, Apple Music and YouTube.

## How it fits together

```
venue sites and feeds  →  scraper/  →  data/los-angeles.json  →  iPhone app
```

- **`scraper/`** is Python with no dependencies. It reads every venue, cleans the
  artist names, adds genres and similar artists, and writes one JSON feed. If a
  site fails, its last good shows are kept and the failure is listed in the feed.
- **`.github/workflows/scrape.yml`** reruns the scraper every 6 hours.
- **`ios/`** is the SwiftUI app. Your taste stays on your phone, and recommendations
  are worked out there from the feed.

## Everyday commands

```bash
cd scraper
python3 -m unittest test_titles    # parser tests
python3 scrape.py                  # refresh data/los-angeles.json
```

## Run it on your iPhone

1. Install Xcode from the App Store, open it once, then switch the command line tools:
   `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
2. Open `ios/Marquee.xcodeproj`.
3. Under Signing & Capabilities, choose your Apple ID as the Team. Change the bundle
   identifier if Xcode says it's taken.
4. Plug in your iPhone, select it, and press Run.

With a free Apple ID the app stops opening after 7 days until you press Run again.
The $99/year Apple Developer Program extends that to a year and adds TestFlight.

## Keep listings fresh

The GitHub Action commits a fresh `data/los-angeles.json` every 6 hours, and the app
downloads it from `FeedConfig.remoteURL` in `ios/Marquee/FeedStore.swift`. If a download
fails, the app keeps showing its last saved listings.

## Add a venue or a city

Venues and cities live in `scraper/venues.py`. Most venues only need a new `sources`
line that reuses an adapter. New site layouts get a function in `scraper/adapters.py`.
Other AEG cities (Denver, San Francisco, Seattle) already have the same feed format.

After editing the app's file list or settings in `ios/project.yml`, run `xcodegen generate`
from `ios/`.

## Checking the app without Xcode

`ios/harness/main.swift` compiles the app's code as a Mac program, runs logic checks on
the real feed and renders each screen to `ios/preview/`.

```bash
cd ios
swiftc -swift-version 5 -module-name MarqueeHarness -o /tmp/marquee-harness \
  $(ls Marquee/*.swift | grep -v MarqueeApp.swift) harness/main.swift
/tmp/marquee-harness ..
```

## Known gaps

The Troubadour, Zebulon, Viper Room, Largo, Hotel Cafe and others aren't covered yet:
their sites block automated requests or load shows through scripts. A free Ticketmaster
Discovery API key would likely fill several of these.

Listings and poster images belong to the venues. That's fine for your own phone, but
get permission or use official APIs before releasing this on the App Store.
