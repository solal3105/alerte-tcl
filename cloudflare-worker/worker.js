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
 *   GET /parc-relais                 → GeoServer tclparcrelaisst/items (statique)
 *   GET /parc-relais-tr              → GeoServer tclparcrelaistr/items (temps réel)
 *
 * Les credentials Grand Lyon sont stockés en secrets Cloudflare chiffrés.
 * Aucune credential n'est dans le code ni dans le binaire iOS.
 *
 * Cache serveur (stale-while-revalidate) :
 *   Grand Lyon reçoit 1 requête toutes les N secondes quel que soit le nombre
 *   d'utilisateurs. Quand le cache est périmé, on sert l'ancienne réponse
 *   immédiatement et on rafraîchit en arrière-plan via ctx.waitUntil().
 *   TTL par route : vehicles/passages 15 s, parc-relais-tr 30 s,
 *                   alerts 60 s, parc-relais statique 1 h, GeoServer 24 h.
 *
 * Déploiement : bash cloudflare-worker/deploy.sh
 */

const DATA_BASE     = "https://data.grandlyon.com";
const DOWNLOAD_BASE = "https://download.data.grandlyon.com/ws/rdata";
const GEO_BASE      = `${DATA_BASE}/geoserver/ogc/features/v1/collections`;

const ALERTS_URL    = `${DOWNLOAD_BASE}/tcl_sytral.tclalertetrafic_2/all.json`;
const PASSAGES_URL  = `${DOWNLOAD_BASE}/tcl_sytral.tclpassagearret/all.json`;
// MaximumVehicles=3000 couvre largement la totalité du parc TCL (~800 véhicules en heure de pointe).
// Sans ce paramètre, Grand Lyon répond avec ≤ 200 véhicules par défaut (MoreData: true ignoré).
const VEHICLES_URL  = `${DATA_BASE}/siri-lite/2.0/vehicle-monitoring.json?MaximumVehicles=3000`;

const GEO_COLLECTIONS = {
  "metro-funi-lines": "sytral:tcl_sytral.tcllignemf_2_0_0",
  "tram-lines":       "sytral:tcl_sytral.tcllignetram_2_0_0",
  "bus-lines":        "sytral:tcl_sytral.tcllignebus_2_0_0",
  "stops":            "sytral:tcl_sytral.tclarret",
  "parc-relais":      "sytral:tcl_sytral.tclparcrelaisst",
  "parc-relais-tr":   "sytral:tcl_sytral.tclparcrelaistr",
};

// TTL (secondes) par route — fréquence de rafraîchissement côté serveur.
// En dehors de ces routes, les collections GeoServer statiques utilisent GEO_TTL.
const ROUTE_TTL = {
  "/vehicles":       15,   // positions temps réel
  "/passages":       15,   // prochains passages
  "/parc-relais-tr": 30,   // occupation P+R temps réel
  "/alerts":         60,   // alertes trafic
  "/parc-relais":    3600, // données P+R statiques
};
const GEO_TTL = 86400; // lignes, arrêts — données quasi-statiques

const ALLOWED_UA        = /^AlerteTCL\//;
const ALLOWED_SORTBY    = new Set(["heurepassage", "id"]);
const ALLOWED_SORTORDER = new Set(["asc", "desc"]);

function parsePositiveInt(raw) {
  if (!raw) return null;
  const n = parseInt(raw, 10);
  if (isNaN(n) || n <= 0 || String(n) !== String(raw).trim()) return null;
  return n;
}

/**
 * Effectue la requête upstream et stocke le résultat dans caches.default.
 * On utilise max-age=86400 pour que Cloudflare conserve l'entrée longtemps ;
 * la fraîcheur réelle est gérée par notre header X-Cached-At.
 */
async function doRefresh(cacheKey, upstreamURL, authHeaders, cache) {
  const upstream = await fetch(upstreamURL, { method: "GET", headers: authHeaders });
  const body = await upstream.arrayBuffer();

  if (upstream.ok) {
    const toStore = new Response(body, {
      status: upstream.status,
      headers: {
        "Content-Type": "application/json",
        "Cache-Control": "public, max-age=86400",
        "X-Cached-At":  String(Date.now()),
      },
    });
    await cache.put(cacheKey, toStore);
  }

  return new Response(body, {
    status:  upstream.status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

/**
 * Variante de doRefresh pour /bus-termini :
 * Fetche la collection bus-lines complète (22 MB) côté serveur,
 * ne conserve que ligne/sens/nom_destination (≈50 KB), cache le résultat allégé.
 */
async function doRefreshBusTermini(cacheKey, authHeaders, cache) {
  const upstreamURL = `${GEO_BASE}/${GEO_COLLECTIONS["bus-lines"]}/items?limit=5000&f=json&sortby=gid`;
  const upstream = await fetch(upstreamURL, { method: "GET", headers: authHeaders });

  if (!upstream.ok) {
    const body = await upstream.arrayBuffer();
    return new Response(body, {
      status: upstream.status,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }

  const data = await upstream.json();
  const stripped = JSON.stringify({
    features: data.features.map(f => ({
      properties: {
        ligne:           f.properties.ligne           ?? null,
        sens:            f.properties.sens            ?? null,
        nom_destination: f.properties.nom_destination ?? null,
      },
    })),
  });

  const buf = new TextEncoder().encode(stripped);
  const toStore = new Response(buf, {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=86400",
      "X-Cached-At":  String(Date.now()),
    },
  });
  await cache.put(cacheKey, toStore.clone());

  return new Response(buf, {
    status: 200,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

/**
 * Stratégie stale-while-revalidate :
 *  - Cache frais (age < ttl)  → réponse immédiate depuis le cache.
 *  - Cache périmé (age ≥ ttl) → réponse immédiate depuis le cache stale
 *                                + refresh en arrière-plan (ctx.waitUntil).
 *  - Aucun cache               → attend la réponse upstream (premier utilisateur).
 *
 * Résultat : Grand Lyon reçoit au plus 1 requête par TTL, quel que soit
 * le nombre d'utilisateurs qui polleraient en même temps.
 */
async function cachedProxyFetch(cacheKeyURL, upstreamURL, authHeaders, ctx, ttl) {
  const cache    = caches.default;
  const cacheKey = new Request(cacheKeyURL);

  const cached = await cache.match(cacheKey);
  if (cached) {
    const cachedAt   = parseInt(cached.headers.get("X-Cached-At") ?? "0", 10);
    const ageSeconds = (Date.now() - cachedAt) / 1000;

    if (ageSeconds < ttl) {
      // Fraîche — servir directement depuis le cache
      const body = await cached.arrayBuffer();
      return new Response(body, {
        status:  cached.status,
        headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
      });
    }

    // Périmée — servir le stale immédiatement + rafraîchir en arrière-plan
    ctx.waitUntil(doRefresh(cacheKey, upstreamURL, authHeaders, cache));
    const body = await cached.arrayBuffer();
    return new Response(body, {
      status:  cached.status,
      headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  }

  // Cache miss — doit attendre upstream (uniquement le tout premier utilisateur)
  return doRefresh(cacheKey, upstreamURL, authHeaders, cache);
}

export default {
  async fetch(request, env, ctx) {
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

    // La clé de cache = URL complète du worker (sans credentials, qui restent
    // dans authHeaders et ne sont jamais dans l'URL).
    const cacheKeyURL = request.url;

    // ── /alerts ─────────────────────────────────────────────────────────────
    if (pathname === "/alerts") {
      return cachedProxyFetch(cacheKeyURL, ALERTS_URL, authHeaders, ctx, ROUTE_TTL["/alerts"]);
    }

    // ── /passages?id=<int>[&sortby=&sortorder=] ──────────────────────────────
    // Chaque arrêt a sa propre clé de cache (l'URL worker inclut ?id=…).
    if (pathname === "/passages") {
      const stopId = parsePositiveInt(searchParams.get("id"));
      if (!stopId) {
        return new Response("Bad Request: missing or invalid id", { status: 400 });
      }
      let url = `${PASSAGES_URL}?field=id&value=${stopId}&compact=false&maxfeatures=500`;
      const sortby = searchParams.get("sortby");
      const sortorder = searchParams.get("sortorder");
      if (sortby && ALLOWED_SORTBY.has(sortby))         url += `&sortby=${sortby}`;
      if (sortorder && ALLOWED_SORTORDER.has(sortorder)) url += `&sortorder=${sortorder}`;
      return cachedProxyFetch(cacheKeyURL, url, authHeaders, ctx, ROUTE_TTL["/passages"]);
    }

    // ── /vehicles ───────────────────────────────────────────────────────────
    if (pathname === "/vehicles") {
      return cachedProxyFetch(cacheKeyURL, VEHICLES_URL, authHeaders, ctx, ROUTE_TTL["/vehicles"]);
    }

    // ── /bus-termini ─────────────────────────────────────────────────────────
    // Retourne ligne+sens+nom_destination pour toutes les lignes bus (géométrie strippée).
    // Payload : 22 MB côté GeoServer → ≈50 KB retourné au client.
    if (pathname === "/bus-termini") {
      const cache    = caches.default;
      const cacheKey = new Request(request.url);

      const cached = await cache.match(cacheKey);
      if (cached) {
        const cachedAt   = parseInt(cached.headers.get("X-Cached-At") ?? "0", 10);
        const ageSeconds = (Date.now() - cachedAt) / 1000;
        if (ageSeconds < GEO_TTL) {
          const body = await cached.arrayBuffer();
          return new Response(body, {
            status:  cached.status,
            headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
          });
        }
        ctx.waitUntil(doRefreshBusTermini(cacheKey, authHeaders, cache));
        const body = await cached.arrayBuffer();
        return new Response(body, {
          status:  cached.status,
          headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
        });
      }
      return doRefreshBusTermini(cacheKey, authHeaders, cache);
    }

    // ── /metro-funi-lines | /tram-lines | /bus-lines | /stops ───────────────
    // ── /parc-relais | /parc-relais-tr ─────────────────────────────────────
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
      const upstreamURL = `${GEO_BASE}/${collection}/items${qs}`;
      const ttl = ROUTE_TTL[pathname] ?? GEO_TTL;
      return cachedProxyFetch(cacheKeyURL, upstreamURL, authHeaders, ctx, ttl);
    }

    return new Response("Not Found", { status: 404 });
  },
};
