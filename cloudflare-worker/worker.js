/**
 * Cloudflare Worker — Proxy TCL (toutes les APIs Grand Lyon)
 *
 * Routes :
 *   GET /alerts                      → tclalertetrafic_2/all.json
 *   GET /passages?id=<int>[&sortby=&sortorder=]  → tclpassagearret/all.json
 *   GET /vehicles                    → siri-lite/2.0/vehicle-monitoring.json
 *   GET /metro-funi-lines?<params>   → GeoServer tcllignemf_2_0_0/items
 *   GET /tram-lines?<params>         → GeoServer tcllignetram_2_0_0/items
 *   GET /bus-lines?<params>          → GeoServer tcllignebus_2_0_0/items
 *   GET /stops?<params>              → GeoServer tclarret/items
 *
 * Les credentials Grand Lyon sont stockés en secrets Cloudflare chiffrés.
 * Aucune credential n'est dans le code ni dans le binaire iOS.
 *
 * Déploiement : bash cloudflare-worker/deploy.sh
 */

const DATA_BASE     = "https://data.grandlyon.com";
const DOWNLOAD_BASE = "https://download.data.grandlyon.com/ws/rdata";
const GEO_BASE      = `${DATA_BASE}/geoserver/ogc/features/v1/collections`;

const ALERTS_URL    = `${DOWNLOAD_BASE}/tcl_sytral.tclalertetrafic_2/all.json`;
const PASSAGES_URL  = `${DOWNLOAD_BASE}/tcl_sytral.tclpassagearret/all.json`;
const VEHICLES_URL  = `${DATA_BASE}/siri-lite/2.0/vehicle-monitoring.json`;

const GEO_COLLECTIONS = {
  "metro-funi-lines": "sytral:tcl_sytral.tcllignemf_2_0_0",
  "tram-lines":       "sytral:tcl_sytral.tcllignetram_2_0_0",
  "bus-lines":        "sytral:tcl_sytral.tcllignebus_2_0_0",
  "stops":            "sytral:tcl_sytral.tclarret",
};

const ALLOWED_UA      = /^AlerteTCL\//;
const ALLOWED_SORTBY  = new Set(["heurepassage", "id"]);
const ALLOWED_SORTORDER = new Set(["asc", "desc"]);

function parsePositiveInt(raw) {
  if (!raw) return null;
  const n = parseInt(raw, 10);
  if (isNaN(n) || n <= 0 || String(n) !== String(raw).trim()) return null;
  return n;
}

async function proxyFetch(upstreamURL, authHeaders) {
  const upstream = await fetch(upstreamURL, { method: "GET", headers: authHeaders });
  const body = await upstream.arrayBuffer();
  return new Response(body, {
    status: upstream.status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

export default {
  async fetch(request, env) {
    const userAgent = request.headers.get("User-Agent") ?? "";
    if (!ALLOWED_UA.test(userAgent)) {
      return new Response("Forbidden", { status: 403 });
    }
    if (request.method !== "GET") {
      return new Response("Method Not Allowed", { status: 405 });
    }

    const username = env.GRANDLYON_USERNAME;
    const password = env.GRANDLYON_PASSWORD;
    if (!username || !password) {
      return new Response("Worker misconfigured: missing secrets", { status: 500 });
    }

    const authHeaders = {
      Authorization: `Basic ${btoa(`${username}:${password}`)}`,
      Accept: "application/json",
      "User-Agent": "AlerteTCL-Proxy/1.0",
    };

    const parsedURL = new URL(request.url);
    const { pathname, searchParams } = parsedURL;
    // search = la query string brute (ex: "?f=application/json&limit=10000")
    // On l'utilise pour les routes GeoServer afin d'éviter que URLSearchParams
    // encode les caractères valides comme '/' en '%2F'.
    const rawSearch = parsedURL.search;

    // ── /alerts ─────────────────────────────────────────────────────────────
    if (pathname === "/alerts") {
      return proxyFetch(ALERTS_URL, authHeaders);
    }

    // ── /passages?id=<int>[&sortby=&sortorder=] ──────────────────────────────
    if (pathname === "/passages") {
      const stopId = parsePositiveInt(searchParams.get("id"));
      if (!stopId) {
        return new Response("Bad Request: missing or invalid id", { status: 400 });
      }
      let url = `${PASSAGES_URL}?field=id&value=${stopId}&compact=false`;
      const sortby = searchParams.get("sortby");
      const sortorder = searchParams.get("sortorder");
      if (sortby && ALLOWED_SORTBY.has(sortby))     url += `&sortby=${sortby}`;
      if (sortorder && ALLOWED_SORTORDER.has(sortorder)) url += `&sortorder=${sortorder}`;
      return proxyFetch(url, authHeaders);
    }

    // ── /vehicles ───────────────────────────────────────────────────────────
    if (pathname === "/vehicles") {
      return proxyFetch(VEHICLES_URL, authHeaders);
    }

    // ── /metro-funi-lines | /tram-lines | /bus-lines | /stops ───────────────
    // On forward la query string brute (rawSearch) pour ne pas ré-encoder
    // des caractères valides comme '/' dans "f=application/json".
    // GeoServer exige un sortby explicite sur les collections sans clé primaire
    // (metro, tram, bus) — on injecte sortby=gid si l'app ne le fournit pas.
    const collection = GEO_COLLECTIONS[pathname.slice(1)];
    if (collection) {
      let qs = rawSearch;
      if (!searchParams.has("sortby")) {
        qs = qs ? `${qs}&sortby=gid` : "?sortby=gid";
      }
      const url = `${GEO_BASE}/${collection}/items${qs}`;
      return proxyFetch(url, authHeaders);
    }

    return new Response("Not Found", { status: 404 });
  },
};
