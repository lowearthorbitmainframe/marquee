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
# Bump when lookups learn new kinds of links, so every artist is checked again.
LINKS_VERSION = 2

# Which MusicBrainz URLs become which link, in the order the app prefers them.
LINK_PATTERNS = [
    ("website", lambda t, u: t == "official homepage"),
    ("instagram", lambda t, u: "instagram.com/" in u),
    ("tiktok", lambda t, u: "tiktok.com/" in u),
    ("bandcamp", lambda t, u: "bandcamp.com" in u),
    ("soundcloud", lambda t, u: "soundcloud.com/" in u),
    ("spotify", lambda t, u: "open.spotify.com/artist/" in u),
    ("youtube", lambda t, u: re.search(r"youtube\.com/(channel/|user/|c/|@)", u) is not None),
    ("applemusic", lambda t, u: "music.apple.com/" in u and "/artist/" in u),
    ("wikidata", lambda t, u: "wikidata.org/wiki/Q" in u),
]

# Wikidata properties for the same pages, and how each becomes a link.
WIKIDATA_LINKS = [
    ("website", "P856", "%s"),
    ("instagram", "P2003", "https://www.instagram.com/%s/"),
    ("tiktok", "P7085", "https://www.tiktok.com/@%s"),
    ("spotify", "P1902", "https://open.spotify.com/artist/%s"),
    ("youtube", "P2397", "https://www.youtube.com/channel/%s"),
    ("applemusic", "P2850", "https://music.apple.com/us/artist/%s"),
]
# Comedian, stand-up comedian, comedy writer... A same-named person with none of these isn't our act.
COMEDY_OCCUPATIONS = {"Q245068", "Q18545066", "Q2310145", "Q19204627", "Q1114448", "Q15077007", "Q20640696"}


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


def get_json(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=20) as response:
        data = json.loads(response.read())
    time.sleep(DELAY)
    return data


def wikidata_entities(ids):
    if not ids:
        return {}
    url = "https://www.wikidata.org/w/api.php?" + urllib.parse.urlencode(
        {"action": "wbgetentities", "ids": "|".join(ids), "props": "labels|aliases|claims", "languages": "en", "format": "json"})
    return get_json(url).get("entities", {})


def claim_values(entity, prop):
    values = []
    for claim in entity.get("claims", {}).get(prop, []):
        value = claim.get("mainsnak", {}).get("datavalue", {}).get("value")
        values.append(value.get("id") if isinstance(value, dict) else value)
    return [v for v in values if v]


def wikidata_links(entity):
    links = {}
    for name, prop, pattern in WIKIDATA_LINKS:
        values = claim_values(entity, prop)
        if values:
            links[name] = pattern % values[0]
    return links


def podcast_link(name):
    """A podcast with the comedian's name in its title, from Apple's directory."""
    url = "https://itunes.apple.com/search?" + urllib.parse.urlencode(
        {"media": "podcast", "entity": "podcast", "term": name, "limit": 10})
    key = artist_key(name)
    words = r"\b%s\b" % r"\W+".join(re.escape(w) for w in name.split())
    for result in get_json(url).get("results", []):
        host = artist_key(result.get("artistName", ""))
        if host == key or re.search(words, result.get("collectionName", ""), re.I):
            return result.get("collectionViewUrl", "").split("?")[0] or None
    return None


def lookup_comedian(name):
    """Comedians are rarely in MusicBrainz. Wikidata is used instead, but only a
    single same-named person whose occupations include comedy counts."""
    search = "https://www.wikidata.org/w/api.php?" + urllib.parse.urlencode(
        {"action": "wbsearchentities", "search": name, "language": "en", "type": "item", "limit": 7, "format": "json"})
    ids = [r["id"] for r in get_json(search).get("search", [])]
    key = artist_key(name)
    matches = []
    for entity in wikidata_entities(ids).values():
        names = [entity.get("labels", {}).get("en", {}).get("value", "")]
        names += [a.get("value", "") for a in entity.get("aliases", {}).get("en", [])]
        if key in {artist_key(n) for n in names} and COMEDY_OCCUPATIONS & set(claim_values(entity, "P106")):
            matches.append(entity)
    links = wikidata_links(matches[0]) if len(matches) == 1 else {}
    how = "wikidata" if len(matches) == 1 else ("ambiguous" if matches else "no match")
    podcast = podcast_link(name)
    if podcast:
        links["podcast"] = podcast
    return links, how


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


def with_wikidata(links):
    """MusicBrainz often links an act's Wikidata page, which may know its
    Spotify and YouTube pages when MusicBrainz doesn't."""
    page = links.pop("wikidata", None)
    if page:
        qid = page.rstrip("/").split("/")[-1]
        entity = wikidata_entities([qid]).get(qid, {})
        for kind, url in wikidata_links(entity).items():
            links.setdefault(kind, url)
    return links


def add_links(names, cache, deadline, save=None, comedians=frozenset()):
    """Adds `links` to cached artists, soonest shows first. Returns how many were checked.
    Names whose key is in `comedians` are looked up as comedians."""
    now = datetime.now(timezone.utc)
    done = 0
    for name in dict.fromkeys(names):
        key = artist_key(name)
        if not key:
            continue
        # Artists Apple hasn't been asked about yet still get links. The old
        # "checked" date makes the Apple lookup try them on its next pass.
        record = cache.setdefault(key, {"name": name, "checked": "1970-01-01T00:00:00+00:00"})
        checked = record.get("linksChecked")
        current = record.get("linksVersion", 1) >= LINKS_VERSION
        if checked and current and now - datetime.fromisoformat(checked) < RETRY_AFTER:
            continue
        if time.time() > deadline:
            break
        try:
            if key in comedians:
                links, how = lookup_comedian(name)
            else:
                links, how = lookup_links(name, record.get("appleUrl"))
                links = with_wikidata(links)
        except Exception as error:  # A flaky lookup shouldn't stop the feed.
            print("  links skipped %s: %s" % (name, error))
            continue
        record["linksChecked"] = now.isoformat(timespec="seconds")
        record["linksVersion"] = LINKS_VERSION
        if links:
            # Pages a ticket seller gave stay unless a lookup found that kind too.
            record["links"] = dict(record.get("links") or {}, **links)
        record["linksMatch"] = how
        done += 1
        if save and done % 25 == 0:
            save()
    return done
