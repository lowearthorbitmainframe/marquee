"""One function per website layout. Each returns a list of raw event dicts:

    {venue, title, start, doors?, artists?, ticket_url?, url?, image?, age?,
     price?, sold_out?, cancelled?}

`start` and `doors` are naive local datetimes (or timezone-aware ones); scrape.py
normalizes them. Adapters raise on layout changes so the last good data is kept.
"""
import json
import os
import re
import time
import unicodedata
import urllib.parse
from datetime import date, date as date_type, datetime, timezone
from zoneinfo import ZoneInfo

from titles import clean_text, parse_artists


LA = ZoneInfo("America/Los_Angeles")


class Skip(Exception):
    """This source isn't configured, which is not a failure."""


# Other spellings of venues, so every source files shows under one venue.
VENUE_ALIASES = {
    "the-dock-at-the-historic-sears-building": "the-dock-at-historic-sears-building",
    "the-greek-theatre": "greek-theatre",
    "greek-theatre-los-angeles": "greek-theatre",
    "the-fonda-theatre": "fonda-theatre",
    "the-roxy-theatre": "the-roxy",
    "roxy-theatre": "the-roxy",
    "the-teragram-ballroom": "teragram-ballroom",
    "whisky-a-go-go-west-hollywood": "whisky-a-go-go",
    "the-whisky-a-go-go": "whisky-a-go-go",
    "wiltern": "the-wiltern",
    "the-troubadour": "troubadour",
    "hollywood-palladium-los-angeles": "hollywood-palladium",
    "lodge-room-highland-park": "lodge-room",
    "the-ford": "the-ford",
    "ford-theatres": "the-ford",
    "john-anson-ford-amphitheatre": "the-ford",
    "the-belasco-theater": "the-belasco",
    "belasco": "the-belasco",
    "the-observatory-santa-ana": "the-observatory",
    "observatory": "the-observatory",
    "moroccan-lounge": "the-moroccan-lounge",
    "the-masonic-lodge-at-hollywood-forever": "hollywood-forever-masonic-lodge",
    "garden-amp": "garden-amphitheatre",
    "the-wayfarer-costa-mesa": "the-wayfarer",
    # Ticketmaster's spellings.
    "academy-nightclub": "academy-la",
    "catch-one-disco": "catch-one",
    "el-rey-theatre-los-angeles": "el-rey-theatre",
    "glass-house": "the-glass-house",
    "orpheum-theatre": "the-orpheum-theatre",
    "peacock-theater-la": "peacock-theater",
    "roxy-theatre-ca": "the-roxy",
    "shrine-auditorium-ca": "shrine-auditorium",
    "the-fox-theater-pomona": "fox-theater-pomona",
    "the-novo-by-microsoft": "the-novo",
    "hollywood-pantages-theatre": "pantages-theatre",
    "improv-comedy-club-irvine": "irvine-improv",
    "improv-comedy-club-hollywood": "hollywood-improv",
    "brea-improv-comedy-club": "brea-improv",
}


def slugify(name):
    text = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    slug = re.sub(r"[^a-z0-9]+", "-", text).strip("-")
    return VENUE_ALIASES.get(slug, slug)


def infer_year(month, day, today):
    """Listings often omit the year. Dates far behind today mean next year."""
    candidate = date(today.year, month, day)
    if (today - candidate).days > 60:
        return today.year + 1
    return today.year


def parse_clock(text):
    match = re.search(r"(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m", text or "", re.I)
    if not match:
        return None
    hour = int(match.group(1)) % 12
    if match.group(3).lower() == "p":
        hour += 12
    return hour, int(match.group(2) or 0)


MONTHS = {name: i + 1 for i, name in enumerate(
    ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"])}


def parse_month_day(text, today):
    """Finds 'Oct 30', 'October 30', 'November 14th' and adds the year."""
    match = re.search(
        r"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*[.,]?\s+(\d{1,2})(?:st|nd|rd|th)?\b(?:,?\s*(\d{4}))?",
        text, re.I)
    if not match:
        # Some calendars write dates as "11.4" or "11/4".
        numeric = re.search(r"\b(\d{1,2})[./](\d{1,2})\b(?![./]\d)", text)
        if not numeric or not (1 <= int(numeric.group(1)) <= 12 and 1 <= int(numeric.group(2)) <= 31):
            return None
        month, day = int(numeric.group(1)), int(numeric.group(2))
        return date(infer_year(month, day, today), month, day)
    month = MONTHS[match.group(1).lower()]
    day = int(match.group(2))
    year = int(match.group(3)) if match.group(3) else infer_year(month, day, today)
    return date(year, month, day)


def combine(day, clock):
    """No clock means midnight, which scrape.py reports as Time TBA."""
    hour, minute = clock or (0, 0)
    return datetime(day.year, day.month, day.day, hour, minute)


def find_events(node):
    """Events can sit at the top level or deep inside @graph or ItemList."""
    if isinstance(node, list):
        for child in node:
            yield from find_events(child)
    elif isinstance(node, dict):
        if str(node.get("@type", "")).endswith("Event"):
            yield node
        else:
            for child in node.values():
                yield from find_events(child)


def json_ld_events(page):
    for block in re.findall(r"<script[^>]*ld\+json[^>]*>(.*?)</script>", page, re.S):
        try:
            yield from find_events(json.loads(block))
        except ValueError:
            continue


def image_url(value):
    """JSON-LD images can be a string, a list, or an ImageObject."""
    if isinstance(value, list):
        return image_url(value[0]) if value else None
    if isinstance(value, dict):
        return image_url(value.get("url") or value.get("contentUrl"))
    return value if isinstance(value, str) else None


def parse_iso(value):
    """AEG uses 'TBD' for times it hasn't set, so bad values return None.
    Some JSON-LD uses 'Nov 05, 2026', which has no time."""
    text = str(value).replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(text)
    except ValueError:
        pass
    try:
        return datetime.strptime(text, "%b %d, %Y")
    except ValueError:
        return None


def live_nation(source, fetch, today):
    """theecho.com, wiltern.com and friends. Their JSON-LD says 'The Echo' for
    both rooms, so the room comes from which page we fetched."""
    events = []
    for item in json_ld_events(fetch(source["url"])):
        events.append({
            "venue": source["venue"],
            "category": JSON_LD_CATEGORIES.get(item.get("@type")),
            "venue_info": {"address": json_ld_address(item.get("location"))},
            "title": item["name"],
            "start": parse_iso(item["startDate"]),
            "ticket_url": item.get("url") or offer_url(item.get("offers")),
            "image": image_url(item.get("image")),
            "cancelled": "Cancelled" in str(item.get("eventStatus")),
        })
    return events


def offer_url(offers):
    if isinstance(offers, list):
        offers = offers[0] if offers else None
    return offers.get("url") if isinstance(offers, dict) else None


# A venue's own JSON-LD says what kind of show each one is.
JSON_LD_CATEGORIES = {
    "MusicEvent": "music", "ComedyEvent": "comedy", "TheaterEvent": "theater",
    "ScreeningEvent": "film", "DanceEvent": "theater",
}


def json_ld_address(location):
    address = (location or {}).get("address") if isinstance(location, dict) else None
    if isinstance(address, str):
        return address
    if not isinstance(address, dict):
        return None
    region = " ".join(x for x in [address.get("addressRegion"), address.get("postalCode")] if x)
    parts = [address.get("streetAddress"), address.get("addressLocality"), region]
    return ", ".join(p for p in parts if p) or None


def greek(source, fetch, today):
    events = []
    for item in json_ld_events(fetch(source["url"])):
        events.append({
            "venue": source["venue"],
            "title": item["name"],
            "start": parse_iso(item["startDate"]),
            "ticket_url": item.get("url"),
            "image": image_url(item.get("image")),
        })
    return events


def aeg(source, fetch, today):
    """Goldenvoice's public feed. Covers The Roxy, El Rey, Fonda, Novo and more,
    so venues are created from the feed itself."""
    cities = set(source["cities"])
    events = []
    for item in json.loads(fetch(source["url"]))["events"]:
        venue = item.get("venue") or {}
        if venue.get("city") not in cities or item.get("private"):
            continue
        title = item["title"]
        names = parse_artists(title.get("headlinersText") or "") + parse_artists(title.get("supportingText") or "")
        media = item.get("media") or {}
        largest = max(media.values(), key=lambda m: m.get("width") or 0, default={})
        ticketing = item.get("ticketing") or {}
        events.append({
            "venue": slugify(venue["title"]),
            "venue_info": {
                "name": venue["title"],
                "address": venue.get("address_line"),
                "city": venue.get("city"),
            },
            "title": title.get("eventTitleText") or title.get("headlinersText"),
            "tour": title.get("tour"),
            "artists": names,
            "start": parse_iso(item["eventDateTimeISO"]),
            "doors": parse_iso(item.get("doorDateTime")),
            "ticket_url": ticketing.get("url"),
            "image": largest.get("file_name"),
            "age": item.get("age"),
            "price": clean_text(item.get("ticketPrice")) or None,
            "sold_out": "sold out" in str(ticketing.get("status")).lower(),
            "cancelled": "cancel" in str(ticketing.get("status")).lower(),
        })
    return events


def ticketweb_plugin(source, fetch, today):
    """WordPress 'tw-' calendar used by the Whisky and Teragram."""
    page = fetch(source["url"])
    cards = page.split('<div class="tw-name">')[1:]
    if not cards and "tw-name" not in page:
        raise ValueError("no tw-name cards found")
    # The image sits just before tw-name, so pair each card with the markup before it.
    chunks = page.split('<div class="tw-name">')
    events = []
    for index, card in enumerate(cards):
        # The title is a link on some sites and plain text on others.
        title_html = card.split("</div>", 1)[0]
        link = re.search(r'href="([^"]+)"', title_html) or re.search(r'href="([^"]+/(?:tm-event|event)/[^"]+)"', card)
        name = (link.group(1) if link else source["url"], clean_text(title_html))
        when = re.search(r'tw-event-date">([^<]+)<', card)
        if not name[1] or not when:
            continue
        day = parse_month_day(when.group(1), today)
        if not day:
            continue
        time_match = (re.search(r'tw-event-time">\s*([^<]*\d[^<]*)<', card)
                      or re.search(r'tw-event-time-complete">\s*([^<]*\d[^<]*)<', card))
        doors_match = re.search(r'tw-event-door-time">([^<]*)<', card)
        tickets = re.search(r'href="(https?://[^"]*(?:ticketweb|ticketmaster)\.com/[^"]+)"', card)
        images = re.findall(r'<img[^>]+src="([^"]+)"', chunks[index])
        doors_clock = parse_clock(doors_match.group(1)) if doors_match else None
        attractions = re.search(r'class="tw-attractions">(.*?)</div>', card, re.S)
        support = [clean_text(x) for x in re.findall(r"<span>(.*?)</span>", attractions.group(1))] if attractions else []
        events.append({
            "venue": source["venue"],
            "title": name[1],
            "artists": parse_artists(name[1]) + [a for n in support for a in parse_artists(n)],
            "start": combine(day, parse_clock(time_match.group(1)) if time_match else None),
            "doors": combine(day, doors_clock) if doors_clock else None,
            "url": name[0],
            "ticket_url": tickets.group(1).replace("&amp;", "&") if tickets else name[0],
            "image": images[-1] if images else None,
        })
    return events


def tessera(source, fetch, today):
    """Lodge Room embeds each show as an eventObjects.push({...}) script."""
    events = []
    for block in re.findall(r"eventObjects\.push\((\{.*?\})\);", fetch(source["url"]), re.S):
        item = json.loads(block)
        start = datetime.strptime(item["eventDate"].upper(), "%m/%d/%Y %I:%M %p")
        doors_clock = parse_clock(item.get("doors"))
        main = [clean_text(a) for a in item.get("mainArtist") or []]
        support = [clean_text(a) for a in item.get("additionalArtists") or []]
        names = []
        for artist in main + support:
            names.extend(parse_artists(artist))
        events.append({
            "venue": source["venue"],
            "title": " / ".join(main),
            "artists": names,
            "start": start,
            "doors": combine(start, doors_clock) if doors_clock else None,
            "url": item.get("link"),
            "ticket_url": item.get("link"),
            "image": item.get("image"),
        })
    return events


def rockhouse(source, fetch, today):
    """Rockhouse Partners WordPress theme, used by 1720."""
    page = fetch(source["url"])
    events = []
    cards = re.split(r'(?=<div[^>]*class\s*=\s*"[^"]*eventWrapper)', page)[1:]
    for card in cards:
        title = re.search(r'id="eventTitle"[^>]*href="([^"]+)"[^>]*title="([^"]*)"', card)
        date_match = re.search(r'id="eventDate"[^>]*>\s*([^<]+)<', card)
        if not title or not date_match:
            continue
        day = parse_month_day(date_match.group(1), today)
        if not day:
            continue
        times = re.search(r'eventDoorStartDate.*?<span[^>]*>\s*([^<]+)<', card, re.S)
        tickets = re.search(r'href="(https://www\.etix\.com/[^"]+)"', card)
        image = re.search(r'<img[^>]+src="([^"]+)"', card)
        age = re.search(r'eventAgeRestriction[^>]*>\s*([^<]+?)\s*<', card)
        events.append({
            "venue": source["venue"],
            "title": clean_text(title.group(2)),
            "start": combine(day, parse_clock(times.group(1)) if times else None),
            "url": title.group(1),
            "ticket_url": tickets.group(1) if tickets else title.group(1),
            "image": image.group(1) if image else None,
            "age": clean_text(age.group(1)) if age else None,
        })
    return events


def plot_cards(source, fetch, today):
    """The Mint's homepage cards."""
    page = fetch(source["url"])
    events = []
    for card in page.split('class="listing plotCard')[1:]:
        title = re.search(r'data-signal-object-title="([^"]+)"', card)
        when = re.search(r"listing-date-time[^>]*>\s*<span>([^<]+)</span>", card)
        url = re.search(r'href="(https://[^"]*/listing/[^"]+)"', card)
        if not title or not when:
            continue
        day = parse_month_day(when.group(1), today)
        if not day:
            continue
        tickets = re.search(r'href="(https://link\.dice\.fm/[^"]+)"', card)
        image = re.search(r'srcset="([^" ]+)', card)
        events.append({
            "venue": source["venue"],
            "title": clean_text(title.group(1)),
            "start": combine(day, parse_clock(when.group(1))),
            "url": url.group(1) if url else None,
            "ticket_url": tickets.group(1) if tickets else (url.group(1) if url else None),
            "image": image.group(1) if image else None,
        })
    return events


def table_listing(source, fetch, today):
    """Permanent Records Roadhouse: a hand-built HTML table."""
    page = fetch(source["url"])
    events = []
    for row in re.split(r"<tr[^>]*>", page, flags=re.I)[1:]:
        match = re.search(r"<i>\s*\w+,\s*([A-Za-z]+\s+\d{1,2}(?:st|nd|rd|th)?)\s*-\s*([^<]+)</i>(.*?)</font>", row, re.S | re.I)
        if not match or "coming soon" in match.group(3).lower():
            continue
        day = parse_month_day(match.group(1), today)
        if not day:
            continue
        names = [clean_text(n) for n in re.split(r"<br\s*/?>", match.group(3), flags=re.I)]
        names = [n for n in names if n]
        if not names:
            continue
        artists = []
        for name in names:
            artists.extend(parse_artists(name))
        tickets = re.search(r'href="(https://link\.dice\.fm/[^"]+)"', row)
        events.append({
            "venue": source["venue"],
            "title": ", ".join(names),
            "artists": artists,
            "start": combine(day, parse_clock(match.group(2))),
            "ticket_url": tickets.group(1) if tickets else source["url"],
        })
    return events


def next_data(page):
    match = re.search(r'<script id="__NEXT_DATA__"[^>]*>(.*?)</script>', page, re.S)
    if not match:
        raise ValueError("no __NEXT_DATA__ on page")
    return json.loads(match.group(1))["props"]["pageProps"]


def dice_event(item):
    venue = (item.get("venues") or [{}])[0]
    name = (venue.get("name") or "").strip()
    dates = item.get("dates") or {}
    start = parse_iso(dates.get("event_start_date"))
    if not name or "tba" in name.lower() or not start:
        return None
    city = venue.get("city") or {}
    location = city.get("location") or {}
    price = (item.get("price") or {}).get("amount_from")
    return {
        "venue": slugify(name),
        "venue_info": {
            "name": name,
            "address": (venue.get("address") or "").replace(", United States", ""),
            "neighborhood": city.get("name"),
            "lat": location.get("lat"),
            "lon": location.get("lng"),
        },
        "title": item["name"],
        "start": start,
        "ticket_url": "https://dice.fm/event/" + item["id"],
        "image": (item.get("images") or {}).get("square"),
        "price": "From $%d" % round(price / 100) if price else None,
        "sold_out": item.get("status") == "sold-out",
        "cancelled": item.get("status") == "cancelled",
    }


def dice_city(source, fetch, today):
    """DICE's city pages. Their robots rules allow listings that link back.
    Each category shows only its soonest 20 or so shows."""
    seen = {}
    categories = {}
    for path, category in source["categories"].items():
        for item in next_data(fetch("%s/%s" % (source["url"], path)))["events"]:
            seen[item["id"]] = item
            categories.setdefault(item["id"], category)
        time.sleep(1)
    events = []
    for item_id, item in seen.items():
        event = dice_event(item)
        if event:
            event["category"] = categories[item_id]
            events.append(event)
    return events


def dice_venues(source, fetch, today):
    """DICE venue pages, each with that room's own calendar."""
    seen = {}
    failures = []
    for slug in source["venues"]:
        try:
            profile = next_data(fetch("https://dice.fm/venue/" + slug))["profile"]
        except Exception as error:
            failures.append("%s: %s" % (slug, error))
            continue
        for section in profile.get("sections") or []:
            for item in section.get("events") or []:
                seen[item["id"]] = item
        time.sleep(1)
    if failures and not seen:
        raise ValueError("; ".join(failures)[:200])
    return [e for e in (dice_event(item) for item in seen.values()) if e]


LA_PHIL_SITES = {
    "Hollywood Bowl": "https://www.hollywoodbowl.com",
    "The Ford": "https://www.theford.com",
}


def la_phil(source, fetch, today):
    """One feed covers Walt Disney Concert Hall, the Hollywood Bowl and the Ford."""
    events = []
    for item in json.loads(fetch(source["url"]))["docs"]:
        event = item.get("event") or {}
        venue = (event.get("venue") or {}).get("title")
        if venue not in source["venues"]:
            continue
        custom = (item.get("attributes") or {}).get("custom") or {}
        start = parse_iso(item.get("startDate"))
        if not start:
            continue
        if item.get("hideStartTime"):
            start = datetime.combine(start.astimezone(LA).date(), datetime.min.time())
        names = []
        # Pop shows bill acts in separate fields; orchestra programs are not lineups.
        if venue in LA_PHIL_SITES:
            # Headliners are separated by line breaks in the formatted title.
            billed = re.sub(r"<br\s*/?>", " / ", event.get("richTitle_html") or "")
            names = parse_artists(clean_text(billed) or event.get("title") or "")
            for field in ("second_billing_html", "third_billing_html"):
                names += parse_artists(clean_text(custom.get(field)))
        site = LA_PHIL_SITES.get(venue, "https://www.laphil.com")
        events.append({
            "venue": slugify(venue),
            "venue_info": {"name": venue},
            "title": clean_text(item.get("displayTitle") or event.get("title")),
            "artists": names,
            "start": start,
            "url": site + item["url"],
            "ticket_url": site + item["url"],
            "image": (event.get("image") or {}).get("url"),
            "sold_out": item.get("bookingStatus") == "soldOut",
        })
    return events


def tribe_events(source, fetch, today):
    """WordPress sites running The Events Calendar, which has a public JSON feed."""
    events = []
    url = "%s/wp-json/tribe/events/v1/events?%s" % (source["url"], urllib.parse.urlencode(
        {"per_page": 50, "start_date": today.isoformat()}))
    skip = re.compile(source["skip"], re.I) if source.get("skip") else None
    for _ in range(source.get("pages", 4)):
        data = json.loads(fetch(url))
        for item in data.get("events") or []:
            categories = " ".join(c.get("name", "") for c in item.get("categories") or [])
            title = clean_text(re.split(r"<\s*/?br\s*/?>", item.get("title") or "")[0])
            if skip and (skip.search(title) or skip.search(categories)):
                continue
            venue = item.get("venue") if isinstance(item.get("venue"), dict) else {}
            name = clean_text(venue.get("venue")) or source["name"]
            address = ", ".join(x for x in [venue.get("address"), venue.get("city")] if x)
            image = item.get("image") if isinstance(item.get("image"), dict) else {}
            start = datetime.strptime(item["start_date"], "%Y-%m-%d %H:%M:%S")
            if item.get("all_day"):
                start = start.replace(hour=0, minute=0)
            events.append({
                "venue": source.get("venue") or slugify(name),
                "venue_info": {"name": name, "address": address or None},
                "title": title,
                "start": start,
                "url": item.get("url"),
                "ticket_url": item.get("website") or item.get("url"),
                "image": image.get("url"),
                "price": clean_text(item.get("cost")) or None,
            })
        url = data.get("next_rest_url")
        if not url:
            break
        time.sleep(1)
    return events


def eventbrite_organizer(source, fetch, today):
    """An organizer's Eventbrite page, for rooms with no site of their own."""
    data = next_data(fetch(source["url"]))
    events = []
    for item in data.get("upcomingEvents") or []:
        start = parse_iso("%sT%s" % (item.get("start_date"), item.get("start_time")))
        if not start:
            continue
        image = item.get("image") or {}
        availability = item.get("ticket_availability") or {}
        events.append({
            "venue": source["venue"],
            "title": item["name"],
            "start": start,
            "ticket_url": item.get("url"),
            "image": image.get("url"),
            "sold_out": availability.get("is_sold_out"),
            "cancelled": item.get("is_cancelled"),
        })
    return events


def squarespace_events(source, fetch, today):
    """A Squarespace events page. The Smell tags each band on the event."""
    data = json.loads(fetch(source["url"] + "?format=json"))
    base = "{0.scheme}://{0.netloc}".format(urllib.parse.urlsplit(source["url"]))
    events = []
    for item in data.get("upcoming") or []:
        names = []
        for tag in item.get("tags") or []:
            if not re.search(r"\b(19|20)\d\d\b", tag):
                names.extend(parse_artists(tag))
        events.append({
            "venue": source["venue"],
            # The Smell titles events with the date, so the lineup reads better.
            "title": " / ".join(names) or clean_text(item["title"]),
            "artists": names,
            "start": datetime.fromtimestamp(item["startDate"] / 1000, timezone.utc),
            "url": base + item["fullUrl"],
            "ticket_url": base + item["fullUrl"],
            "image": item.get("assetUrl"),
        })
    return events


def troubadour(source, fetch, today):
    """The Troubadour's homepage, which gives dates but no times."""
    events = []
    seen = set()
    # The site sometimes answers with a short placeholder page, so try again.
    for attempt in range(3):
        page = fetch(source["url"])
        if 'class="date"' in page:
            break
        time.sleep(5)
    for card in re.split(r'class="(?:splide__slide|eventItem)[" ]', page)[1:]:
        day_match = re.search(r'class="date">\s*([^<]+?)\s*<', card)
        title = re.search(r'<h3[^>]*>\s*<a href="([^"]+)"[^>]*>(.*?)</a>', card, re.S)
        if not day_match or not title:
            continue
        day = parse_month_day(day_match.group(1), today)
        if not day or title.group(1) in seen:
            continue
        seen.add(title.group(1))
        tickets = re.search(r'<a href="([^"]+)"[^>]*class="tickets', card)
        image = re.search(r'<img[^>]+src="([^"]+)"', card)
        tagline = re.search(r'class="tagline">\s*(.*?)\s*</h4>', card, re.S)
        events.append({
            "venue": source["venue"],
            "title": clean_text(title.group(2)),
            "tour": clean_text(tagline.group(1)) if tagline else None,
            "start": combine(day, None),
            "url": title.group(1),
            "ticket_url": tickets.group(1).replace("&amp;", "&") if tickets else title.group(1),
            "image": image.group(1) if image else None,
            "sold_out": "soldout" in card.lower().replace(" ", ""),
        })
    return events


# Music, Arts & Theatre, and Film.
TICKETMASTER_SEGMENTS = {"KZFzniwnSyZfZ7v7nJ": "music", "KZFzniwnSyZfZ7v7na": "theater", "KZFzniwnSyZfZ7v7nn": "film"}


def ticketmaster_category(item):
    classification = (item.get("classifications") or [{}])[0]
    segment = TICKETMASTER_SEGMENTS.get((classification.get("segment") or {}).get("id"), "other")
    genre = ((classification.get("genre") or {}).get("name") or "").lower()
    if segment == "theater" and "comedy" in genre:
        return "comedy"
    if segment == "music" and genre in ("dance/electronic", "electronic", "house", "techno"):
        return "party"
    if segment == "theater" and genre not in ("theatre", "musical", "opera", "dance", "classical", "performance art", "children's theatre", "magic & illusion", "cultural", "spectacular", "circus & specialty acts", "puppetry", "variety"):
        return "theater" if "theat" in genre or "music" in genre else "other"
    return segment


def ticketmaster_links(attraction):
    """A performer's own pages, as Ticketmaster lists them for that show."""
    external = attraction.get("externalLinks") or {}
    links = {}
    for ours, theirs in (("website", "homepage"), ("instagram", "instagram"), ("tiktok", "tiktok"), ("soundcloud", "soundcloud")):
        url = ((external.get(theirs) or [{}])[0]).get("url")
        if url:
            links[ours] = url
    return links


TICKETMASTER_NOT_SHOWS = re.compile(r"\b(parking|vip|package|suite|premium|shuttle|upgrade|voucher|gift card|add-?on)\b", re.I)


def parse_ticketmaster(item):
    if TICKETMASTER_NOT_SHOWS.search(item.get("name", "")):
        return None
    embedded = item.get("_embedded") or {}
    venue = (embedded.get("venues") or [{}])[0]
    start_info = (item.get("dates") or {}).get("start") or {}
    if not venue.get("name") or not start_info.get("localDate"):
        return None
    clock = "%sT%s" % (start_info["localDate"], start_info.get("localTime") or "00:00:00")
    images = sorted(item.get("images") or [], key=lambda i: i.get("width") or 0)
    prices = item.get("priceRanges") or []
    location = venue.get("location") or {}
    status = ((item.get("dates") or {}).get("status") or {}).get("code")
    return {
        "venue": slugify(venue["name"]),
        "venue_info": {
            "name": venue["name"],
            "address": ", ".join(x for x in [(venue.get("address") or {}).get("line1"), (venue.get("city") or {}).get("name")] if x),
            "city": (venue.get("city") or {}).get("name"),
            "lat": float(location["latitude"]) if location.get("latitude") else None,
            "lon": float(location["longitude"]) if location.get("longitude") else None,
        },
        "title": item["name"],
        "artists": [a["name"] for a in embedded.get("attractions") or [] if a.get("name")],
        "artist_links": {a["name"]: ticketmaster_links(a) for a in embedded.get("attractions") or []
                         if a.get("name") and ticketmaster_links(a)},
        "start": parse_iso(clock),
        "ticket_url": item.get("url"),
        "image": images[-1].get("url") if images else None,
        "price": "From $%d" % round(prices[0]["min"]) if prices and prices[0].get("min") else None,
        "cancelled": status in ("cancelled", "postponed"),
        "category": ticketmaster_category(item),
    }


def ticketmaster(source, fetch, today):
    """Ticketmaster's Discovery API. Needs a free key in TM_API_KEY."""
    key = os.environ.get("TM_API_KEY")
    if not key:
        raise Skip()
    cities = set(source["cities"])
    events = []
    for page in range(source.get("pages", 5)):
        query = urllib.parse.urlencode({
            "apikey": key, "dmaId": source["dma"], "segmentId": ",".join(TICKETMASTER_SEGMENTS),
            "size": 200, "page": page, "sort": "date,asc", "locale": "en-us",
        })
        try:
            data = json.loads(fetch("https://app.ticketmaster.com/discovery/v2/events.json?" + query))
        except Exception as error:
            raise ValueError(type(error).__name__ + ": " + str(error).replace(key, "***"))
        for item in (data.get("_embedded") or {}).get("events") or []:
            event = parse_ticketmaster(item)
            if event and event["venue_info"]["city"] in cities:
                events.append(event)
        info = data.get("page") or {}
        if page + 1 >= (info.get("totalPages") or 0):
            break
        time.sleep(0.3)
    return events


def new_beverly(source, fetch, today):
    """Quentin Tarantino's New Beverly Cinema."""
    events = []
    for card in fetch(source["url"]).split('<article class="event-card')[1:]:
        link = re.search(r'href="([^"]+)"', card)
        title = re.search(r'event-card__title">\s*(.*?)\s*</h4>', card, re.S)
        month = re.search(r'event-card__month">([^<]+)<', card)
        number = re.search(r'event-card__numb">(\d+)<', card)
        if not (link and title and month and number):
            continue
        day = parse_month_day("%s %s" % (month.group(1), number.group(1)), today)
        clock = re.search(r'event-card__time">([^<]+)<', card)
        note = re.search(r'event-card__link">\s*([^<]+?)\s*<', card)
        image = re.search(r'<img src="([^"]+)"', card)
        events.append({
            "venue": source["venue"],
            "title": clean_text(title.group(1)),
            "start": combine(day, parse_clock(clock.group(1)) if clock else None),
            "url": link.group(1),
            "ticket_url": link.group(1),
            "image": image.group(1) if image else None,
            "sold_out": bool(note and "sold out" in note.group(1).lower() and "door" not in note.group(1).lower()),
        })
    return events


def improv(source, fetch, today):
    """Improv comedy clubs. Lineups follow 'ft.' in the title."""
    events = []
    for card in re.split(r'<a class="item[ "]', fetch(source["url"]))[1:]:
        link = re.search(r'href="([^"]+)"', card)
        month = re.search(r"<dt>(\w+)</dt>\s*<dd>(\d+)", card)
        main = re.search(r'lt-main">(.*?)</span>', card, re.S) or re.search(r"<h3>(.*?)</h3>", card, re.S)
        if not (link and month and main):
            continue
        day = parse_month_day("%s %s" % month.groups(), today)
        rest = re.search(r'lt-rest">(.*?)</span>', card, re.S)
        times = re.search(r'class="times">(.*?)</div>', card, re.S)
        clocks = [parse_clock(t) for t in re.findall(r"<span>([^<]+)</span>", times.group(1))] if times else []
        room = re.search(r'class="city">\s*@?\s*([^<]+?)\s*<', card)
        image = re.search(r'data-src="([^"]+)"', card)
        lineup = clean_text(rest.group(1)) if rest else ""
        lineup = re.sub(r"^\s*(ft\.?|feat\.?|featuring|with|w/)\s*", "", lineup, flags=re.I)
        url = urllib.parse.urljoin(source["url"], link.group(1))
        # One card can list several showtimes on the same day.
        for clock in [c for c in clocks if c] or [None]:
            events.append({
                "venue": source["venue"],
                "title": clean_text(main.group(1)),
                "tour": room.group(1) if room else None,
                "artists": [n.strip() for n in re.split(r",\s*|\s+and\s+|\s*&\s*", lineup) if 2 <= len(n.strip()) <= 40],
                "start": combine(day, clock),
                "url": url,
                "ticket_url": url,
                "image": image.group(1) if image else None,
                "sold_out": "soldout" in card.replace(" ", "").lower(),
            })
    return events


def laugh_factory(source, fetch, today):
    """Laugh Factory sells through Eventbrite but lists shows with real timestamps."""
    page = fetch(source["url"])
    events = []
    for card in page.split('<time class="')[1:]:
        stamp = re.search(r'dateTime="([^"]+)"', card)
        title = re.search(r'_title">(.*?)</h3>', card, re.S)
        if not (stamp and title):
            continue
        lineup = re.search(r'_description">(.*?)</p>', card, re.S)
        ticket = re.search(r"eventbrite-checkout-(\d+)", card)
        names = re.split(r",\s*|\s+and\s+", clean_text(lineup.group(1)).rstrip("!.")) if lineup else []
        events.append({
            "venue": source["venue"],
            "title": re.sub(r"\s+\d{1,2}:\d{2}\s*[AP]M$", "", clean_text(title.group(1))),
            "artists": [n.strip() for n in names if 2 <= len(n.strip()) <= 40],
            "start": parse_iso(stamp.group(1)),
            "ticket_url": "https://www.eventbrite.com/e/%s" % ticket.group(1) if ticket else source["url"],
            "url": source["url"],
        })
    return events


CINEMATHEQUE_VENUES = {"Los Feliz Theatre": "los-feliz-3", "Aero Theatre": "aero-theatre", "Egyptian Theatre": "egyptian-theatre"}


def cinematheque(source, fetch, today):
    """American Cinematheque runs the Egyptian, the Aero and the Los Feliz 3."""
    events = []
    fields = "id,title,link,acf"
    for page in range(1, source.get("pages", 4) + 1):
        url = "%s?per_page=100&page=%d&orderby=date&order=desc&_fields=%s" % (source["url"], page, fields)
        try:
            items = json.loads(fetch(url))
        except Exception:
            break
        for item in items:
            acf = item.get("acf") or {}
            hero = acf.get("event_hero") or {}
            locations = (acf.get("location_section") or {}).get("locations") or [{}]
            place = (locations[0].get("location_select") or {}).get("name")
            if place not in CINEMATHEQUE_VENUES or not hero.get("dates"):
                continue
            try:
                day = datetime.strptime(hero["dates"].title(), "%a %b %d, %Y").date()
            except ValueError:
                continue
            if day < today:
                continue
            details = acf.get("event_details") or {}
            director = clean_text(details.get("director"))
            events.append({
                "venue": CINEMATHEQUE_VENUES[place],
                "title": clean_text(hero.get("hero_title") or (item.get("title") or {}).get("rendered")),
                "tour": "Directed by " + director if director else None,
                "start": combine(day, parse_clock(hero.get("times"))),
                "url": item.get("link"),
                "ticket_url": item.get("link"),
                "image": hero.get("image_url"),
                "price": clean_text(hero.get("pricing")) or None,
                "sold_out": bool(hero.get("sold_out")),
            })
        if len(items) < 100:
            break
        time.sleep(1)
    return events


def club_events(source, fetch, today):
    """The Exchange LA, Academy, Avalon and Bardot sites, which share one template."""
    events = []
    for card in fetch(source["url"]).split('class="events__item"')[1:]:
        date = re.search(r"(\d{1,2})\.(\d{1,2})\.(\d{2})\b", card)
        link = re.search(r'href="(https://[^"]+/event/[^"]+)"', card)
        title = re.search(r'event__content-title[^>]*>(.*?)</', card, re.S)
        if not (date and link and title):
            continue
        month, day, year = (int(x) for x in date.groups())
        image = re.search(r'data-lazy-srcset="([^" ]+)', card)
        tickets = re.search(r'href="(https://[^"]*(?:ticketweb|eventbrite|tixr|seetickets)[^"]+)"', card)
        clock = re.search(r"\b(\d{1,2}(?::\d{2})?\s*[ap]\.?m)\b", clean_text(card), re.I)
        events.append({
            "venue": source["venue"],
            "title": clean_text(title.group(1)),
            "start": combine(date_type(2000 + year, month, day), parse_clock(clock.group(1)) if clock else None),
            "url": link.group(1),
            "ticket_url": tickets.group(1).replace("&amp;", "&") if tickets else link.group(1),
            "image": image.group(1) if image else None,
        })
    return events


def nightjar_cinema(source, fetch, today):
    """Vidiots and the Frida run on the same cinema platform, whose 'coming soon'
    page lists every upcoming screening as JSON-LD."""
    events = []
    for item in json_ld_events(fetch(source["url"])):
        start = parse_iso(item.get("startDate"))
        if not start:
            continue
        # Names arrive as "Primetime - 11/4/26 @ 7:30 pm".
        title = re.sub(r"\s+-\s+\d{1,2}/\d{1,2}/\d{2}\s+@.*$", "", clean_text(item.get("name")))
        offers = item.get("offers") if isinstance(item.get("offers"), list) else [item.get("offers") or {}]
        events.append({
            "venue": source["venue"],
            "title": title,
            "start": start,
            "ticket_url": item.get("url"),
            "url": item.get("url"),
            "image": image_url(item.get("image")),
            "sold_out": any("SoldOut" in str((o or {}).get("availability")) for o in offers),
        })
    return events


def alamo(source, fetch, today):
    """Alamo Drafthouse's schedule. Only special screenings and repertory
    series are kept, so new releases don't crowd out everything else."""
    data = json.loads(fetch(source["url"]))["data"]
    special = {}
    for presentation in data.get("presentations") or []:
        if presentation.get("event") or presentation.get("primaryCollectionSlug"):
            special[presentation["slug"]] = presentation
    cinemas = {c["id"]: c.get("name") for c in (data.get("market") or [{}])[0].get("cinemas") or []}
    # Markets with several theaters map each one to its own venue.
    venue_for = {cid: (source.get("cinemas") or {}).get(name, source.get("venue")) for cid, name in cinemas.items()}
    events = []
    for session in data.get("sessions") or []:
        presentation = special.get(session.get("presentationSlug"))
        if not presentation or session.get("isHidden") or session.get("status") not in (None, "ONSALE", "SOLDOUT"):
            continue
        show = presentation.get("show") or {}
        event = presentation.get("event") or {}
        series = (presentation.get("primaryCollectionSlug") or "").replace("-", " ").title()
        hero = (show.get("landscapeHeroImage") or {}).get("uri")
        url = "%s/show/%s" % (source.get("site", "https://drafthouse.com/los-angeles"), show.get("slug", presentation["slug"]))
        venue = venue_for.get(session.get("cinemaId"), source.get("venue"))
        if not venue:
            continue
        events.append({
            "venue": venue,
            "title": clean_text(event.get("title") or show.get("title")),
            "tour": series or None,
            "start": datetime.fromisoformat(session["showTimeClt"]),
            "url": url,
            "ticket_url": url,
            "image": hero,
            "sold_out": session.get("status") == "SOLDOUT",
        })
    return events


def ticketweb_index(source, fetch, today):
    """Some TicketWeb sites list every upcoming show in their search box data,
    as "Title MM/DD" with a link. There are no times, so they show as TBA."""
    events = []
    pattern = re.compile(r'EventData\.events\.push\(\{"value"\s*:\s*"(.*?)\s+(\d{1,2})/(\d{1,2})"\s*,.*?"url"\s*:\s*"([^"]+)"', re.S)
    for title, month, day, url in pattern.findall(fetch(source["url"])):
        month, day = int(month), int(day)
        if not (1 <= month <= 12 and 1 <= day <= 31):
            continue
        events.append({
            "venue": source["venue"],
            "title": clean_text(title.encode().decode("unicode_escape", "ignore") if "\\u" in title else title),
            "start": combine(date(infer_year(month, day, today), month, day), None),
            "url": url,
            "ticket_url": url,
        })
    return events


def seetickets_list(source, fetch, today):
    """The SeeTickets WordPress listing, used by the Chapel, Thee Stork Club and others."""
    events = []
    for card in fetch(source["url"]).split("seetickets-list-event-container")[1:]:
        title = re.search(r'class="[^"]*\btitle"[^>]*>\s*<a href="([^"]+)"[^>]*>(.*?)</a>', card, re.S)
        day = re.search(r'class="[^"]*\bdate"[^>]*>([^<]+)<', card)
        if not (title and day):
            continue
        when = parse_month_day(day.group(1), today)
        if not when:
            continue
        show = re.search(r'see-showtime[^>]*>([^<]+)<', card)
        doors = re.search(r'see-doortime[^>]*>([^<]+)<', card)
        headliner = re.search(r'class="[^"]*headliners"[^>]*>([^<]+)<', card)
        support = re.search(r'Supporting Talent:\s*([^<]+)<', card)
        image = re.search(r'<img[^>]+src="([^"]+)"', card)
        age = re.search(r'class="ages">([^<]+)<', card)
        price = re.search(r'class="price">([^<]+)<', card)
        names = parse_artists(clean_text(headliner.group(1)) if headliner else clean_text(title.group(2)))
        if support:
            names += parse_artists(clean_text(support.group(1)))
        doors_clock = parse_clock(doors.group(1)) if doors else None
        events.append({
            "venue": source["venue"],
            "title": clean_text(title.group(2)),
            "artists": names,
            "start": combine(when, parse_clock(show.group(1)) if show else None),
            "doors": combine(when, doors_clock) if doors_clock else None,
            "url": title.group(1).replace("&amp;", "&"),
            "ticket_url": title.group(1).replace("&amp;", "&"),
            "image": image.group(1) if image else None,
            "age": clean_text(age.group(1)) if age else None,
            "price": clean_text(price.group(1)) if price else None,
        })
    return events


def webflow_shows(source, fetch, today):
    """Webflow venue sites list shows as collection items. `card`, `title` and
    `date` in the source say which class names this site uses."""
    page = fetch(source["url"])
    events = []
    for card in page.split(source["card"])[1:]:
        link = re.search(r'href="([^"]*(?:/shows?/|tixr\.com|/events?/)[^"]*)"', card)
        title = re.search(r'class="[^"]*%s[^"]*"[^>]*>([^<]+)<' % source["title"], card) if source.get("title") else None
        text = clean_text(card)
        when = parse_month_day(text, today)
        if not (link and when):
            continue
        name = clean_text(title.group(1)) if title else None
        if not name:
            # The UC Theatre names shows only in the link: /shows/rexx-life-raj-14-nov
            slug = re.sub(r"-\d{1,2}-[a-z]{3}$", "", link.group(1).rstrip("/").split("/")[-1])
            name = slug.replace("-", " ").title()
        clocks = re.findall(r"\b\d{1,2}(?::\d{2})?\s*[ap]\.?m\b", text, re.I)
        image = re.search(r'url\((?:&quot;|")?(https://[^&")]+)', card) or re.search(r'<img[^>]+src="(https://[^"]+)"', card)
        url = urllib.parse.urljoin(source["url"], link.group(1))
        events.append({
            "venue": source["venue"],
            "title": name,
            "start": combine(when, parse_clock(clocks[-1]) if clocks else None),
            "doors": combine(when, parse_clock(clocks[0])) if len(clocks) > 1 else None,
            "url": url,
            "ticket_url": url,
            "image": image.group(1) if image else None,
            "sold_out": "sold out" in text.lower() and "w-condition-invisible" not in card[:400],
        })
    return events


def dated_cards(source, fetch, today):
    """Sites whose show cards carry a machine-readable date. The source names the
    card marker and title class; dates come from a datetime or content attribute."""
    events = []
    for card in re.split(source["card"], fetch(source["url"]))[1:]:
        stamp = re.search(r'(?:datetime|content)="([^"]*\d{4}[^"]*)"', card)
        title = re.search(r'class="[^"]*%s[^"]*"[^>]*>(.*?)</' % source["title"], card, re.S)
        link = re.search(r'href="(https?://[^"]+)"', card)
        if not (stamp and title):
            continue
        start = parse_iso(stamp.group(1))
        if not start:
            try:
                start = datetime.strptime(re.sub(r"\s+", " ", stamp.group(1)).strip().upper(), "%B %d, %Y %I:%M%p")
            except ValueError:
                day = parse_month_day(stamp.group(1), today)
                start = combine(day, parse_clock(stamp.group(1))) if day else None
        if not start:
            continue
        room = re.search(r'class="room-tag[^"]*">([^<]+)<', card)
        image = re.search(r'<img[^>]+src="(https://[^"]+)"', card)
        venue = source["venue"]
        if room and source.get("rooms"):
            venue = source["rooms"].get(clean_text(room.group(1)), venue)
        events.append({
            "venue": venue,
            "title": clean_text(title.group(1)),
            "start": start,
            "url": link.group(1) if link else source["url"],
            "ticket_url": link.group(1) if link else source["url"],
            "image": image.group(1) if image else None,
            "sold_out": "sold-out" in card[:300] or "sold out" in clean_text(card[:600]).lower(),
        })
    return events


def bampfa(source, fetch, today):
    """The Berkeley Art Museum and Pacific Film Archive calendar."""
    events = []
    for card in fetch(source["url"]).split('class="calendar-event"')[1:]:
        day = re.search(r'popupboxthing-date">([^<]+)<', card)
        clock = re.search(r'popupboxthing-time">([^<]+)<', card)
        title = re.search(r'class="title">\s*<a href="([^"]+)">(.*?)</a>', card, re.S)
        if not (day and title):
            continue
        try:
            when = datetime.strptime(clean_text(day.group(1)), "%A, %B %d, %Y").date()
        except ValueError:
            continue
        image = re.search(r"<img src='([^']+)'", card)
        url = urllib.parse.urljoin(source["url"], title.group(1))
        # The museum's tours and talks share this calendar; only films are kept.
        if not ("director" in card or "cb_person" in card):
            continue
        events.append({
            "venue": source["venue"],
            "title": clean_text(title.group(2)),
            "category": "film",
            "start": combine(when, parse_clock(clock.group(1)) if clock else None),
            "url": url,
            "ticket_url": url,
            "image": image.group(1) if image else None,
        })
    return events


def roxie(source, fetch, today):
    """The Roxie's month grid: one cell per day, each film with its showtimes."""
    page = fetch(source["url"])
    # The grid opens on the current month.
    month_number, year = today.month, today.year
    events = []
    for cell in re.split(r'<td class="', page)[1:]:
        if cell.startswith("past-day"):
            continue
        number = re.search(r'calendar-day">(\d{1,2})<', cell)
        if not number:
            continue
        try:
            day = date(year, month_number, int(number.group(1)))
        except ValueError:
            continue
        for film in cell.split('<span class="film">')[1:]:
            title = re.search(r'film-title">(.*?)</p>', film, re.S)
            link = re.search(r'href="([^"]+)"', film)
            if not title:
                continue
            for clock in re.findall(r'film-showtime"[^>]*>([^<]+)<', film):
                events.append({
                    "venue": source["venue"],
                    "title": clean_text(title.group(1)),
                    "start": combine(day, parse_clock(clock)),
                    "url": link.group(1).replace("&#038;", "&") if link else source["url"],
                    "ticket_url": link.group(1).replace("&#038;", "&") if link else source["url"],
                })
    return events


def yoshis(source, fetch, today):
    """Yoshi's Oakland. Dates are in the Etix ticket link, like sun11826."""
    events = []
    for card in fetch(source["url"]).split('class="event-indv"')[1:]:
        title = re.search(r'class="headliner">\s*<a\s+href="([^"]+)"[^>]*>(.*?)</a>', card, re.S)
        ticket = re.search(r'href="(https://www\.etix\.com/[^"]+)"', card)
        if not (title and ticket):
            continue
        stamp = re.search(r"-(mon|tue|wed|thu|fri|sat|sun)(\d{3,4})(\d{2})-", ticket.group(1))
        if not stamp:
            continue
        # "sun11826" could be 11/8 or 1/18; the weekday says which.
        weekday = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"].index(stamp.group(1))
        digits, year = stamp.group(2), 2000 + int(stamp.group(3))
        when = None
        for cut in (1, 2):
            try:
                candidate = date(year, int(digits[:cut]), int(digits[cut:]))
            except ValueError:
                continue
            if candidate.weekday() == weekday:
                when = candidate
        if not when:
            continue
        image = re.search(r'<img src="([^"]+)"', card)
        events.append({
            "venue": source["venue"],
            "title": clean_text(title.group(2)).title() if clean_text(title.group(2)).isupper() else clean_text(title.group(2)),
            "start": combine(when, None),
            "url": title.group(1),
            "ticket_url": ticket.group(1),
            "image": urllib.parse.urljoin(source["url"], image.group(1)) if image else None,
        })
    return events
