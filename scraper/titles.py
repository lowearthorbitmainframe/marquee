"""Turns messy show titles into a clean list of artist names."""
import html
import re
import unicodedata

NOISE = re.compile(
    r"\b(sold[\s-]*out|rescheduled|postponed|canceled|cancelled|new date|"
    r"moved to [\w\s]+|early show|late show|matinee|all ages|21\+|18\+|"
    r"limited tickets|low tickets|night (one|two|1|2)|day (one|two|1|2))\b[:!]*",
    re.I,
)
PRESENTS = re.compile(r"^.{2,60}?\s+presents?:?\s+", re.I)
# Text after " - " that describes a tour, not another act.
TOUR_WORDS = re.compile(
    r"\b(tour|live|anniversary|album|release|show|residency|edition|party|"
    r"celebration|festival|benefit|world|north america|in concert|haunting hour)\b",
    re.I,
)
SEPARATORS = re.compile(
    r"\s+(?:with special guests?|special guests?|and special guests?|with|w/|feat\.?|"
    r"ft\.?|featuring|plus|support(?:ing)?(?: from| by)?|b2b|x|vs\.?)\s+|\s+\+\s+|\s*,\s*|\s+/\s+|\s+_\s+|\s*\|\s*|:\s+",
    re.I,
)
ROLE_SUFFIX = re.compile(r"\s*\([^)]*\)\s*$")
TOUR_PHRASE = re.compile(r"^(live\b|an evening with\b|hosted by\b|the .* tour$)|\b(19|20)\d\d\b", re.I)
PLACEHOLDER = re.compile(r"\b(tba|tbd)\b|^(special guests?|guests?|more|and more|many more|friends|\+? ?more)$", re.I)
LEADING_LINK = re.compile(r"^(?:with|w/|and|&|\+|plus|performed by|featuring|feat\.?|ft\.?)\s+", re.I)

# Words that mean a title is not a band name. Those events stay in the feed,
# they just don't get artist links.
EVENT_WORDS = re.compile(
    r"\b(night|party|tribute|comedy|comedians?|karaoke|trivia|brunch|bingo|drag|"
    r"burlesque|open mic|showcase|festival|fest|rave|dance|workshop|podcast|"
    r"screening|market|halloween|n?ye|nye|new year|emo night|pass|kickoff|"
    r"tickets?|presents|tour|anniversary|records|residency|donate|gofundme|fundraiser)\b",
    re.I,
)
# If these appear anywhere in the title, the whole thing is an event, not a lineup.
WHOLE_EVENT = re.compile(
    r"\b(dance party|emo night|karaoke|trivia|bingo|open mic|comedy night)\b",
    re.I,
)
# The categories the app filters by. Sources can set one; otherwise the title decides.
CATEGORY_NAMES = ("music", "comedy", "film", "theater", "party", "other")
CATEGORIES = [
    ("comedy", re.compile(r"\b(comedy|comedians?|stand[- ]?up|improv)\b", re.I)),
    ("film", re.compile(r"\b(screening|film festival|movie night|in 35mm|in 70mm|double feature)\b", re.I)),
    ("theater", re.compile(r"\b(the musical|a new play|broadway)\b", re.I)),
    ("party", re.compile(r"\b(dance party|rave|dj night|emo night|karaoke|club night|drag|burlesque|b2b|"
                         r"all night long|open to close|extended set|afters|warehouse party|day party|"
                         r"techno|house music|drum (?:&|and) bass|dnb)\b", re.I)),
    ("other", re.compile(r"\b(podcast|market|bingo|trivia|workshop|brunch|in conversation)\b", re.I)),
]


def clean_text(value):
    if value is None:
        return ""
    text = html.unescape(str(value)).replace("\\'", "'")
    text = re.sub(r"<[^>]+>", " ", text)
    return re.sub(r"\s+", " ", text).strip()


def artist_key(name):
    """Stable lowercase key, so 'Beyoncé' and 'THE  Beyonce' can be compared."""
    text = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    text = re.sub(r"^the\s+", "", text.strip())
    text = text.replace("&", "and")
    return re.sub(r"[^a-z0-9]+", "", text)


def _strip_noise(title):
    text = clean_text(title)
    text = re.sub(r"\b(sold[\s-]*out|rescheduled|postponed)\s*[:!-]*", " ", text, flags=re.I)
    text = NOISE.sub(" ", text)
    text = re.sub(r"\(\s*\)", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip(" -–—:|")


def _is_plausible_artist(name):
    if not 2 <= len(name) <= 48 or len(name.split()) > 6:
        return False
    if EVENT_WORDS.search(name) or TOUR_PHRASE.search(name) or PLACEHOLDER.match(name):
        return False
    return bool(re.search(r"[A-Za-z0-9]", name))


def parse_artists(title):
    """'The Hails - Duckpond Tour with Meldrop' -> ['The Hails', 'Meldrop']"""
    text = _strip_noise(title)
    if WHOLE_EVENT.search(text):
        return []
    text = PRESENTS.sub("", text)
    text = re.sub(r"^an evening with\s+", "", text, flags=re.I)
    text = re.sub(r"\s+[–—]\s+", " - ", text)

    parts = text.split(" - ")
    kept = []
    for index, part in enumerate(parts):
        if index == 0 or not TOUR_WORDS.search(part):
            kept.append(part)
            continue
        # "Duckpond Tour with Meldrop": drop the tour, keep the support act.
        support = re.split(r"\s+(?:with|w/|feat\.?|ft\.?|featuring)\s+", part, maxsplit=1, flags=re.I)
        if len(support) == 2:
            kept.append(support[1])

    artists = []
    for piece in SEPARATORS.split(", ".join(kept)):
        name = ROLE_SUFFIX.sub("", piece).strip(" -–—:;*\"'“”")
        name = LEADING_LINK.sub("", name).strip()
        if _is_plausible_artist(name) and artist_key(name) not in [artist_key(a) for a in artists]:
            artists.append(name)
    return artists


def merge_artists(*groups):
    """Combine artist lists from structured fields, keeping order, dropping repeats."""
    merged = []
    seen = set()
    for group in groups:
        for name in group:
            key = artist_key(name)
            if key and key not in seen:
                seen.add(key)
                merged.append(name)
    return merged


def classify(title):
    for category, pattern in CATEGORIES:
        if pattern.search(title):
            return category
    return "music"


def is_sold_out(title):
    return bool(re.search(r"sold[\s-]*out", title or "", re.I))


def is_cancelled(title):
    return bool(re.search(r"\b(cancell?ed|postponed)\b", title or "", re.I))


def display_title(title):
    text = clean_text(title)
    text = re.sub(r"\s*[-–—:]*\s*\(?\bsold[\s-]*out\b\)?[!:]*\s*", " ", text, flags=re.I)
    return re.sub(r"\s+", " ", text).strip(" -–—:")
