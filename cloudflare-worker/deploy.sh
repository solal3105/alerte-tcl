#!/usr/bin/env bash
# deploy.sh — Déploiement complet du proxy TCL sur Cloudflare Workers
# Usage : bash cloudflare-worker/deploy.sh

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
RESET="\033[0m"

info()    { echo -e "${BOLD}[→]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
die()     { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

# ── 0. Se placer dans le dossier du worker ─────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
info "Dossier de travail : $SCRIPT_DIR"

# ── 1. Node.js ─────────────────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
  die "Node.js non trouvé. Installe-le depuis https://nodejs.org (LTS recommandé)"
fi
NODE_VERSION=$(node -v)
success "Node.js $NODE_VERSION détecté"

# ── 2. Wrangler ────────────────────────────────────────────────────────────
if ! command -v wrangler &>/dev/null; then
  warn "Wrangler non trouvé — installation globale..."
  npm install -g wrangler
fi
# Le cache partagé (objet durable SQLite, wrangler.toml) demande Wrangler 4 ou plus.
WRANGLER_MAJOR=$(wrangler --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d. -f1)
if [[ -z "$WRANGLER_MAJOR" || "$WRANGLER_MAJOR" -lt 4 ]]; then
  warn "Wrangler trop ancien — mise à jour..."
  npm install -g wrangler@latest
fi
WRANGLER_VERSION=$(wrangler --version 2>/dev/null | head -1)
success "Wrangler $WRANGLER_VERSION prêt"

# ── 3. Authentification Cloudflare ────────────────────────────────────────
info "Vérification de la session Cloudflare..."
if ! wrangler whoami &>/dev/null; then
  warn "Non connecté — ouverture du navigateur pour se connecter..."
  wrangler login
fi
success "Connecté à Cloudflare"

# ── 4. Déploiement du Worker ──────────────────────────────────────────────
info "Déploiement du Worker..."
DEPLOY_OUTPUT=$(wrangler deploy 2>&1)
echo "$DEPLOY_OUTPUT"

# Extraire l'URL du worker depuis l'output de wrangler
WORKER_URL=$(echo "$DEPLOY_OUTPUT" | grep -oE 'https://[a-zA-Z0-9._-]+\.workers\.dev' | head -1)

if [[ -z "$WORKER_URL" ]]; then
  die "Impossible d'extraire l'URL du Worker. Vérifie l'output ci-dessus."
fi
success "Worker déployé sur $WORKER_URL"

# ── 5. Secrets ────────────────────────────────────────────────────────────
# Les secrets survivent aux redéploiements : on ne les redemande que s'ils manquent
# ou si l'utilisateur veut les changer.
echo ""
if wrangler secret list 2>/dev/null | grep -q GRANDLYON_USERNAME; then
  echo -n "Secrets Grand Lyon déjà configurés. Les remplacer ? (o/N) "
  read -r REPLACE_SECRETS
else
  REPLACE_SECRETS="o"
fi

if [[ "$REPLACE_SECRETS" =~ ^[oOyY]$ ]]; then
  info "Configuration des secrets Grand Lyon (stockés chiffrés côté Cloudflare)"
  echo -e "${YELLOW}Ces credentials ne seront JAMAIS dans le code source.${RESET}"
  echo ""

  echo -n "Email Grand Lyon Data : "
  read -r GL_USERNAME

  echo -n "Mot de passe Grand Lyon Data : "
  read -rs GL_PASSWORD
  echo ""

  echo "$GL_USERNAME" | wrangler secret put GRANDLYON_USERNAME
  echo "$GL_PASSWORD" | wrangler secret put GRANDLYON_PASSWORD

  success "Secrets enregistrés"
else
  success "Secrets conservés"
fi

# ── 6. Vérification rapide ────────────────────────────────────────────────
# Appel du relais comme le font les applications : relay <chemin> [options curl]
relay() {
  local path="$1"; shift
  curl -s -H "User-Agent: AlerteTCL/1.0" "$@" "$WORKER_URL$path"
}
http_status() { relay "$1" -o /dev/null -w "%{http_code}"; }
# En-tête d'une réponse : response_header <chemin> <nom en minuscules> [options curl]
response_header() {
  local path="$1" name="$2"; shift 2
  relay "$path" -o /dev/null -D - "$@" \
    | tr -d '\r' | awk -F': ' -v name="$name" 'tolower($1) == name { print $2 }'
}

info "Test de la route /alerts..."
HTTP_STATUS=$(http_status /alerts)

if [[ "$HTTP_STATUS" == "200" ]]; then
  success "Route /alerts répond HTTP 200 ✓"
else
  warn "Route /alerts répond HTTP $HTTP_STATUS — vérifie les secrets ou le déploiement"
fi

# Deux appels à /vehicles doivent renvoyer la même copie (même X-Cached-At) :
# preuve que Grand Lyon n'est interrogé qu'une fois par période.
info "Test du cache partagé sur /vehicles..."
FIRST=$(response_header /vehicles x-cached-at)
sleep 2
SECOND=$(response_header /vehicles x-cached-at)
if [[ -n "$FIRST" && "$FIRST" == "$SECOND" ]]; then
  success "Cache partagé actif sur /vehicles ✓"
else
  warn "Cache partagé non confirmé sur /vehicles (« $FIRST » puis « $SECOND ») — vérifie le déploiement"
fi

# Relevés Vélo'v : la route doit répondre tout de suite, mais la liste des jours est vide juste
# après une première mise en ligne (le déclencheur planifié met jusqu'à 15 minutes à se propager,
# puis relève toutes les 5 minutes). Dès qu'il y a des relevés, le dernier doit être récent.
info "Test des relevés Vélo'v (/velov-releves)..."
RELEVES_CHECK="curl -H 'User-Agent: AlerteTCL/1.0' $WORKER_URL/velov-releves"
RELEVES_DAYS=$(relay /velov-releves)
LAST_DAY=$(echo "$RELEVES_DAYS" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | tail -1 || true)
if [[ "$RELEVES_DAYS" != '{"jours":['* ]]; then
  warn "Route /velov-releves : réponse inattendue (« ${RELEVES_DAYS:0:80} ») — vérifie le déploiement"
elif [[ -z "$LAST_DAY" ]]; then
  warn "Route /velov-releves en place, aucun relevé pour l'instant — le premier arrive sous 20 minutes, à revérifier : $RELEVES_CHECK"
else
  LAST_READING=$(relay "/velov-releves?jour=$LAST_DAY" --compressed | grep -oE '"t":[0-9]+' | tail -1 | cut -d: -f2 || true)
  READING_AGE=$(( $(date +%s) - ${LAST_READING:-0} ))
  if [[ "$READING_AGE" -lt 1200 ]]; then
    success "Relevés Vélo'v : dernier relevé il y a $((READING_AGE / 60)) min ✓"
  else
    warn "Relevés Vélo'v : dernier relevé il y a $((READING_AGE / 60)) min — la collecte semble arrêtée (wrangler tail, puis $RELEVES_CHECK)"
  fi
fi

# Modèle de prévision Vélo'v : relayé depuis la branche GitHub velov-prevision, absente tant que
# le premier entraînement n'a pas tourné. modele.json pèse ≈ 4,5 Mo : il doit arriver compressé.
info "Test du relais du modèle de prévision Vélo'v..."
MODEL_STATUS=$(http_status /velov-prevision/index.json)
if [[ "$MODEL_STATUS" == "404" ]]; then
  warn "Modèle de prévision pas encore publié (branche velov-prevision) — à revérifier après le premier entraînement"
elif [[ "$MODEL_STATUS" != "200" || "$(http_status /velov-prevision/modele.json)" != "200" ]]; then
  warn "Relais du modèle de prévision en échec (index.json : HTTP $MODEL_STATUS) — vérifie le déploiement"
else
  MODEL_ENCODING=$(response_header /velov-prevision/modele.json content-encoding -H "Accept-Encoding: gzip")
  if [[ -n "$MODEL_ENCODING" ]]; then
    success "Modèle de prévision relayé et compressé ($MODEL_ENCODING) ✓"
  else
    warn "Modèle de prévision relayé mais non compressé — 4,5 Mo par téléchargement, vérifie la réponse du relais"
  fi
fi

# Coupures du réseau : relayées depuis la branche GitHub coupures, republiée au plus toutes les
# 5 minutes (au moins une fois par heure) par .github/workflows/coupures.yml.
info "Test du relais des coupures..."
COUPURES_STATUS=$(http_status /coupures)
if [[ "$COUPURES_STATUS" == "200" ]]; then
  success "Coupures relayées ✓"
elif [[ "$COUPURES_STATUS" == "404" ]]; then
  warn "Coupures pas encore publiées (branche coupures) — à revérifier après le premier passage du workflow"
else
  warn "Relais des coupures en échec (HTTP $COUPURES_STATUS) — vérifie le déploiement"
fi

# ── 7. Mise à jour automatique de l'adresse du relais côté Swift ──────────
# Une seule adresse, partagée par l'application et l'extension widget.
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROXY_ENDPOINT="$REPO_ROOT/WidgetCommon/ProxyEndpoint.swift"

info "Mise à jour de ProxyEndpoint.swift (baseURL)..."
sed -i '' -E "s|https://[a-zA-Z0-9._-]+\.workers\.dev|$WORKER_URL|g" "$PROXY_ENDPOINT"
success "ProxyEndpoint.swift → $WORKER_URL"

# ── 8. Résumé ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD} Déploiement terminé avec succès !${RESET}"
echo -e "${BOLD}═══════════════════════════════════════════${RESET}"
echo ""
echo -e "  Worker URL       : ${BOLD}$WORKER_URL${RESET}"
echo -e "  /alerts          : alertes TCL"
echo -e "  /passages?id=N   : horaires arrêt"
echo -e "  /vehicles        : positions temps réel"
echo -e "  /metro-funi-lines: tracés métro/funi"
echo -e "  /tram-lines      : tracés tramway"
echo -e "  /bus-lines       : tracés bus C"
echo -e "  /stops           : arrêts GeoServer"
echo -e "  /horaires/...    : fiches horaires théoriques (branche GitHub horaires)"
echo -e "  /velov           : stations Vélo'v"
echo -e "  /velov-releves   : relevés Vélo'v (toutes les 5 min, 75 jours)"
echo -e "  /velov-prevision/: modèle de prévision Vélo'v (branche GitHub velov-prevision)"
echo ""
echo -e "${YELLOW}Prochaines étapes :${RESET}"
echo "  1. Lance Xcode → Product → Build (⌘B) pour vérifier la compilation"
echo "  2. Teste sur simulateur : les alertes et le widget doivent fonctionner"
echo "  3. Archive et soumet sur App Store Connect"
echo ""
