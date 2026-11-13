// The confirmation link in the venue's email: marks the address as verified.

function page(title, body) {
  return new Response(
    `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title} · Scenester</title><link rel="stylesheet" href="/style.css"></head>
<body><main class="narrow"><a class="wordmark" href="/">SCENESTER</a><h1 class="sign">${title}</h1>${body}</main></body></html>`,
    { headers: { "Content-Type": "text/html; charset=utf-8" } }
  );
}

export async function onRequestGet({ request, env }) {
  const token = new URL(request.url).searchParams.get("token") || "";
  if (!/^[0-9a-f]{48}$/.test(token)) return page("Link not recognized", "<p>This confirmation link isn't valid. Please use the link from your email.</p>");
  const row = await env.DB.prepare("SELECT venue, email_verified_at, domain_match, site_code, website FROM submissions WHERE token = ?")
    .bind(token).first();
  if (!row) return page("Link not recognized", "<p>We couldn't find this request. It may have been removed.</p>");
  if (!row.email_verified_at) {
    await env.DB.prepare("UPDATE submissions SET email_verified_at = ? WHERE token = ?").bind(new Date().toISOString(), token).run();
  }
  const next = row.domain_match
    ? "<p>We'll check your website and calendar next, and email you when your shows are live.</p>"
    : `<p>One more step: add the code <code>${row.site_code}</code> somewhere on your website, or post it from the venue's official Instagram, then reply to our email. After that we'll check your calendar and add your shows.</p>`;
  return page("Thanks, you're confirmed", `<p><strong>${row.venue.replace(/</g, "&lt;")}</strong> is in our queue.</p>${next}`);
}
