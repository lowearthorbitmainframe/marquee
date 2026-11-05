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
from datetime import date, datetime, timezone
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
        r"\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b(?:,?\s*(\d{4}))?",
        text, re.I)
    if not match:
        return None
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
    for category in source["categories"]:
        for item in next_data(fetch("%s/%s" % (source["url"], category)))["events"]:
            seen[item["id"]] = item
        time.sleep(1)
    return [e for e in (dice_event(item) for item in seen.values()) if e]


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
            title = clean_text(item.get("title"))
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
        "start": parse_iso(clock),
        "ticket_url": item.get("url"),
        "image": images[-1].get("url") if images else None,
        "price": "From $%d" % round(prices[0]["min"]) if prices and prices[0].get("min") else None,
        "cancelled": status in ("cancelled", "postponed"),
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
            "apikey": key, "dmaId": source["dma"], "classificationName": "music",
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
