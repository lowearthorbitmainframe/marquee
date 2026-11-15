// /v/<region>/<venue-id> shows a venue its listing as the app draws it. The page itself
// (public/preview.html) reads the region and venue from the address and loads the live feed.
export async function onRequestGet({ request, env }) {
  const page = await env.ASSETS.fetch(new URL("/preview", request.url));
  return new Response(page.body, { status: 200, headers: page.headers });
}
