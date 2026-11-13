// Receives the "List your venue" form, checks it isn't a bot, stores it, and emails the
// contact a confirmation link. Verification of the venue itself happens in the daily
// check on the owner's Mac, which reads these rows.

const REGIONS = {
  "los-angeles": "Los Angeles", "bay-area": "Bay Area", "san-diego": "San Diego", "seattle": "Seattle",
  "portland": "Portland", "las-vegas": "Las Vegas", "denver": "Denver", "austin": "Austin",
  "phoenix": "Phoenix", "detroit": "Detroit", "new-york": "New York City",
};
const FREE_MAIL = /@(gmail|googlemail|yahoo|ymail|hotmail|outlook|live|icloud|me|mac|aol|proton|protonmail|gmx|mail)\./i;

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function clean(value, max = 300) {
  return String(value || "").trim().slice(0, max);
}

function hostOf(url) {
  try {
    return new URL(/^https?:\/\//i.test(url) ? url : "https://" + url).hostname.replace(/^www\./, "").toLowerCase();
  } catch {
    return "";
  }
}

function randomCode(bytes) {
  const data = crypto.getRandomValues(new Uint8Array(bytes));
  return Array.from(data, (b) => b.toString(16).padStart(2, "0")).join("");
}

async function verifyTurnstile(token, ip, secret) {
  const form = new FormData();
  form.append("secret", secret);
  form.append("response", token);
  if (ip) form.append("remoteip", ip);
  const reply = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", { method: "POST", body: form });
  return (await reply.json()).success === true;
}

export async function onRequestPost({ request, env }) {
  let data;
  try {
    data = await request.json();
  } catch {
    return json({ ok: false, error: "Something went wrong sending the form. Please try again." }, 400);
  }
  // A hidden field people never see; bots fill it in.
  if (clean(data.company_fax)) return json({ ok: true });

  const ip = request.headers.get("CF-Connecting-IP");
  if (!(await verifyTurnstile(clean(data.turnstile, 2048), ip, env.TURNSTILE_SECRET))) {
    return json({ ok: false, error: "Please complete the check above the button and try again." }, 400);
  }

  const venue = clean(data.venue, 120);
  const address = clean(data.address, 200);
  const region = clean(data.region, 40);
  const website = clean(data.website, 300);
  const calendar = clean(data.calendar_url, 500);
  const name = clean(data.contact_name, 100);
  const email = clean(data.contact_email, 200).toLowerCase();
  const role = clean(data.contact_role, 100);
  const notes = clean(data.notes, 1000);
  const kinds = Array.isArray(data.kinds) ? data.kinds.map((k) => clean(k, 20)).slice(0, 6).join(",") : "";

  const missing = [];
  if (venue.length < 2) missing.push("venue name");
  if (address.length < 5) missing.push("street address");
  if (!REGIONS[region]) missing.push("city");
  if (!hostOf(website)) missing.push("website");
  if (name.length < 2) missing.push("your name");
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) missing.push("email");
  if (data.consent !== true) missing.push("permission checkbox");
  if (missing.length) return json({ ok: false, error: "Please fill in: " + missing.join(", ") + "." }, 400);

  const siteHost = hostOf(website);
  const emailHost = email.split("@")[1];
  const domainMatch = !FREE_MAIL.test(email) && (emailHost === siteHost || emailHost.endsWith("." + siteHost));

  const id = crypto.randomUUID();
  const token = randomCode(24);
  const siteCode = "scenester-" + randomCode(4);
  await env.DB.prepare(
    `INSERT INTO submissions (id, created, venue, address, region, website, calendar_url, kinds, contact_name,
       contact_email, contact_role, notes, consent, domain_match, token, site_code)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?)`
  ).bind(id, new Date().toISOString(), venue, address, region, website, calendar, kinds, name, email, role, notes,
         domainMatch ? 1 : 0, token, siteCode).run();

  const link = `${env.SITE_URL}/verify?token=${token}`;
  const extra = domainMatch ? "" :
    `\nBecause this email address isn't on ${siteHost}, we also need one sign that the listing comes from the venue. Either:\n` +
    `  • add this code anywhere on ${siteHost} (a footer or your events page is fine): ${siteCode}\n` +
    `  • or post it from the venue's official Instagram and send us the link\n` +
    `Reply to this email once it's up.\n`;
  const text =
    `Hi ${name},\n\nThanks for asking to list ${venue} on Scenester.\n\n` +
    `Please confirm this email address:\n${link}\n${extra}\n` +
    `Once confirmed, we check your website and calendar and add your shows, usually within a few days. ` +
    `We'll email you when ${venue} is live.\n\nScenester\nheyscenester.app\n`;

  const sent = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify({ from: env.FROM_EMAIL, to: [email], reply_to: env.REPLY_TO, subject: `Confirm ${venue} on Scenester`, text }),
  });
  if (!sent.ok) {
    console.log("resend failed", sent.status, await sent.text());
    return json({ ok: true, emailed: false, domainMatch });
  }
  return json({ ok: true, emailed: true, domainMatch });
}
