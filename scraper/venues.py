"""The venues Marquee watches. To add a city, add a new entry to CITIES."""

# Each source is one fetch. `adapter` names a function in adapters.py.
LOS_ANGELES = {
    "id": "los-angeles",
    "name": "Los Angeles",
    "timezone": "America/Los_Angeles",
    "sources": [
        {"adapter": "troubadour", "url": "https://www.troubadour.com/", "venue": "troubadour"},
        {"adapter": "live_nation", "url": "https://www.theecho.com/shows/rooms/echoplex", "venue": "echoplex"},
        {"adapter": "live_nation", "url": "https://www.theecho.com/shows/rooms/the-echo", "venue": "the-echo"},
        {"adapter": "live_nation", "url": "https://www.wiltern.com/shows", "venue": "the-wiltern"},
        {"adapter": "live_nation", "url": "https://www.hollywoodpalladium.com/shows", "venue": "hollywood-palladium"},
        {"adapter": "greek", "url": "https://www.lagreektheatre.com/", "venue": "greek-theatre"},
        {
            "adapter": "aeg",
            "url": "https://aegwebprod.blob.core.windows.net/json/events/19/events.json",
            "cities": ["Los Angeles", "Hollywood", "West Hollywood", "Inglewood", "Pomona", "Pasadena", "Long Beach", "Santa Monica"],
        },
        {"adapter": "ticketweb_plugin", "url": "https://teragramballroom.com/calendar/", "venue": "teragram-ballroom"},
        {"adapter": "ticketweb_plugin", "url": "https://www.whiskyagogo.com/", "venue": "whisky-a-go-go"},
        {"adapter": "tessera", "url": "https://www.lodgeroomhlp.com/", "venue": "lodge-room"},
        {"adapter": "rockhouse", "url": "https://1720.la/", "venue": "1720"},
        {"adapter": "plot_cards", "url": "https://themintla.com/", "venue": "the-mint"},
        {"adapter": "table_listing", "url": "http://roadhouse.permanentrecordsla.com/", "venue": "permanent-records-roadhouse"},
        {"adapter": "eventbrite_organizer", "url": "https://www.eventbrite.com/o/npu-16532911902", "venue": "non-plus-ultra"},
        {"adapter": "squarespace_events", "url": "https://www.thesmell.org/events", "venue": "the-smell"},
        # City-wide sources run last, so a venue's own listing wins any duplicate.
        {
            "adapter": "dice_city",
            "url": "https://dice.fm/browse/losangeles-5982e13c613de866017c3e3a",
            "categories": ["music/gig", "music/dj", "music/party"],
        },
        {
            "adapter": "ticketmaster",
            "url": "https://app.ticketmaster.com/discovery/v2/events.json",
            "dma": 324,
            "cities": ["Los Angeles", "Hollywood", "West Hollywood", "Inglewood", "Pasadena", "Long Beach", "Santa Monica", "Burbank", "Glendale", "Culver City", "North Hollywood", "Studio City", "Venice"],
        },
    ],
    # Venues the AEG feed adds on its own come with an address but no map pin.
    "venues": {
        "echoplex": {"name": "Echoplex", "neighborhood": "Echo Park", "address": "1154 Glendale Blvd, Los Angeles, CA 90026", "lat": 34.0778, "lon": -118.2600, "url": "https://www.theecho.com/shows/rooms/echoplex"},
        "troubadour": {"name": "Troubadour", "neighborhood": "West Hollywood", "address": "9081 Santa Monica Blvd, West Hollywood, CA 90069", "lat": 34.0815, "lon": -118.3895, "url": "https://www.troubadour.com/"},
        "non-plus-ultra": {"name": "Non Plus Ultra", "neighborhood": "Address by DM", "url": "https://www.eventbrite.com/o/npu-16532911902"},
        "the-smell": {"name": "The Smell", "neighborhood": "Downtown", "address": "247 S Main St, Los Angeles, CA 90012", "lat": 34.0512, "lon": -118.2470, "url": "https://www.thesmell.org/events"},
        "the-echo": {"name": "The Echo", "neighborhood": "Echo Park", "address": "1822 W Sunset Blvd, Los Angeles, CA 90026", "lat": 34.0779, "lon": -118.2601, "url": "https://www.theecho.com/shows/rooms/the-echo"},
        "the-wiltern": {"name": "The Wiltern", "neighborhood": "Koreatown", "address": "3790 Wilshire Blvd, Los Angeles, CA 90010", "lat": 34.0617, "lon": -118.3085, "url": "https://www.wiltern.com/shows"},
        "hollywood-palladium": {"name": "Hollywood Palladium", "neighborhood": "Hollywood", "address": "6215 W Sunset Blvd, Los Angeles, CA 90028", "lat": 34.0979, "lon": -118.3247, "url": "https://www.hollywoodpalladium.com/shows"},
        "greek-theatre": {"name": "Greek Theatre", "neighborhood": "Griffith Park", "address": "2700 N Vermont Ave, Los Angeles, CA 90027", "lat": 34.1197, "lon": -118.2966, "url": "https://www.lagreektheatre.com/"},
        "el-rey-theatre": {"name": "El Rey Theatre", "neighborhood": "Mid-Wilshire", "lat": 34.0618, "lon": -118.3502},
        "fonda-theatre": {"name": "Fonda Theatre", "neighborhood": "Hollywood", "lat": 34.1019, "lon": -118.3231},
        "the-novo": {"name": "The Novo", "neighborhood": "Downtown", "lat": 34.0449, "lon": -118.2664},
        "the-roxy": {"name": "The Roxy", "neighborhood": "West Hollywood", "lat": 34.0903, "lon": -118.3885},
        "shrine-expo-hall": {"name": "Shrine Expo Hall", "neighborhood": "University Park", "lat": 34.0235, "lon": -118.2813},
        "shrine-auditorium": {"name": "Shrine Auditorium", "neighborhood": "University Park", "lat": 34.0235, "lon": -118.2813},
        "teragram-ballroom": {"name": "Teragram Ballroom", "neighborhood": "Westlake", "address": "1234 W 7th St, Los Angeles, CA 90017", "lat": 34.0517, "lon": -118.2664, "url": "https://teragramballroom.com/calendar/"},
        "whisky-a-go-go": {"name": "Whisky a Go Go", "neighborhood": "West Hollywood", "address": "8901 W Sunset Blvd, West Hollywood, CA 90069", "lat": 34.0908, "lon": -118.3856, "url": "https://www.whiskyagogo.com/"},
        "lodge-room": {"name": "Lodge Room", "neighborhood": "Highland Park", "address": "104 N Avenue 56, Los Angeles, CA 90042", "lat": 34.1105, "lon": -118.1916, "url": "https://www.lodgeroomhlp.com/"},
        "1720": {"name": "1720", "neighborhood": "Arts District", "address": "1720 E 16th St, Los Angeles, CA 90021", "lat": 34.0197, "lon": -118.2378, "url": "https://1720.la/"},
        "the-mint": {"name": "The Mint", "neighborhood": "Mid-City", "address": "6010 W Pico Blvd, Los Angeles, CA 90035", "lat": 34.0543, "lon": -118.3690, "url": "https://themintla.com/"},
        "permanent-records-roadhouse": {"name": "Permanent Records Roadhouse", "neighborhood": "Cypress Park", "address": "3 Cypress Ave, Los Angeles, CA 90065", "url": "http://roadhouse.permanentrecordsla.com/"},
    },
}

CITIES = [LOS_ANGELES]
