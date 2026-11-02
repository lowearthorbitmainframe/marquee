"""Adds genre, photo, a direct Apple Music link and similar artists to each act.

Uses Apple's and Deezer's free public lookups, which need no key. Results are
cached in data/artists.json, so each run only looks up names it hasn't seen.
Apple allows roughly 20 lookups a minute, hence the delay and per-run budget.
"""
import json
import time
import urllib.parse
from datetime import datetime, timedelta, timezone

from titles import artist_key

APPLE_DELAY = 3.2
RETRY_MISSES_AFTER = timedelta(days=30)


def _lookup(fetch, url):
    return json.loads(fetch(url))


def lookup_apple(name, fetch):
    query = urllib.parse.urlencode({"term": name, "entity": "musicArtist", "limit": 5, "country": "US"})
    results = _lookup(fetch, "https://itunes.apple.com/search?" + query).get("results", [])
    for result in results:
        if artist_key(result.get("artistName", "")) == artist_key(name):
            return {"genre": result.get("primaryGenreName"), "appleUrl": result.get("artistLinkUrl")}
    return {}


def lookup_deezer(name, fetch):
    query = urllib.parse.urlencode({"q": name, "limit": 5})
    results = _lookup(fetch, "https://api.deezer.com/search/artist?" + query).get("data", [])
    for result in results:
        if artist_key(result.get("name", "")) == artist_key(name):
            related = _lookup(fetch, "https://api.deezer.com/artist/%d/related?limit=12" % result["id"])
            return {
                "image": result.get("picture_medium"),
                "fans": result.get("nb_fan"),
                "related": [a["name"] for a in related.get("data", [])],
            }
    return {}


def enrich(names, cache, fetch, budget, deadline=None, save=None):
    """Fills `cache` in place, saving as it goes. Returns how many names were looked up."""
    now = datetime.now(timezone.utc)
    done = 0
    for name in sorted(set(names)):
        key = artist_key(name)
        if not key:
            continue
        cached = cache.get(key)
        if cached:
            matched = cached.get("genre") or cached.get("related")
            age = now - datetime.fromisoformat(cached["checked"])
            if matched or age < RETRY_MISSES_AFTER:
                continue
        if done >= budget or (deadline and time.time() > deadline):
            break
        record = {"name": name, "checked": now.isoformat(timespec="seconds")}
        try:
            record.update(lookup_apple(name, fetch))
            record.update(lookup_deezer(name, fetch))
        except Exception as error:  # A flaky lookup shouldn't stop the feed.
            print("  enrich skipped %s: %s" % (name, error))
            time.sleep(APPLE_DELAY * 3)
            continue
        cache[key] = record
        done += 1
        if save and done % 25 == 0:
            save()
        time.sleep(APPLE_DELAY)
    return done
