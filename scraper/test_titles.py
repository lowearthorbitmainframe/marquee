import unittest
from datetime import datetime
from zoneinfo import ZoneInfo

from adapters import image_url, parse_iso, parse_ticketmaster, slugify, ticketmaster_category
from links import apple_id, collect_links
from scrape import normalize, remove_duplicates
from titles import artist_key, classify, display_title, is_sold_out, parse_artists


class ParseArtists(unittest.TestCase):
    def check(self, title, expected):
        self.assertEqual(parse_artists(title), expected, title)

    def test_real_titles(self):
        self.check("Francis of Delirium with Beatrix", ["Francis of Delirium", "Beatrix"])
        self.check("Qendresa - SOLD OUT", ["Qendresa"])
        self.check("sahn - ten thousand mistakes Tour", ["sahn"])
        self.check("The Hails - Duckpond Tour with Meldrop", ["The Hails", "Meldrop"])
        self.check("young friend with marinelli", ["young friend", "marinelli"])
        self.check("aeter - Haunting Hour", ["aeter"])
        self.check("Echoe Events Presents BabyBartier, Sir Untre", ["BabyBartier", "Sir Untre"])
        self.check("System Error: Gentlemens Club, Neumonic, Snuffy", ["System Error", "Gentlemens Club", "Neumonic", "Snuffy"])
        self.check(
            "Michale Graves, Sophia Mengrosso, Leave It To Cleaver",
            ["Michale Graves", "Sophia Mengrosso", "Leave It To Cleaver"],
        )

    def test_lineup_survives_tribute_act(self):
        self.check(
            "Fair Warning (Tribute to Van Halen), Colonel Angus (AC/DC Tribute), Past Due",
            ["Fair Warning", "Colonel Angus", "Past Due"],
        )
        self.check("Marilyn Manson: Live in Los Angeles", ["Marilyn Manson"])
        self.check("Cody Dickinson (of North Mississippi Allstars)", ["Cody Dickinson"])

    def test_slash_and_underscore_lineups(self):
        self.check("lozenge / Blimp / Hysteria57", ["lozenge", "Blimp", "Hysteria57"])
        self.check("TALEEN KALI _ SALINE _ NEOCONS", ["TALEEN KALI", "SALINE", "NEOCONS"])
        self.check("POPFREE / **tba special guest** / Blazed", ["POPFREE", "Blazed"])
        self.check("MINERVA HOYT / FRUIT LO0OPS (CHI) / SLEEVIES (SEA)", ["MINERVA HOYT", "FRUIT LO0OPS", "SLEEVIES"])
        self.check("AC/DC", ["AC/DC"])

    def test_drops_connectors_and_placeholders(self):
        self.check("with Silverdeer", ["Silverdeer"])
        self.check("performed by Jimmy Rip", ["Jimmy Rip"])
        self.check("Thee Sacred Souls, Special Guest", ["Thee Sacred Souls"])
        self.check("Camp Flog Gnaw 2026", [])

    def test_fundraiser_text_is_not_an_artist(self):
        self.check("A Benefit for Mike Roche of TSOL - Please donate to the GoFundMe", [])

    def test_an_evening_with(self):
        self.check("An Evening With Faouzia", ["Faouzia"])

    def test_keeps_ampersand_band_names(self):
        self.check("Simon & Garfunkel", ["Simon & Garfunkel"])
        self.check("Mumford & Sons with Beatrix", ["Mumford & Sons", "Beatrix"])

    def test_role_suffix(self):
        self.check("Adron + Languid Machinations (DJ Set)", ["Adron", "Languid Machinations"])

    def test_event_titles_are_not_artists(self):
        self.assertEqual(parse_artists("Emo Night LA"), [])
        self.assertEqual(parse_artists("Electric Feels: Indie Rock + Electronic Dance Party"), [])


class Helpers(unittest.TestCase):
    def test_date_only_listing_has_no_made_up_time(self):
        zone = ZoneInfo("America/Los_Angeles")
        raw = {"venue": "greek-theatre", "title": "Damien Rice", "start": datetime(2027, 5, 25)}
        self.assertTrue(normalize(raw, zone)["timeTBA"])
        raw["start"] = datetime(2027, 5, 25, 20, 0)
        self.assertNotIn("timeTBA", normalize(raw, zone))

    def test_same_show_from_two_sources_is_kept_once(self):
        first = {"venueId": "1720", "start": "2026-11-07T20:00:00-08:00", "artists": ["Gutalax"], "title": "Gutalax", "source": "1720"}
        second = dict(first, title="GUTALAX with Friends", artists=["Gutalax", "Spasm"], source="dice.fm venues")
        other_day = dict(first, start="2026-11-08T20:00:00-08:00")
        self.assertEqual(remove_duplicates([first, second, other_day]), [first, other_day])

    def test_early_and_late_shows_from_one_source_both_stay(self):
        early = {"venueId": "laugh-factory-hollywood", "start": "2026-11-06T19:30:00-08:00", "artists": ["Earthquake"], "title": "All-Star Comedy", "source": "laugh-factory-hollywood"}
        late = dict(early, start="2026-11-06T22:00:00-08:00")
        self.assertEqual(remove_duplicates([early, late]), [early, late])

    def test_venue_spellings_merge(self):
        self.assertEqual(slugify("The Roxy Theatre"), "the-roxy")
        self.assertEqual(slugify("The Mint "), "the-mint")
        self.assertEqual(slugify("The Novo by Microsoft"), "the-novo")
        self.assertEqual(slugify("Hollywood Pantages Theatre"), "pantages-theatre")

    def test_ticketmaster_event(self):
        item = {
            "name": "Beach House", "url": "https://tm.example/1",
            "dates": {"start": {"localDate": "2026-12-01", "localTime": "19:30:00"}, "status": {"code": "onsale"}},
            "images": [{"url": "small.jpg", "width": 100}, {"url": "big.jpg", "width": 1000}],
            "priceRanges": [{"min": 45.5}],
            "_embedded": {
                "venues": [{"name": "Hollywood Bowl", "city": {"name": "Los Angeles"}, "address": {"line1": "2301 N Highland Ave"}, "location": {"latitude": "34.11", "longitude": "-118.33"}}],
                "attractions": [{"name": "Beach House"}, {"name": "Slow Pulp"}],
            },
        }
        event = parse_ticketmaster(item)
        self.assertEqual(event["venue"], "hollywood-bowl")
        self.assertEqual(event["artists"], ["Beach House", "Slow Pulp"])
        self.assertEqual(event["image"], "big.jpg")
        self.assertEqual(event["price"], "From $46")
        self.assertEqual(event["start"], datetime(2026, 12, 1, 19, 30))
        self.assertEqual(event["venue_info"]["lat"], 34.11)
        self.assertIsNone(parse_ticketmaster(dict(item, name="VIP Parking Pass")))

    def test_empty_lineup_is_not_guessed_from_title(self):
        zone = ZoneInfo("America/Los_Angeles")
        raw = {"venue": "walt-disney-concert-hall", "title": "Daniel Harding Leads Bernstein & Brahms",
               "start": datetime(2026, 11, 6, 20), "artists": []}
        self.assertEqual(normalize(raw, zone)["artists"], [])
        del raw["artists"]
        self.assertTrue(normalize(raw, zone)["artists"])

    def test_written_out_json_ld_date(self):
        self.assertEqual(parse_iso("Nov 05, 2026"), datetime(2026, 11, 5))
        self.assertIsNone(parse_iso("TBD"))

    def test_film_titles_are_not_artists(self):
        zone = ZoneInfo("America/Los_Angeles")
        raw = {"venue": "new-beverly-cinema", "title": "Double Harness / Peter Ibbetson",
               "start": datetime(2026, 11, 5, 19, 30), "category": "film"}
        event = normalize(raw, zone)
        self.assertEqual(event["category"], "film")
        self.assertEqual(event["artists"], [])

    def test_ticketmaster_categories(self):
        def item(segment, genre):
            return {"classifications": [{"segment": {"id": segment}, "genre": {"name": genre}}]}
        self.assertEqual(ticketmaster_category(item("KZFzniwnSyZfZ7v7nJ", "Rock")), "music")
        self.assertEqual(ticketmaster_category(item("KZFzniwnSyZfZ7v7na", "Comedy")), "comedy")
        self.assertEqual(ticketmaster_category(item("KZFzniwnSyZfZ7v7na", "Theatre")), "theater")
        self.assertEqual(ticketmaster_category(item("KZFzniwnSyZfZ7v7nn", "Drama")), "film")
        self.assertEqual(ticketmaster_category(item("KZFzniwnSyZfZ7v7nJ", "Dance/Electronic")), "party")

    def test_rave_titles_are_nightlife(self):
        self.assertEqual(classify("Basstripper: Dieselboy b2b Craze"), "party")
        self.assertEqual(classify("Carl Cox All Night Long"), "party")
        self.assertEqual(classify("Gilla Band"), "music")

    def test_links_from_musicbrainz_relations(self):
        relations = [
            {"type": "social network", "url": {"resource": "https://twitter.com/slowpulpband"}},
            {"type": "official homepage", "url": {"resource": "https://www.slowpulp.com/"}},
            {"type": "social network", "url": {"resource": "https://www.instagram.com/slowpulp/"}},
            {"type": "bandcamp", "url": {"resource": "https://slowpulp.bandcamp.com/"}},
        ]
        self.assertEqual(collect_links(relations), {
            "website": "https://www.slowpulp.com/",
            "instagram": "https://www.instagram.com/slowpulp/",
            "bandcamp": "https://slowpulp.bandcamp.com/",
        })
        self.assertEqual(apple_id("https://music.apple.com/us/artist/slow-pulp/1180495553?uo=4"), "1180495553")

    def test_image_shapes(self):
        self.assertEqual(image_url("a.jpg"), "a.jpg")
        self.assertEqual(image_url(["a.jpg", "b.jpg"]), "a.jpg")
        self.assertEqual(image_url({"@type": "ImageObject", "url": "a.jpg"}), "a.jpg")
        self.assertIsNone(image_url({}))

    def test_key_matches_variants(self):
        self.assertEqual(artist_key("The Beyoncé"), artist_key("beyonce"))
        self.assertEqual(artist_key("Simon & Garfunkel"), artist_key("simon and garfunkel"))

    def test_flags(self):
        self.assertTrue(is_sold_out("Qendresa - SOLD OUT"))
        self.assertEqual(display_title("Qendresa - SOLD OUT"), "Qendresa")
        self.assertEqual(classify("Stand-Up Comedy Night"), "comedy")
        self.assertEqual(classify("Gilla Band"), "music")


if __name__ == "__main__":
    unittest.main()
