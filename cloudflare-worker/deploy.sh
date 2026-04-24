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
echo ""
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

# ── 6. Vérification rapide ────────────────────────────────────────────────
info "Test de la route /alerts..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "User-Agent: AlerteTCL/1.0" \
  "$WORKER_URL/alerts")

if [[ "$HTTP_STATUS" == "200" ]]; then
  success "Route /alerts répond HTTP 200 ✓"
else
  warn "Route /alerts répond HTTP $HTTP_STATUS — vérifie les secrets ou le déploiement"
fi

# ── 7. Mise à jour automatique des fichiers Swift ─────────────────────────
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NETWORK_CONFIG="$REPO_ROOT/AlerteTCL/Services/NetworkConfiguration.swift"
WIDGET_SERVICES="$REPO_ROOT/AlerteTCLWidget/WidgetServices.swift"

info "Mise à jour de NetworkConfiguration.swift (proxyBaseURL)..."
sed -i '' "s|https://tcl-proxy\.YOUR_SUBDOMAIN\.workers\.dev|$WORKER_URL|g" "$NETWORK_CONFIG"
success "NetworkConfiguration.swift → $WORKER_URL"

info "Mise à jour de WidgetServices.swift (passagesEndpoint)..."
sed -i '' "s|https://download\.data\.grandlyon\.com/ws/rdata/tcl_sytral\.tclpassagearret/all\.json|$WORKER_URL/passages|g" "$WIDGET_SERVICES"
success "WidgetServices.swift → $WORKER_URL/passages"

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
echo ""
echo -e "${YELLOW}Prochaines étapes :${RESET}"
echo "  1. Lance Xcode → Product → Build (⌘B) pour vérifier la compilation"
echo "  2. Teste sur simulateur : les alertes et le widget doivent fonctionner"
echo "  3. Archive et soumet sur App Store Connect"
echo ""
