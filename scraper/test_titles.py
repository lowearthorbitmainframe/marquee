import unittest
from datetime import datetime
from zoneinfo import ZoneInfo

from adapters import image_url
from scrape import normalize
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

    def test_drops_connectors_and_placeholders(self):
        self.check("with Silverdeer", ["Silverdeer"])
        self.check("performed by Jimmy Rip", ["Jimmy Rip"])
        self.check("Thee Sacred Souls, Special Guest", ["Thee Sacred Souls"])
        self.check("Camp Flog Gnaw 2026", [])

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
