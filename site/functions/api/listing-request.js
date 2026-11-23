// Receives "Change/Remove Listing" requests from the app, keeps a record, and emails them to
// venues@heyscenester.app (forwarded to the owner's inbox) with the requester as reply-to, so
// answering is one tap. Removals are promised within 48 hours.

const KINDS = { remove: "Remove our listing", change: "Change our listing" };
const PER_HOUR = 5;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function clean(value, max = 300) {
  return String(value || "").trim().slice(0, max);
}

export async function onRequestPost({ request, env }) {
  // Not a secret: it only keeps casual web traffic out. Requests are rate-limited per address below.
  if (request.headers.get("X-Scenester-App") !== "1") return json({ ok: false, error: "Not found." }, 404);
  let data;
  try {
    data = await request.json();
  } catch {
    return json({ ok: false, error: "Something went wrong sending your request. Please try again." }, 400);
  }
  const kind = KINDS[data.kind] ? data.kind : "change";
  const venue = clean(data.venue, 120);
  const venueId = clean(data.venueId, 120);
  const region = clean(data.region, 40);
  const name = clean(data.name, 100);
  const role = clean(data.role, 100);
  const email = clean(data.email, 200);
  const details = clean(data.details, 2000);
  if (!venue || !name || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return json({ ok: false, error: "Please fill in the venue, your name and a valid email." }, 400);
  }
  if (kind === "change" && !details) {
    return json({ ok: false, error: "Please tell us what should change." }, 400);
  }

  const ip = request.headers.get("CF-Connecting-IP") || "";
  const hourAgo = new Date(Date.now() - 3600e3).toISOString();
  const recent = await env.DB.prepare("SELECT COUNT(*) AS n FROM listing_requests WHERE ip = ? AND created > ?")
    .bind(ip, hourAgo).first();
  if ((recent?.n || 0) >= PER_HOUR) {
    return json({ ok: false, error: "We've received several requests from you already. Please email venues@heyscenester.app." }, 429);
  }

  const created = new Date().toISOString();
  const id = crypto.randomUUID();
  await env.DB.prepare(
    "INSERT INTO listing_requests (id, created, kind, venue, venue_id, region, name, role, email, details, ip) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
  ).bind(id, created, kind, venue, venueId, region, name, role, email, details, ip).run();

  const due = new Date(Date.now() + 48 * 3600e3).toLocaleString("en-US", { timeZone: "America/Los_Angeles", dateStyle: "medium", timeStyle: "short" });
  const preview = venueId && region ? `${env.SITE_URL}/v/${region}/${venueId}` : "";
  const text = [
    `${KINDS[kind]}: ${venue}`,
    "",
    `From: ${name}${role ? ` (${role})` : ""} <${email}>`,
    `Venue: ${venue}${region ? `, ${region}` : ""}${venueId ? ` [${venueId}]` : ""}`,
    preview ? `Their listing: ${preview}` : "",
    "",
    details ? `What they said:\n${details}` : "(No details given.)",
    "",
    kind === "remove" ? `We promised removal within 48 hours: by ${due} (LA time).` : "",
    "Reply to this email to answer them directly.",
    `Request ${id}`,
  ].filter((line, i, all) => line !== "" || all[i - 1] !== "").join("\n");

  const sent = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      from: env.FROM_EMAIL,
      to: [env.REPLY_TO],
      reply_to: email,
      subject: `${kind === "remove" ? "REMOVE" : "Change"}: ${venue} listing request`,
      text,
    }),
  });
  if (!sent.ok) console.log("resend failed", sent.status, await sent.text());
  return json({ ok: true, emailed: sent.ok });
}
