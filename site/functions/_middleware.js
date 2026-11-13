// heyscenester.com and www. both send visitors to https://heyscenester.app.
export async function onRequest({ request, next }) {
  const url = new URL(request.url);
  if (url.hostname === "heyscenester.com" || url.hostname.startsWith("www.")) {
    url.hostname = "heyscenester.app";
    url.protocol = "https:";
    return Response.redirect(url.toString(), 301);
  }
  return next();
}
