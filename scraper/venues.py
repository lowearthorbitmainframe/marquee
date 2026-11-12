"""The venues Marquee watches. To add a city, add a new entry to CITIES."""

# Cities that count as greater Los Angeles, including the nearer parts of Orange County.
GREATER_LA = [
    "Los Angeles", "Hollywood", "West Hollywood", "Inglewood", "Pasadena", "Long Beach", "Santa Monica",
    "Burbank", "Glendale", "Culver City", "North Hollywood", "Studio City", "Venice", "Pomona", "Universal City",
    "Santa Ana", "Anaheim", "Costa Mesa", "Garden Grove", "Fullerton", "Irvine", "Huntington Beach",
]

# DICE city pages show only the soonest 20 or so shows per page, so genre pages
# reach further into raves, after-hours, hip hop, jazz and classical.
DICE_CATEGORIES = {
    "music/gig": "music", "music/dj": "party", "music/party": "party",
    "culture/comedy": "comedy", "culture/film": "film", "culture/theatre": "theater",
    "music/gig/hiphop": "music", "music/gig/rap": "music", "music/gig/jazz": "music",
    "music/gig/classical": "music", "music/gig/chamber": "music", "music/gig/experimental": "music",
    "music/dj/techno": "party", "music/dj/hard_techno": "party", "music/dj/house": "party",
    "music/dj/tech-house": "party", "music/dj/drumnbass": "party", "music/dj/bass": "party",
    "music/dj/hiphop": "party", "music/dj/afrohouse": "party", "music/dj/ukg": "party",
    "music/party/techno": "party", "music/party/house": "party", "music/party/hiphop": "party",
    "music/party/lgbtq+": "party",
}

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
            "cities": GREATER_LA,
        },
        {"adapter": "ticketweb_plugin", "url": "https://teragramballroom.com/calendar/", "venue": "teragram-ballroom"},
        {"adapter": "ticketweb_plugin", "url": "https://www.whiskyagogo.com/", "venue": "whisky-a-go-go"},
        {"adapter": "tessera", "url": "https://www.lodgeroomhlp.com/", "venue": "lodge-room"},
        {"adapter": "rockhouse", "url": "https://1720.la/", "venue": "1720"},
        {"adapter": "plot_cards", "url": "https://themintla.com/", "venue": "the-mint"},
        {"adapter": "table_listing", "url": "http://roadhouse.permanentrecordsla.com/", "venue": "permanent-records-roadhouse"},
        {"adapter": "eventbrite_organizer", "url": "https://www.eventbrite.com/o/npu-16532911902", "venue": "non-plus-ultra"},
        {"adapter": "squarespace_events", "url": "https://www.thesmell.org/events", "venue": "the-smell"},
        {"adapter": "squarespace_events", "url": "https://www.vibratogrilljazz.com/music", "venue": "vibrato-grill-jazz"},
        {"adapter": "live_nation", "url": "https://www.thebelasco.com/shows", "venue": "the-belasco"},
        {"adapter": "live_nation", "url": "https://www.peppermintclub.com/shows", "venue": "the-peppermint-club"},
        {"adapter": "live_nation", "url": "https://www.observatoryoc.com/shows", "venue": "the-observatory"},
        {"adapter": "live_nation", "url": "https://www.theveniceWest.com/", "venue": "the-venice-west"},
        {"adapter": "ticketweb_plugin", "url": "https://themoroccan.com/", "venue": "the-moroccan-lounge"},
        {"adapter": "ticketweb_plugin", "url": "https://gardenamp.com/", "venue": "garden-amphitheatre"},
        {"adapter": "eventbrite_organizer", "url": "https://www.eventbrite.com/o/the-wayfarer-20250596796", "venue": "the-wayfarer"},
        {"adapter": "tribe_events", "url": "https://www.vermonthollywood.com", "name": "The Vermont Hollywood"},
        {"adapter": "tribe_events", "url": "https://hollywoodforever.com", "name": "Hollywood Forever"},
        # Nightlife
        {"adapter": "club_events", "url": "https://exchangela.com/events/", "venue": "exchange-la", "category": "party"},
        {"adapter": "club_events", "url": "https://academy.la/events/", "venue": "academy-la", "category": "party"},
        {"adapter": "club_events", "url": "https://avalonhollywood.com/events/", "venue": "avalon-hollywood", "category": "party"},
        {
            "adapter": "dice_venues",
            "label": "dice.fm clubs",
            "url": "https://dice.fm/venue/",
            "venues": ["sound-nightclub-kxeo", "catch-one-e582"],
            "category": "party",
        },
        # Comedy
        {"adapter": "improv", "url": "https://improv.com/hollywood/calendar/", "venue": "hollywood-improv", "category": "comedy"},
        {"adapter": "improv", "url": "https://improv.com/brea/calendar/", "venue": "brea-improv", "category": "comedy"},
        {"adapter": "improv", "url": "https://improv.com/irvine/calendar/", "venue": "irvine-improv", "category": "comedy"},
        {"adapter": "laugh_factory", "url": "https://www.laughfactory.com/hollywood", "venue": "laugh-factory-hollywood", "category": "comedy"},
        {"adapter": "comedy_store", "url": "https://thecomedystore.com/calendar/by-month", "venue": "the-comedy-store", "category": "comedy"},
        {
            "adapter": "webflow_shows", "url": "https://calendar.dynastytypewriter.com/", "venue": "dynasty-typewriter",
            "card": "w-dyn-item", "title": "uui-heading-xxsmall-2", "category": "comedy",
        },
        {
            "adapter": "json_ld_cards", "url": "https://www.hahacomedyclub.com/calendar", "venue": "ha-ha-comedy-club",
            "card": 'class="event-item w-dyn-item"', "category": "comedy",
        },
        {"adapter": "seatengine", "url": "https://thecomedychateau.com/events", "venue": "the-comedy-chateau", "category": "comedy"},
        # Suggested in the app, November 2026
        {"adapter": "thundertix", "url": "https://thebakedpotato.thundertix.com", "venue": "the-baked-potato"},
        {"adapter": "ical_feed", "url": "https://harvardandstone.com/events.ics", "venue": "harvard-and-stone"},
        # Valley, Westside and Pasadena stages
        {
            "adapter": "live_nation", "label": "the canyon", "url": "https://wheremusicmeetsthesoul.com/",
            "locations": {
                "The Canyon - Agoura Hills": "the-canyon-agoura-hills",
                "The Saban Theatre - Beverly Hills": "saban-theatre",
                "Redondo Beach Performing Arts Center": "redondo-beach-performing-arts-center",
            },
            "category": "music",
        },
        {"adapter": "live_nation", "url": "https://thewallis.org", "venue": "the-wallis"},
        {"adapter": "stagey", "url": "https://whitefire.stagey.net/schedule", "venue": "whitefire-theatre", "category": "theater"},
        {
            "adapter": "spektrix", "label": "a noise within", "client": "anoisewithin", "rooms": ".",
            "site": "https://www.anoisewithin.org/", "venue": "a-noise-within", "category": "theater",
        },
        # Museums: exhibitions on view and dated programs
        {"adapter": "museum_cards", "label": "the broad", "url": "https://www.thebroad.org/events", "venue": "the-broad", "card": 'class="card-main"', "all_dates": True},
        {"adapter": "museum_cards", "label": "lacma", "url": "https://www.lacma.org/art/exhibitions/current", "venue": "lacma", "card": "<article data-history-node-id", "kind": "exhibition"},
        {
            "adapter": "json_ld_exhibitions", "label": "getty", "url": "https://www.getty.edu/exhibitions/", "venue": "getty-center",
            "elsewhere": {"getty-villa": "https://www.getty.edu/visit/villa"},
        },
        {"adapter": "museum_cards", "label": "hammer exhibitions", "url": "https://hammer.ucla.edu/exhibitions/on-view", "venue": "hammer-museum", "card": "page-teaser__preview", "kind": "exhibition"},
        {"adapter": "museum_cards", "label": "hammer programs", "url": "https://hammer.ucla.edu/programs-events", "venue": "hammer-museum", "card": 'class="result-item__information"'},
        {"adapter": "museum_cards", "label": "moca exhibitions", "url": "https://www.moca.org/exhibitions", "venue": "moca-grand-avenue", "card": 'href="/exhibitions/', "kind": "exhibition"},
        {"adapter": "museum_cards", "label": "moca programs", "url": "https://www.moca.org/events", "venue": "moca-grand-avenue", "card": 'href="/events/'},
        {"adapter": "museum_cards", "label": "academy museum", "url": "https://www.academymuseum.org/en/exhibitions/current", "venue": "academy-museum", "card": 'href="/exhibitions/', "kind": "exhibition"},
        # Jazz and classical
        {"adapter": "ticketweb_plugin", "url": "https://catalinajazzclub.com/", "venue": "catalina-jazz-club"},
        {"adapter": "wix_events", "url": "https://www.samfirstbar.com/", "venue": "sam-first"},
        {"adapter": "colburn", "url": "https://colburnschool.edu/calendar/", "venue": "colburn-school", "category": "music"},
        # Film
        {"adapter": "new_beverly", "url": "https://thenewbev.com/schedule/", "venue": "new-beverly-cinema", "category": "film"},
        {"adapter": "nightjar_cinema", "url": "https://vidiotsfoundation.org/coming-soon/", "venue": "vidiots", "category": "film"},
        {"adapter": "nightjar_cinema", "url": "https://thefridacinema.org/coming-soon/", "venue": "the-frida-cinema", "category": "film"},
        {"adapter": "alamo", "url": "https://drafthouse.com/s/mother/v2/schedule/market/los-angeles", "venue": "alamo-drafthouse-dtla", "category": "film"},
        {"adapter": "cinematheque", "label": "american cinematheque", "url": "https://www.americancinematheque.com/wp-json/wp/v2/event", "category": "film"},
        # Theater
        {"adapter": "live_nation", "url": "https://www.broadwayinhollywood.com/events", "venue": "pantages-theatre", "category": "theater"},
        {"adapter": "tribe_events", "url": "https://www.pasadenaplayhouse.org", "venue": "pasadena-playhouse", "name": "Pasadena Playhouse", "category": "theater"},
        {"adapter": "la_opera", "url": "https://www.laopera.org/whats-on/by-date", "venue": "dorothy-chandler-pavilion", "category": "theater"},
        {"adapter": "geffen", "url": "https://www.geffenplayhouse.org/tickets/", "venue": "geffen-playhouse", "category": "theater"},
        {"adapter": "cap_ucla", "label": "cap ucla", "url": "https://cap.ucla.edu/calendar", "category": "theater"},
        {
            "adapter": "spektrix", "label": "los angeles ballet", "client": "laballet", "presenter": "Los Angeles Ballet",
            "site": "https://www.losangelesballet.org/", "venue": "los-angeles-ballet-center", "category": "theater",
        },
        {
            "adapter": "spektrix", "label": "latino theater company", "client": "latinotheater", "rooms": r"^theat(er|re) \d",
            "site": "https://www.latinotheaterco.org/", "venue": "los-angeles-theatre-center", "category": "theater",
        },
        {
            "adapter": "la_phil",
            "label": "la phil",
            "url": "https://www.hollywoodbowl.com/api/event-instances.json",
            "venues": ["Hollywood Bowl", "The Ford", "Walt Disney Concert Hall"],
        },
        {
            "adapter": "dice_venues",
            "label": "dice.fm venues",
            "url": "https://dice.fm/venue/",
            "venues": [
                "zebulon-y8bv", "los-globos-a6w7", "gold-diggers-n2mq", "the-airliner-7r7v",
                "alexs-bar-mqp9", "el-cid-ven7", "brain-dead-studios-xlna", "the-virgil-39bl", "oblivion-mxobr",
                "high-tide-6nk3", "sid-the-cat-auditorium-2wr5m", "2220-arts--archives-bdyv", "grand-star-jazz-club-6kx8",
                "kiss-kiss-bang-bang-la-w79p", "milkys-l8v5b", "the-grayson-bar-yovqr", "townhouse-venice-d8ve",
                "now-instant-image-hall-bb5wg", "the-vermont-hollywood-35kl", "the-mint-5ggd",
                "permanent-records-roadhouse-olyg", "1720-mvpw",
            ],
        },
        # City-wide sources run last, so a venue's own listing wins any duplicate.
        {
            "adapter": "dice_city",
            "label": "dice.fm city",
            "url": "https://dice.fm/browse/losangeles-5982e13c613de866017c3e3a",
            "categories": DICE_CATEGORIES,
        },
        {
            "adapter": "ticketmaster",
            "url": "https://app.ticketmaster.com/discovery/v2/events.json",
            "dma": 324,
            "cities": GREATER_LA,
        },
    ],
    # Venues the AEG feed adds on its own come with an address but no map pin.
    "venues": {
        "echoplex": {"name": "Echoplex", "neighborhood": "Echo Park", "address": "1154 Glendale Blvd, Los Angeles, CA 90026", "lat": 34.0778, "lon": -118.2600, "url": "https://www.theecho.com/shows/rooms/echoplex"},
        "the-belasco": {"name": "The Belasco", "neighborhood": "Downtown", "url": "https://www.thebelasco.com/shows"},
        "the-peppermint-club": {"name": "The Peppermint Club", "neighborhood": "Beverly Grove", "url": "https://www.peppermintclub.com/shows"},
        "the-observatory": {"name": "The Observatory", "neighborhood": "Santa Ana", "url": "https://www.observatoryoc.com/shows"},
        "the-venice-west": {"name": "The Venice West", "neighborhood": "Venice", "url": "https://www.theveniceWest.com/"},
        "the-moroccan-lounge": {"name": "The Moroccan Lounge", "neighborhood": "Arts District", "address": "901 E 1st St, Los Angeles, CA 90012", "url": "https://themoroccan.com/"},
        "garden-amphitheatre": {"name": "Garden Amphitheatre", "neighborhood": "Garden Grove", "address": "12762 Main St, Garden Grove, CA 92840", "url": "https://gardenamp.com/"},
        "vibrato-grill-jazz": {"name": "Vibrato Grill Jazz", "neighborhood": "Bel Air", "address": "2930 N Beverly Glen Cir, Los Angeles, CA 90077", "url": "https://www.vibratogrilljazz.com/music"},
        "the-wayfarer": {"name": "The Wayfarer", "neighborhood": "Costa Mesa", "address": "843 W 19th St, Costa Mesa, CA 92627", "url": "https://wayfarercm.com/"},
        "exchange-la": {"name": "Exchange LA", "neighborhood": "Downtown", "address": "618 S Spring St, Los Angeles, CA 90014", "url": "https://exchangela.com/events/"},
        "academy-la": {"name": "Academy LA", "neighborhood": "Hollywood", "address": "6021 Hollywood Blvd, Los Angeles, CA 90028", "url": "https://academy.la/events/"},
        "avalon-hollywood": {"name": "Avalon Hollywood", "neighborhood": "Hollywood", "address": "1735 Vine St, Los Angeles, CA 90028", "url": "https://avalonhollywood.com/events/"},
        "hollywood-improv": {"name": "Hollywood Improv", "neighborhood": "Hollywood", "address": "8162 Melrose Ave, Los Angeles, CA 90046", "url": "https://improv.com/hollywood/"},
        "brea-improv": {"name": "Brea Improv", "neighborhood": "Brea", "address": "120 S Brea Blvd, Brea, CA 92821", "url": "https://improv.com/brea/"},
        "irvine-improv": {"name": "Irvine Improv", "neighborhood": "Irvine", "address": "527 Spectrum Center Dr, Irvine, CA 92618", "url": "https://improv.com/irvine/"},
        "the-comedy-store": {"name": "The Comedy Store", "neighborhood": "West Hollywood", "address": "8433 W Sunset Blvd, West Hollywood, CA 90069", "url": "https://thecomedystore.com/calendar"},
        "dynasty-typewriter": {"name": "Dynasty Typewriter", "neighborhood": "Westlake", "address": "2511 Wilshire Blvd, Los Angeles, CA 90057", "url": "https://www.dynastytypewriter.com/"},
        "the-broad": {"name": "The Broad", "neighborhood": "Downtown", "address": "221 S Grand Ave, Los Angeles, CA 90012", "url": "https://www.thebroad.org/"},
        "lacma": {"name": "LACMA", "neighborhood": "Miracle Mile", "address": "5905 Wilshire Blvd, Los Angeles, CA 90036", "url": "https://www.lacma.org/"},
        "getty-center": {"name": "Getty Center", "neighborhood": "Brentwood", "address": "1200 Getty Center Dr, Los Angeles, CA 90049", "url": "https://www.getty.edu/"},
        "getty-villa": {"name": "Getty Villa", "neighborhood": "Pacific Palisades", "address": "17985 Pacific Coast Hwy, Pacific Palisades, CA 90272", "url": "https://www.getty.edu/visit/villa/"},
        "hammer-museum": {"name": "Hammer Museum", "neighborhood": "Westwood", "address": "10899 Wilshire Blvd, Los Angeles, CA 90024", "url": "https://hammer.ucla.edu/"},
        "moca-grand-avenue": {"name": "MOCA Grand Avenue", "neighborhood": "Downtown", "address": "250 S Grand Ave, Los Angeles, CA 90012", "url": "https://www.moca.org/"},
        "academy-museum": {"name": "Academy Museum of Motion Pictures", "neighborhood": "Miracle Mile", "address": "6067 Wilshire Blvd, Los Angeles, CA 90036", "url": "https://www.academymuseum.org/"},
        "the-baked-potato": {"name": "The Baked Potato", "neighborhood": "Studio City", "address": "3787 Cahuenga Blvd, Studio City, CA 91604", "url": "https://www.thebakedpotato.com/"},
        "harvard-and-stone": {"name": "Harvard & Stone", "neighborhood": "East Hollywood", "address": "5221 Hollywood Blvd, Los Angeles, CA 90027", "url": "https://harvardandstone.com/"},
        "ha-ha-comedy-club": {"name": "Ha Ha Comedy Club", "neighborhood": "North Hollywood", "address": "4712 Lankershim Blvd, North Hollywood, CA 91602", "url": "https://www.hahacomedyclub.com/"},
        "the-comedy-chateau": {"name": "The Comedy Chateau", "neighborhood": "North Hollywood", "address": "4615 Lankershim Blvd, North Hollywood, CA 91602", "url": "https://thecomedychateau.com/"},
        "the-canyon-agoura-hills": {"name": "The Canyon", "neighborhood": "Agoura Hills", "address": "28912 Roadside Dr, Agoura Hills, CA 91301", "url": "https://wheremusicmeetsthesoul.com/"},
        "saban-theatre": {"name": "Saban Theatre", "neighborhood": "Beverly Hills", "address": "8440 Wilshire Blvd, Beverly Hills, CA 90211", "url": "https://wheremusicmeetsthesoul.com/"},
        "redondo-beach-performing-arts-center": {"name": "Redondo Beach Performing Arts Center", "neighborhood": "Redondo Beach", "address": "1935 Manhattan Beach Blvd, Redondo Beach, CA 90278", "url": "https://wheremusicmeetsthesoul.com/"},
        "the-wallis": {"name": "The Wallis", "neighborhood": "Beverly Hills", "address": "9390 N Santa Monica Blvd, Beverly Hills, CA 90210", "url": "https://thewallis.org/"},
        "whitefire-theatre": {"name": "Whitefire Theatre", "neighborhood": "Sherman Oaks", "address": "13500 Ventura Blvd, Sherman Oaks, CA 91423", "url": "https://whitefire.stagey.net/"},
        "a-noise-within": {"name": "A Noise Within", "neighborhood": "Pasadena", "address": "3352 E Foothill Blvd, Pasadena, CA 91107", "url": "https://www.anoisewithin.org/"},
        "catalina-jazz-club": {"name": "Catalina Jazz Club", "neighborhood": "Hollywood", "address": "6725 Sunset Blvd, Los Angeles, CA 90028", "url": "https://catalinajazzclub.com/"},
        "sam-first": {"name": "Sam First", "neighborhood": "Westchester", "address": "6171 W Century Blvd, Los Angeles, CA 90045", "url": "https://www.samfirstbar.com/"},
        "colburn-school": {"name": "Colburn School", "neighborhood": "Downtown", "address": "200 S Grand Ave, Los Angeles, CA 90012", "url": "https://colburnschool.edu/calendar/"},
        "dorothy-chandler-pavilion": {"name": "Dorothy Chandler Pavilion", "neighborhood": "Downtown", "address": "135 N Grand Ave, Los Angeles, CA 90012", "url": "https://www.laopera.org/"},
        "geffen-playhouse": {"name": "Geffen Playhouse", "neighborhood": "Westwood", "address": "10886 Le Conte Ave, Los Angeles, CA 90024", "url": "https://www.geffenplayhouse.org/"},
        "royce-hall": {"name": "Royce Hall", "neighborhood": "Westwood", "address": "340 Royce Dr, Los Angeles, CA 90095", "url": "https://cap.ucla.edu/"},
        "the-nimoy": {"name": "The Nimoy", "neighborhood": "Westwood", "address": "1262 Westwood Blvd, Los Angeles, CA 90024", "url": "https://cap.ucla.edu/"},
        "freud-playhouse": {"name": "Freud Playhouse", "neighborhood": "Westwood", "address": "245 Charles E Young Dr E, Los Angeles, CA 90095", "url": "https://cap.ucla.edu/"},
        "los-angeles-ballet-center": {"name": "Los Angeles Ballet Center", "neighborhood": "West LA", "url": "https://www.losangelesballet.org/"},
        "los-angeles-theatre-center": {"name": "Los Angeles Theatre Center", "neighborhood": "Downtown", "address": "514 S Spring St, Los Angeles, CA 90013", "url": "https://www.latinotheaterco.org/"},
        "laugh-factory-hollywood": {"name": "Laugh Factory", "neighborhood": "West Hollywood", "address": "8001 W Sunset Blvd, Los Angeles, CA 90046", "url": "https://www.laughfactory.com/hollywood"},
        "vidiots": {"name": "Vidiots", "neighborhood": "Eagle Rock", "address": "4884 Eagle Rock Blvd, Los Angeles, CA 90041", "url": "https://vidiotsfoundation.org/"},
        "the-frida-cinema": {"name": "The Frida Cinema", "neighborhood": "Santa Ana", "address": "305 E 4th St, Santa Ana, CA 92701", "url": "https://thefridacinema.org/"},
        "alamo-drafthouse-dtla": {"name": "Alamo Drafthouse DTLA", "neighborhood": "Downtown", "address": "700 W 7th St, Los Angeles, CA 90017", "url": "https://drafthouse.com/los-angeles"},
        "new-beverly-cinema": {"name": "New Beverly Cinema", "neighborhood": "Fairfax", "address": "7165 Beverly Blvd, Los Angeles, CA 90036", "url": "https://thenewbev.com/schedule/"},
        "los-feliz-3": {"name": "Los Feliz 3", "neighborhood": "Los Feliz", "address": "1822 N Vermont Ave, Los Angeles, CA 90027", "url": "https://www.americancinematheque.com/"},
        "aero-theatre": {"name": "Aero Theatre", "neighborhood": "Santa Monica", "address": "1328 Montana Ave, Santa Monica, CA 90403", "url": "https://www.americancinematheque.com/"},
        "egyptian-theatre": {"name": "Egyptian Theatre", "neighborhood": "Hollywood", "address": "6712 Hollywood Blvd, Los Angeles, CA 90028", "url": "https://www.americancinematheque.com/"},
        "pantages-theatre": {"name": "Hollywood Pantages", "neighborhood": "Hollywood", "address": "6233 Hollywood Blvd, Los Angeles, CA 90028", "url": "https://www.broadwayinhollywood.com/"},
        "pasadena-playhouse": {"name": "Pasadena Playhouse", "neighborhood": "Pasadena", "address": "39 S El Molino Ave, Pasadena, CA 91101", "url": "https://www.pasadenaplayhouse.org/"},
        "hollywood-bowl": {"name": "Hollywood Bowl", "neighborhood": "Hollywood Hills", "address": "2301 N Highland Ave, Los Angeles, CA 90068", "lat": 34.1122, "lon": -118.3391, "url": "https://www.hollywoodbowl.com/"},
        "the-ford": {"name": "The Ford", "neighborhood": "Cahuenga Pass", "address": "2580 Cahuenga Blvd E, Los Angeles, CA 90068", "url": "https://www.theford.com/"},
        "walt-disney-concert-hall": {"name": "Walt Disney Concert Hall", "neighborhood": "Downtown", "address": "111 S Grand Ave, Los Angeles, CA 90012", "lat": 34.0553, "lon": -118.2498, "url": "https://www.laphil.com/"},
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

# San Francisco down through the Peninsula and South Bay to Santa Cruz.
BAY_AREA_CITIES = [
    "San Francisco", "Oakland", "Berkeley", "Emeryville", "Richmond", "Alameda", "Concord", "Walnut Creek",
    "San Mateo", "Redwood City", "Palo Alto", "Menlo Park", "Mountain View", "Sunnyvale", "Santa Clara",
    "San Jose", "Saratoga", "Los Gatos", "Campbell", "Santa Cruz", "Felton", "Capitola", "Soquel", "Aptos",
]

BAY_AREA = {
    "id": "bay-area",
    "name": "Bay Area",
    "timezone": "America/Los_Angeles",
    "ready": True,
    "sources": [
        # Music: San Francisco
        {"adapter": "live_nation", "url": "https://www.thefillmore.com/shows", "venue": "the-fillmore"},
        {"adapter": "live_nation", "url": "https://sfmasonic.com/", "venue": "the-masonic"},
        {"adapter": "ticketweb_plugin", "url": "https://www.theindependentsf.com/", "venue": "the-independent"},
        {"adapter": "ticketweb_plugin", "url": "https://www.augusthallsf.com/", "venue": "august-hall"},
        {"adapter": "ticketweb_plugin", "url": "https://www.neckofthewoodssf.com/", "venue": "neck-of-the-woods"},
        {"adapter": "ticketweb_plugin", "url": "https://www.brickandmortarmusic.com/", "venue": "brick-mortar-music-hall"},
        {"adapter": "seetickets_list", "url": "https://thechapelsf.com/music/", "venue": "the-chapel"},
        {"adapter": "seetickets_list", "url": "https://www.hotelutah.com/", "venue": "hotel-utah"},
        {"adapter": "rockhouse", "url": "https://boomboomroom.com/", "venue": "boom-boom-room"},
        {
            "adapter": "dated_cards", "url": "https://www.cafedunord.com/", "venue": "cafe-du-nord",
            "card": r'<li class="show-row', "title": "show-row__headliner",
            "rooms": {"Cafe du Nord": "cafe-du-nord", "Swedish American Hall": "swedish-american-hall"},
        },
        {"adapter": "dated_cards", "url": "https://www.thecastro.com/", "venue": "the-castro", "card": r"wp-block-post-featured-image", "title": "show-title"},
        # Music: East Bay, Marin and the South Bay
        {"adapter": "seetickets_list", "url": "https://www.theestorkclub.com/", "venue": "thee-stork-club"},
        {"adapter": "webflow_shows", "url": "https://www.theuctheatre.org/events", "venue": "uc-theatre", "card": "shows-collection-item"},
        {"adapter": "webflow_shows", "url": "https://www.cornerstoneberkeley.com/", "venue": "cornerstone", "card": 'class="event-card', "title": "main-title-hover"},
        {"adapter": "yoshis", "url": "https://yoshis.com/", "venue": "yoshis"},
        {"adapter": "rockhouse", "url": "https://www.sweetwatermusichall.com/", "venue": "sweetwater-music-hall"},
        {"adapter": "venuepilot", "accounts": [992], "venue": "ivy-room", "site": "https://www.ivyroom.com/", "url": "https://www.ivyroom.com/"},
        {"adapter": "live_nation", "url": "https://montalvoarts.org/", "venue": "montalvo-arts-center"},
        # Santa Cruz
        {"adapter": "rockhouse", "url": "https://www.catalystclub.com/", "venue": "the-catalyst"},
        {"adapter": "ticketweb_plugin", "url": "https://www.moesalley.com/", "venue": "moes-alley"},
        {"adapter": "tribe_events", "url": "https://kuumbwajazz.org", "venue": "kuumbwa-jazz", "name": "Kuumbwa Jazz"},
        # Comedy
        {"adapter": "live_nation", "url": "https://www.cobbscomedy.com/", "venue": "cobbs-comedy-club", "category": "comedy"},
        {"adapter": "live_nation", "url": "https://www.punchlinecomedyclub.com/", "venue": "punch-line", "category": "comedy"},
        {"adapter": "improv", "url": "https://improv.com/sanjose/calendar/", "venue": "san-jose-improv", "category": "comedy"},
        {"adapter": "seatengine", "url": "https://rooster-t-feathers.seatengine-sites.com/events", "venue": "rooster-t-feathers", "category": "comedy"},
        # Film
        {"adapter": "roxie", "url": "https://roxie.com/calendar/", "venue": "roxie-theater", "category": "film"},
        {"adapter": "bampfa", "url": "https://bampfa.org/visit/calendar", "venue": "bampfa"},
        {"adapter": "tribe_events", "url": "https://www.artiststelevisionaccess.org", "venue": "artists-television-access", "name": "Artists' Television Access", "category": "film"},
        {
            "adapter": "alamo", "label": "alamo bay area", "category": "film",
            "url": "https://drafthouse.com/s/mother/v2/schedule/market/sf", "site": "https://drafthouse.com/sf",
            "cinemas": {"San Francisco": "alamo-new-mission", "Mountain View": "alamo-mountain-view", "Valley Fair": "alamo-valley-fair"},
        },
        # Theater
        {"adapter": "squarespace_events", "url": "https://www.magictheatre.org/calendar", "venue": "magic-theatre", "category": "theater"},
        # Nightlife and DICE rooms
        {
            "adapter": "dice_venues", "label": "dice.fm venues", "url": "https://dice.fm/venue/",
            "venues": ["the-knockout-3neg", "kilowatt-v9v6", "bottom-of-the-hill-dk9eo", "the-lab-bogk"],
        },
        {
            "adapter": "dice_venues", "label": "dice.fm clubs", "url": "https://dice.fm/venue/", "category": "party",
            "venues": ["halcyon-sf-mabv", "cat-club-l88vl"],
        },
        # Region-wide
        {
            "adapter": "aeg",
            "url": "https://aegwebprod.blob.core.windows.net/json/events/19/events.json",
            "cities": BAY_AREA_CITIES,
        },
        {
            "adapter": "dice_city",
            "label": "dice.fm city",
            "url": "https://dice.fm/browse/sanfrancisco-60dee10ce5e339918757f0db",
            "categories": DICE_CATEGORIES,
        },
        {
            "adapter": "ticketmaster",
            "url": "https://app.ticketmaster.com/discovery/v2/events.json",
            "dma": 382,
            "cities": BAY_AREA_CITIES,
        },
    ],
    "venues": {
        "the-fillmore": {"name": "The Fillmore", "neighborhood": "Western Addition", "address": "1805 Geary Blvd, San Francisco, CA 94115", "url": "https://www.thefillmore.com/shows"},
        "the-masonic": {"name": "The Masonic", "neighborhood": "Nob Hill", "address": "1111 California St, San Francisco, CA 94108", "url": "https://sfmasonic.com/"},
        "the-independent": {"name": "The Independent", "neighborhood": "NoPa", "address": "628 Divisadero St, San Francisco, CA 94117", "url": "https://www.theindependentsf.com/"},
        "august-hall": {"name": "August Hall", "neighborhood": "Union Square", "address": "420 Mason St, San Francisco, CA 94102", "url": "https://www.augusthallsf.com/"},
        "neck-of-the-woods": {"name": "Neck of the Woods", "neighborhood": "Inner Richmond", "address": "406 Clement St, San Francisco, CA 94118", "url": "https://www.neckofthewoodssf.com/"},
        "brick-mortar-music-hall": {"name": "Brick & Mortar Music Hall", "neighborhood": "Mission", "address": "1710 Mission St, San Francisco, CA 94103", "url": "https://www.brickandmortarmusic.com/"},
        "the-chapel": {"name": "The Chapel", "neighborhood": "Mission", "address": "777 Valencia St, San Francisco, CA 94110", "url": "https://thechapelsf.com/music/"},
        "hotel-utah": {"name": "Hotel Utah Saloon", "neighborhood": "SoMa", "address": "500 4th St, San Francisco, CA 94107", "url": "https://www.hotelutah.com/"},
        "boom-boom-room": {"name": "Boom Boom Room", "neighborhood": "Fillmore", "address": "1601 Fillmore St, San Francisco, CA 94115", "url": "https://boomboomroom.com/"},
        "cafe-du-nord": {"name": "Cafe du Nord", "neighborhood": "Castro", "address": "2174 Market St, San Francisco, CA 94114", "url": "https://www.cafedunord.com/"},
        "swedish-american-hall": {"name": "Swedish American Hall", "neighborhood": "Castro", "address": "2174 Market St, San Francisco, CA 94114", "url": "https://www.cafedunord.com/"},
        "the-castro": {"name": "The Castro Theatre", "neighborhood": "Castro", "address": "429 Castro St, San Francisco, CA 94114", "url": "https://www.thecastro.com/"},
        "thee-stork-club": {"name": "Thee Stork Club", "neighborhood": "Oakland", "address": "2330 Telegraph Ave, Oakland, CA 94612", "url": "https://www.theestorkclub.com/"},
        "uc-theatre": {"name": "The UC Theatre", "neighborhood": "Berkeley", "address": "2036 University Ave, Berkeley, CA 94704", "url": "https://www.theuctheatre.org/"},
        "cornerstone": {"name": "Cornerstone", "neighborhood": "Berkeley", "address": "2367 Shattuck Ave, Berkeley, CA 94704", "url": "https://www.cornerstoneberkeley.com/"},
        "yoshis": {"name": "Yoshi's", "neighborhood": "Oakland", "address": "510 Embarcadero W, Oakland, CA 94607", "url": "https://yoshis.com/"},
        "sweetwater-music-hall": {"name": "Sweetwater Music Hall", "neighborhood": "Mill Valley", "address": "19 Corte Madera Ave, Mill Valley, CA 94941", "url": "https://www.sweetwatermusichall.com/"},
        "the-catalyst": {"name": "The Catalyst", "neighborhood": "Santa Cruz", "address": "1011 Pacific Ave, Santa Cruz, CA 95060", "url": "https://www.catalystclub.com/"},
        "moes-alley": {"name": "Moe's Alley", "neighborhood": "Santa Cruz", "address": "1535 Commercial Way, Santa Cruz, CA 95065", "url": "https://www.moesalley.com/"},
        "kuumbwa-jazz": {"name": "Kuumbwa Jazz Center", "neighborhood": "Santa Cruz", "address": "320 Cedar St, Santa Cruz, CA 95060", "url": "https://kuumbwajazz.org/"},
        "cobbs-comedy-club": {"name": "Cobb's Comedy Club", "neighborhood": "North Beach", "address": "915 Columbus Ave, San Francisco, CA 94133", "url": "https://www.cobbscomedy.com/"},
        "punch-line": {"name": "Punch Line", "neighborhood": "Financial District", "address": "444 Battery St, San Francisco, CA 94111", "url": "https://www.punchlinecomedyclub.com/"},
        "san-jose-improv": {"name": "San Jose Improv", "neighborhood": "San Jose", "address": "62 S 2nd St, San Jose, CA 95113", "url": "https://improv.com/sanjose/"},
        "roxie-theater": {"name": "Roxie Theater", "neighborhood": "Mission", "address": "3117 16th St, San Francisco, CA 94103", "url": "https://roxie.com/"},
        "bampfa": {"name": "BAMPFA", "neighborhood": "Berkeley", "address": "2155 Center St, Berkeley, CA 94704", "url": "https://bampfa.org/"},
        "artists-television-access": {"name": "Artists' Television Access", "neighborhood": "Mission", "address": "992 Valencia St, San Francisco, CA 94110", "url": "https://www.artiststelevisionaccess.org/"},
        "alamo-new-mission": {"name": "Alamo Drafthouse New Mission", "neighborhood": "Mission", "address": "2550 Mission St, San Francisco, CA 94110", "url": "https://drafthouse.com/sf"},
        "alamo-mountain-view": {"name": "Alamo Drafthouse Mountain View", "neighborhood": "Mountain View", "address": "2306 Charleston Rd, Mountain View, CA 94043", "url": "https://drafthouse.com/sf"},
        "alamo-valley-fair": {"name": "Alamo Drafthouse Valley Fair", "neighborhood": "San Jose", "address": "2855 Stevens Creek Blvd, Santa Clara, CA 95050", "url": "https://drafthouse.com/sf"},
        "ivy-room": {"name": "Ivy Room", "neighborhood": "Albany", "address": "860 San Pablo Ave, Albany, CA 94706", "url": "https://www.ivyroom.com/"},
        "montalvo-arts-center": {"name": "Montalvo Arts Center", "neighborhood": "Saratoga", "address": "15400 Montalvo Rd, Saratoga, CA 95070", "url": "https://montalvoarts.org/"},
        "rooster-t-feathers": {"name": "Rooster T. Feathers", "neighborhood": "Sunnyvale", "address": "157 W El Camino Real, Sunnyvale, CA 94087", "url": "https://www.roostertfeathers.com/"},
        "magic-theatre": {"name": "Magic Theatre", "neighborhood": "Fort Mason", "address": "2 Marina Blvd, San Francisco, CA 94123", "url": "https://www.magictheatre.org/"},
    },
}

SAN_DIEGO_CITIES = ["San Diego", "Solana Beach", "Del Mar", "Chula Vista", "Escondido", "Oceanside", "La Jolla", "Carlsbad", "Encinitas", "La Mesa", "El Cajon", "Coronado"]

SAN_DIEGO = {
    "id": "san-diego",
    "name": "San Diego",
    "timezone": "America/Los_Angeles",
    "ready": True,
    "sources": [
        # Music
        {"adapter": "live_nation", "url": "https://www.observatorysd.com/shows", "venue": "observatory-north-park"},
        {"adapter": "live_nation", "url": "https://www.houseofblues.com/sandiego", "venue": "house-of-blues-san-diego"},
        {"adapter": "ticketweb_index", "url": "https://bellyup.com/events/", "venue": "belly-up-tavern"},
        {"adapter": "tribe_events", "url": "https://www.theholdingcompanyob.com", "venue": "the-holding-company", "name": "The Holding Company"},
        {"adapter": "tribe_events", "url": "https://www.whistlestopbar.com", "venue": "whistle-stop", "name": "Whistle Stop"},
        # Comedy
        {"adapter": "live_nation", "url": "https://micdropcomedy.com/", "venue": "mic-drop-comedy", "category": "comedy"},
        {"adapter": "live_nation", "url": "https://www.madhousecomedyclub.com/", "venue": "mad-house-comedy", "category": "comedy"},
        # Film
        {"adapter": "nightjar_cinema", "url": "https://digitalgym.org/coming-soon/", "venue": "digital-gym-cinema", "category": "film"},
        # Nightlife
        {"adapter": "club_events", "url": "https://www.novasd.com/events/", "venue": "nova-sd", "category": "party"},
        # Region-wide
        {
            "adapter": "aeg",
            "url": "https://aegwebprod.blob.core.windows.net/json/events/19/events.json",
            "cities": SAN_DIEGO_CITIES,
        },
        {
            "adapter": "ticketmaster",
            "url": "https://app.ticketmaster.com/discovery/v2/events.json",
            "dma": 381,
            "cities": SAN_DIEGO_CITIES,
        },
    ],
    "venues": {
        "observatory-north-park": {"name": "Observatory North Park", "neighborhood": "North Park", "address": "2891 University Ave, San Diego, CA 92104", "url": "https://www.observatorysd.com/shows"},
        "house-of-blues-san-diego": {"name": "House of Blues San Diego", "neighborhood": "Gaslamp", "address": "1055 5th Ave, San Diego, CA 92101", "url": "https://www.houseofblues.com/sandiego"},
        "belly-up-tavern": {"name": "Belly Up Tavern", "neighborhood": "Solana Beach", "address": "143 S Cedros Ave, Solana Beach, CA 92075", "url": "https://bellyup.com/"},
        "the-holding-company": {"name": "The Holding Company", "neighborhood": "Ocean Beach", "address": "5046 Newport Ave, San Diego, CA 92107", "url": "https://www.theholdingcompanyob.com/"},
        "whistle-stop": {"name": "Whistle Stop", "neighborhood": "South Park", "address": "2236 Fern St, San Diego, CA 92104", "url": "https://www.whistlestopbar.com/"},
        "mic-drop-comedy": {"name": "Mic Drop Comedy", "neighborhood": "Sports Arena", "address": "3595 Sports Arena Blvd, San Diego, CA 92110", "url": "https://micdropcomedy.com/"},
        "mad-house-comedy": {"name": "Mad House Comedy Club", "neighborhood": "Horton Plaza", "address": "502 Horton Plaza, San Diego, CA 92101", "url": "https://www.madhousecomedyclub.com/"},
        "digital-gym-cinema": {"name": "Digital Gym Cinema", "neighborhood": "East Village", "address": "1100 Market St, San Diego, CA 92101", "url": "https://digitalgym.org/"},
        "nova-sd": {"name": "Nova SD", "neighborhood": "Gaslamp", "address": "500 4th Ave, San Diego, CA 92101", "url": "https://www.novasd.com/"},
    },
}

# --- New regions in preview -------------------------------------------------
# "preview" regions are scraped by the separate Preview workflow (no artist lookups)
# and stay out of the app's city picker until "ready" is set. Each starts from the
# region-wide feeds (Ticketmaster, AEG, DICE) plus film and comedy where a reader exists.

TICKETMASTER_URL = "https://app.ticketmaster.com/discovery/v2/events.json"


def aeg_feeds(numbers, cities):
    return [{"adapter": "aeg", "label": "aeg feed %d" % n, "url": "https://aegwebprod.blob.core.windows.net/json/events/%d/events.json" % n, "cities": cities}
            for n in numbers]


SEATTLE_CITIES = ["Seattle", "Tacoma", "Bellevue", "Redmond", "Kirkland", "Everett", "Woodinville", "Auburn", "Renton",
                  "Bothell", "Shoreline", "Kent", "Tukwila", "Issaquah", "Snoqualmie"]
SEATTLE = {
    "id": "seattle", "name": "Seattle", "timezone": "America/Los_Angeles", "ready": False, "preview": True,
    "sources": [
        {"adapter": "dice_city", "label": "dice.fm city", "url": "https://dice.fm/browse/seattle-5e3c245c136e51081e406ed1", "categories": DICE_CATEGORIES},
        *aeg_feeds([23], SEATTLE_CITIES),
        {"adapter": "ticketmaster", "url": TICKETMASTER_URL, "dma": 385, "cities": SEATTLE_CITIES},
    ],
    "venues": {},
}

PORTLAND_CITIES = ["Portland", "Beaverton", "Hillsboro", "Gresham", "Lake Oswego", "Tigard", "Vancouver", "Milwaukie",
                   "Troutdale", "Ridgefield", "Oregon City", "Tualatin"]
PORTLAND = {
    "id": "portland", "name": "Portland", "timezone": "America/Los_Angeles", "ready": False, "preview": True,
    "sources": [
        {"adapter": "dice_venues", "label": "dice.fm venues", "url": "https://dice.fm/venue/", "venues": ["holocene-xql3", "swan-dive-k6xx8"]},
        *aeg_feeds([23], PORTLAND_CITIES),
        # Portland's market number is one of these; only Portland-area venues are kept.
        {"adapter": "ticketmaster", "url": TICKETMASTER_URL, "dma": [370, 371, 373, 374], "cities": PORTLAND_CITIES},
    ],
    "venues": {},
}

LAS_VEGAS_CITIES = ["Las Vegas", "Henderson", "North Las Vegas", "Paradise", "Spring Valley", "Summerlin", "Boulder City"]
LAS_VEGAS = {
    "id": "las-vegas", "name": "Las Vegas", "timezone": "America/Los_Angeles", "ready": False, "preview": True,
    "sources": [
        {"adapter": "dice_city", "label": "dice.fm city", "url": "https://dice.fm/browse/lasvegas-5e3c232c136e51081e406ece", "categories": DICE_CATEGORIES},
        {"adapter": "ticketmaster", "url": TICKETMASTER_URL, "dma": 319, "cities": LAS_VEGAS_CITIES},
    ],
    "venues": {},
}

DENVER_CITIES = ["Denver", "Englewood", "Aurora", "Lakewood", "Boulder", "Morrison", "Broomfield", "Littleton", "Westminster",
                 "Golden", "Commerce City", "Greenwood Village", "Arvada", "Wheat Ridge", "Louisville", "Fort Collins"]
DENVER = {
    "id": "denver", "name": "Denver", "timezone": "America/Denver", "ready": False, "preview": True,
    "sources": [
        {"adapter": "dice_venues", "label": "dice.fm venues", "url": "https://dice.fm/venue/",
         "venues": ["hi-dive-8kwv", "skylark-lounge-7x7b", "esp-hi-fi-bbdlo", "1134-broadway-53d2k"]},
        *aeg_feeds([2, 7, 37, 44, 89], DENVER_CITIES),
        {"adapter": "improv", "url": "https://improv.com/denver/calendar/", "venue": "denver-improv", "category": "comedy"},
        {
            "adapter": "alamo", "label": "alamo denver", "category": "film",
            "url": "https://drafthouse.com/s/mother/v2/schedule/market/denver", "site": "https://drafthouse.com/denver",
            "cinemas": {"Sloans Lake": "alamo-sloans-lake", "Westminster": "alamo-westminster", "Littleton": "alamo-littleton"},
        },
        {"adapter": "ticketmaster", "url": TICKETMASTER_URL, "dma": 264, "cities": DENVER_CITIES},
    ],
    "venues": {
        "denver-improv": {"name": "Denver Improv", "neighborhood": "Central Park", "address": "8246 Northfield Blvd, Denver, CO 80238", "url": "https://improv.com/denver/"},
        "alamo-sloans-lake": {"name": "Alamo Drafthouse Sloans Lake", "neighborhood": "Sloan's Lake", "address": "4255 W Colfax Ave, Denver, CO 80204", "url": "https://drafthouse.com/denver"},
        "alamo-westminster": {"name": "Alamo Drafthouse Westminster", "neighborhood": "Westminster", "address": "8905 Westminster Blvd, Westminster, CO 80031", "url": "https://drafthouse.com/denver"},
        "alamo-littleton": {"name": "Alamo Drafthouse Littleton", "neighborhood": "Littleton", "address": "7301 S Santa Fe Dr, Littleton, CO 80120", "url": "https://drafthouse.com/denver"},
    },
}

AUSTIN_CITIES = ["Austin", "Round Rock", "Del Valle", "Cedar Park", "Pflugerville", "Dripping Springs", "Georgetown",
                 "San Marcos", "Buda", "Spicewood", "Bee Cave", "Lakeway"]
AUSTIN = {
    "id": "austin", "name": "Austin", "timezone": "America/Chicago", "ready": False, "preview": True,
    "sources": [
        {"adapter": "dice_city", "label": "dice.fm city", "url": "https://dice.fm/browse/austin-5e3c24db136e51081e406ed3", "categories": DICE_CATEGORIES},
        {
            "adapter": "alamo", "label": "alamo austin", "category": "film",
            "url": "https://drafthouse.com/s/mother/v2/schedule/market/austin", "site": "https://drafthouse.com/austin",
            "cinemas": {"Village": "alamo-village", "Slaughter Lane": "alamo-slaughter-lane", "South Lamar": "alamo-south-lamar",
                        "Lakeline": "alamo-lakeline", "Mueller": "alamo-mueller"},
        },
        {"adapter": "ticketmaster", "url": TICKETMASTER_URL, "dma": 222, "cities": AUSTIN_CITIES},
    ],
    "venues": {
        "alamo-village": {"name": "Alamo Drafthouse Village", "neighborhood": "Allandale", "address": "2700 W Anderson Ln, Austin, TX 78757", "url": "https://drafthouse.com/austin"},
        "alamo-slaughter-lane": {"name": "Alamo Drafthouse Slaughter Lane", "neighborhood": "South Austin", "address": "5701 W Slaughter Ln, Austin, TX 78749", "url": "https://drafthouse.com/austin"},
        "alamo-south-lamar": {"name": "Alamo Drafthouse South Lamar", "neighborhood": "South Lamar", "address": "1120 S Lamar Blvd, Austin, TX 78704", "url": "https://drafthouse.com/austin"},
        "alamo-lakeline": {"name": "Alamo Drafthouse Lakeline", "neighborhood": "Cedar Park", "address": "14028 N US Hwy 183 Bldg F, Austin, TX 78717", "url": "https://drafthouse.com/austin"},
        "alamo-mueller": {"name": "Alamo Drafthouse Mueller", "neighborhood": "Mueller", "address": "1911 Aldrich St, Austin, TX 78723", "url": "https://drafthouse.com/austin"},
    },
}

PHOENIX_CITIES = ["Phoenix", "Tempe", "Scottsdale", "Mesa", "Chandler", "Glendale", "Gilbert", "Peoria", "Avondale",
                  "Goodyear", "Surprise", "Tucson"]
PHOENIX = {
    "id": "phoenix", "name": "Phoenix", "timezone": "America/Phoenix", "ready": False, "preview": True,
    "sources": [
        {"adapter": "ticketmaster", "url": TICKETMASTER_URL, "dma": 359, "cities": PHOENIX_CITIES},
    ],
    "venues": {},
}

DETROIT_CITIES = ["Detroit", "Royal Oak", "Ferndale", "Hamtramck", "Pontiac", "Ann Arbor", "Clarkston", "Sterling Heights",
                  "Dearborn", "Ypsilanti", "Auburn Hills", "Southfield", "Warren", "Clinton Township", "Rochester Hills", "Windsor"]
DETROIT = {
    "id": "detroit", "name": "Detroit", "timezone": "America/Detroit", "ready": False, "preview": True,
    "sources": [
        {"adapter": "dice_city", "label": "dice.fm city", "url": "https://dice.fm/browse/detroit-5e3c22d9136e51081e406ecd", "categories": DICE_CATEGORIES},
        *aeg_feeds([40], DETROIT_CITIES),
        {"adapter": "ticketmaster", "url": TICKETMASTER_URL, "dma": 266, "cities": DETROIT_CITIES},
    ],
    "venues": {},
}

NEW_YORK_CITIES = ["New York", "Brooklyn", "Queens", "Long Island City", "Bronx", "Staten Island", "Jersey City", "Hoboken",
                   "Astoria", "Flushing", "Ridgewood", "Forest Hills", "Manhattan"]
NEW_YORK = {
    "id": "new-york", "name": "New York City", "timezone": "America/New_York", "ready": False, "preview": True,
    "sources": [
        {"adapter": "dice_city", "label": "dice.fm city", "url": "https://dice.fm/browse/new_york-5bbf4db0f06331478e9b2c59", "categories": DICE_CATEGORIES},
        *aeg_feeds([15, 58, 59, 85], NEW_YORK_CITIES),
        {
            "adapter": "alamo", "label": "alamo nyc", "category": "film",
            "url": "https://drafthouse.com/s/mother/v2/schedule/market/nyc", "site": "https://drafthouse.com/nyc",
            "cinemas": {"Lower Manhattan": "alamo-lower-manhattan", "Staten Island": "alamo-staten-island", "Downtown Brooklyn": "alamo-downtown-brooklyn"},
        },
        {"adapter": "ticketmaster", "url": TICKETMASTER_URL, "dma": 345, "cities": NEW_YORK_CITIES, "split_segments": True},
    ],
    "venues": {
        "alamo-lower-manhattan": {"name": "Alamo Drafthouse Lower Manhattan", "neighborhood": "Financial District", "address": "28 Liberty St, New York, NY 10005", "url": "https://drafthouse.com/nyc"},
        "alamo-staten-island": {"name": "Alamo Drafthouse Staten Island", "neighborhood": "Staten Island", "address": "2655 Richmond Ave, Staten Island, NY 10314", "url": "https://drafthouse.com/nyc"},
        "alamo-downtown-brooklyn": {"name": "Alamo Drafthouse Downtown Brooklyn", "neighborhood": "Downtown Brooklyn", "address": "445 Albee Square W, Brooklyn, NY 11201", "url": "https://drafthouse.com/nyc"},
    },
}

CITIES = [LOS_ANGELES, BAY_AREA, SAN_DIEGO, SEATTLE, PORTLAND, LAS_VEGAS, DENVER, AUSTIN, PHOENIX, DETROIT, NEW_YORK]
