"""Finds each act's website, Instagram, TikTok and Bandcamp through MusicBrainz.

MusicBrainz asks for at most one request a second and a client name with a way
to reach the maintainer, so requests name the app and its public repository.
A wrong band's Instagram is worse than none, so a match must either link to the
same Apple Music page we already found, or be the only exact-name artist.
"""
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timedelta, timezone

from titles import artist_key

USER_AGENT = "Marquee/1.0 (https://github.com/lowearthorbitmainframe/marquee)"
DELAY = 1.5
RETRY_AFTER = timedelta(days=60)

# Which MusicBrainz URLs become which link, in the order the app prefers them.
LINK_PATTERNS = [
    ("website", lambda t, u: t == "official homepage"),
    ("instagram", lambda t, u: "instagram.com/" in u),
    ("tiktok", lambda t, u: "tiktok.com/" in u),
    ("bandcamp", lambda t, u: "bandcamp.com" in u),
    ("soundcloud", lambda t, u: "soundcloud.com/" in u),
]


def musicbrainz(path, params):
    url = "https://musicbrainz.org/ws/2/%s?%s" % (path, urllib.parse.urlencode(dict(params, fmt="json")))
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                data = json.loads(response.read())
            time.sleep(DELAY)
            return data
        except urllib.error.HTTPError as error:
            # 503 is MusicBrainz's rate limiter: wait and try again.
            if error.code != 503 or attempt == 2:
                raise
            time.sleep(5 * (attempt + 1))


def apple_id(url):
    match = re.search(r"/(\d+)(?:\?|$)", url or "")
    return match.group(1) if match else None


def collect_links(relations):
    links = {}
    for relation in relations:
        url = (relation.get("url") or {}).get("resource") or ""
        for name, matches in LINK_PATTERNS:
            if name not in links and matches(relation.get("type"), url):
                links[name] = url
    return links


def lookup_links(name, apple_url):
    """Returns ({link: url}, how it was matched), or ({}, reason) when unsure."""
    found = musicbrainz("artist/", {"query": 'artist:"%s"' % name, "limit": 8})
    candidates = [a for a in found.get("artists", []) if artist_key(a.get("name", "")) == artist_key(name)]
    if not candidates:
        return {}, "no match"

    wanted = apple_id(apple_url)
    if wanted:
        for candidate in candidates[:3]:
            detail = musicbrainz("artist/%s" % candidate["id"], {"inc": "url-rels"})
            relations = detail.get("relations", [])
            if any(wanted == apple_id((r.get("url") or {}).get("resource")) for r in relations
                   if "apple.com" in ((r.get("url") or {}).get("resource") or "")):
                return collect_links(relations), "apple"

    if len(candidates) == 1 and candidates[0].get("score") == 100:
        detail = musicbrainz("artist/%s" % candidates[0]["id"], {"inc": "url-rels"})
        return collect_links(detail.get("relations", [])), "only"
    return {}, "ambiguous"


def add_links(names, cache, deadline, save=None):
    """Adds `links` to cached artists, soonest shows first. Returns how many were checked."""
    now = datetime.now(timezone.utc)
    done = 0
    for name in dict.fromkeys(names):
        record = cache.get(artist_key(name))
        if not record:
            continue
        checked = record.get("linksChecked")
        if checked and now - datetime.fromisoformat(checked) < RETRY_AFTER:
            continue
        if time.time() > deadline:
            break
        try:
            links, how = lookup_links(name, record.get("appleUrl"))
        except Exception as error:  # A flaky lookup shouldn't stop the feed.
            print("  links skipped %s: %s" % (name, error))
            continue
        record["linksChecked"] = now.isoformat(timespec="seconds")
        if links:
            record["links"] = links
        record["linksMatch"] = how
        done += 1
        if save and done % 25 == 0:
            save()
    return done
