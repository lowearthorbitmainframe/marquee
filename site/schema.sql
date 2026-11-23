-- Venues that asked to be listed. Read by "Marquee Outreach/verify_venue_signups.py".
CREATE TABLE IF NOT EXISTS submissions (
  id TEXT PRIMARY KEY,
  created TEXT NOT NULL,
  venue TEXT NOT NULL,
  address TEXT NOT NULL,
  region TEXT NOT NULL,
  website TEXT NOT NULL,
  calendar_url TEXT,
  kinds TEXT,
  contact_name TEXT NOT NULL,
  contact_email TEXT NOT NULL,
  contact_role TEXT,
  notes TEXT,
  consent INTEGER NOT NULL,
  domain_match INTEGER NOT NULL,   -- contact email is on the venue website's domain
  token TEXT NOT NULL,             -- secret in the confirmation link
  site_code TEXT NOT NULL,         -- short code a venue can put on its website instead
  email_verified_at TEXT,
  status TEXT NOT NULL DEFAULT 'new',  -- new, checked, approved, rejected
  review_notes TEXT
);
CREATE INDEX IF NOT EXISTS submissions_token ON submissions(token);

-- "Change/Remove Listing" requests from the app (functions/api/listing-request.js); each is also emailed.
CREATE TABLE IF NOT EXISTS listing_requests (
  id TEXT PRIMARY KEY,
  created TEXT NOT NULL,
  kind TEXT NOT NULL,          -- remove, change
  venue TEXT NOT NULL,
  venue_id TEXT,
  region TEXT,
  name TEXT NOT NULL,
  role TEXT,
  email TEXT NOT NULL,
  details TEXT,
  ip TEXT,
  status TEXT NOT NULL DEFAULT 'new'   -- new, done
);
CREATE INDEX IF NOT EXISTS listing_requests_ip ON listing_requests(ip, created);
