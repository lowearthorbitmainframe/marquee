#!/usr/bin/env python3
"""Builds data/<city>.json, the feed the iPhone app reads.

    python3 scrape.py                 # scrape and enrich
    python3 scrape.py --no-enrich     # scrape only
    python3 scrape.py --budget 400    # look up more new artists this run

A site that fails or returns nothing keeps its last good shows, and the failure
is recorded in the feed's `sources` list.
"""
import argparse
import gzip
import hashlib
import json
import os
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from zoneinfo import ZoneInfo

import adapters
import enrich as enricher
from titles import artist_key, classify, display_title, is_cancelled, is_sold_out, merge_artists, parse_artists
from venues import CITIES

DATA_DIR = Path(__file__).resolve().parent.parent / "data"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
PAUSE_BETWEEN_SOURCES = 2
# Apple sometimes matches a performer's name to a book author.
NON_MUSIC_GENRES = {"Graphic Novels", "General Nonfiction for Kids", "Self-Development", "Poetry"}


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept-Encoding": "gzip"})
    with urllib.request.urlopen(request, timeout=30) as response:
        body = response.read()
        if response.headers.get("Content-Encoding") == "gzip":
            body = gzip.decompress(body)
    return body.decode("utf-8", "ignore")


def to_local(value, zone):
    return value.replace(tzinfo=zone) if value.tzinfo is None else value.astimezone(zone)


def event_id(raw, start):
    seed = "%s|%s|%s" % (raw["venue"], start.date().isoformat(), artist_key(raw["title"]))
    return hashlib.sha1(seed.encode()).hexdigest()[:12]


def normalize(raw, zone):
    title = raw.get("title")
    if not title or not raw.get("start"):
        return None
    start = to_local(raw["start"], zone)
    artists = merge_artists(raw.get("artists") or [], parse_artists(title) if not raw.get("artists") else [])
    event = {
        "id": event_id(raw, start),
        "venueId": raw["venue"],
        "title": display_title(title),
        "artists": artists,
        "start": start.isoformat(),
        "category": classify(title),
        "soldOut": bool(raw.get("sold_out")) or is_sold_out(title),
        "cancelled": bool(raw.get("cancelled")) or is_cancelled(title),
    }
    # Some sites list only a date, which parses as midnight.
    if (start.hour, start.minute) == (0, 0):
        event["timeTBA"] = True
    if raw.get("doors"):
        event["doors"] = to_local(raw["doors"], zone).isoformat()
    for source_key, feed_key in [("ticket_url", "ticketUrl"), ("url", "url"), ("image", "image"),
                                 ("age", "age"), ("price", "price"), ("tour", "tour")]:
        # The app reads these as text, so one odd value must not reach the feed.
        if isinstance(raw.get(source_key), str) and raw[source_key]:
            event[feed_key] = raw[source_key]
    return event


def remove_duplicates(events):
    """Sources can list the same show. The first source to list it wins."""
    kept = []
    seen = set()
    for event in events:
        names = event["artists"] or [event["title"]]
        keys = {(event["venueId"], event["start"][:10], artist_key(name)) for name in names}
        if keys & seen:
            continue
        seen |= keys
        kept.append(event)
    return kept


def load_json(path, default):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return default


def source_label(source):
    return source.get("venue") or source["url"].split("/")[2]


def scrape_city(city, run_enrich, budget, minutes):
    zone = ZoneInfo(city["timezone"])
    today = datetime.now(zone).date()
    feed_path = DATA_DIR / (city["id"] + ".json")
    artist_path = DATA_DIR / "artists.json"
    previous = load_json(feed_path, {"events": [], "venues": {}})

    events = {}
    venues = {key: dict(value, id=key) for key, value in city["venues"].items()}
    sources = []

    for source in city["sources"]:
        label = source_label(source)
        adapter = getattr(adapters, source["adapter"])
        status = {"source": label, "adapter": source["adapter"]}
        try:
            raws = adapter(source, fetch, today)
            normalized = [dict(e, source=label) for e in (normalize(r, zone) for r in raws) if e]
            if not normalized:
                raise ValueError("no events found")
            for raw in raws:
                info = raw.get("venue_info")
                if info and raw["venue"] not in venues:
                    venues[raw["venue"]] = {"id": raw["venue"], "name": info["name"]}
                for field in ("address", "neighborhood", "lat", "lon"):
                    if info and info.get(field):
                        venues[raw["venue"]].setdefault(field, info[field])
            for event in normalized:
                events[event["id"]] = event
            status.update(ok=True, count=len(normalized))
        except adapters.Skip:
            continue
        except Exception as error:  # Keep the last good shows for this source.
            status.update(ok=False, error=str(error)[:200])
            kept = [e for e in previous["events"]
                    if e.get("source") == label or e["venueId"] == source.get("venue")]
            for event in kept:
                events.setdefault(event["id"], event)
            status["keptFromLastRun"] = len(kept)
        sources.append(status)
        print("%-30s %s" % (label, status.get("count", "FAILED: %s" % status.get("error"))))
        time.sleep(PAUSE_BETWEEN_SOURCES)

    upcoming = sorted(
        remove_duplicates(e for e in events.values() if e["start"][:10] >= today.isoformat()),
        key=lambda e: (e["start"][:10], bool(e.get("timeTBA")), e["start"], e["venueId"]),
    )

    cache = load_json(artist_path, {})
    if run_enrich:
        names = [name for event in upcoming for name in event["artists"]]
        deadline = time.time() + minutes * 60
        save = lambda: artist_path.write_text(json.dumps(cache, indent=0, sort_keys=True))
        done = enricher.enrich(names, cache, fetch, budget, deadline, save)
        save()
        print("looked up %d new artists; %d cached" % (done, len(cache)))

    # Only ship artist records this feed actually uses.
    used = {}
    for event in upcoming:
        for name in event["artists"]:
            key = artist_key(name)
            record = cache.get(key)
            if record and (record.get("genre") or record.get("related")):
                used[key] = {k: v for k, v in record.items() if k != "checked"}
                if used[key].get("genre") in NON_MUSIC_GENRES:
                    del used[key]["genre"]

    feed = {
        "version": 1,
        "city": {"id": city["id"], "name": city["name"], "timezone": city["timezone"]},
        "generatedAt": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "venues": sorted(venues.values(), key=lambda v: v["name"].lower()),
        "artists": used,
        "events": upcoming,
        "sources": sources,
    }
    feed_path.write_text(json.dumps(feed, ensure_ascii=False, separators=(",", ":")))
    failed = [s["source"] for s in sources if not s["ok"]]
    print("%s: %d events, %d venues, %d artists matched, %.0f KB" % (
        city["name"], len(upcoming), len(venues), len(used), feed_path.stat().st_size / 1024))
    if failed:
        print("failed: " + ", ".join(failed))
    return feed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--no-enrich", action="store_true")
    parser.add_argument("--budget", type=int, default=int(os.environ.get("ENRICH_BUDGET", "150")))
    parser.add_argument("--minutes", type=float, default=15, help="time limit for artist lookups")
    options = parser.parse_args()
    DATA_DIR.mkdir(exist_ok=True)
    for city in CITIES:
        scrape_city(city, not options.no_enrich, options.budget, options.minutes)
    return 0


if __name__ == "__main__":
    sys.exit(main())
