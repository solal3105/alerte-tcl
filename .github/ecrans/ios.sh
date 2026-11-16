#!/usr/bin/env bash
# Temporaire : compile l'application pour un simulateur iPhone, y dépose le modèle d'amorce de la
# prévision Vélo'v (le relais ne le publie pas encore), puis capture la carte et la fiche d'une station.
set -x
mkdir -p shots
BUNDLE=com.solal.AlerteTCL
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
def version(runtime):
    return [int(n) for n in re.findall(r"\d+", runtime.split("iOS-")[-1])]
runtimes = sorted((r for r in devices if "iOS" in r and devices[r]), key=version)
phones = [d for d in devices[runtimes[-1]] if d["name"].startswith("iPhone")]
preferred = [d for d in phones if d["name"].endswith(" Pro Max")] or [d for d in phones if d["name"].endswith(" Pro")]
print((preferred or phones)[-1]["udid"])
')
xcrun simctl list devices | grep "$UDID"
xcrun simctl boot "$UDID"
xcodebuild -project AlerteTCL.xcodeproj -scheme AlerteTCL -configuration Debug \
  -destination "id=$UDID" -derivedDataPath build CODE_SIGNING_ALLOWED=NO build \
  | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
APP=$(find build/Build/Products/Debug-iphonesimulator -maxdepth 1 -name '*.app' | head -1)
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4
xcrun simctl install "$UDID" "$APP"
xcrun simctl privacy "$UDID" grant location $BUNDLE || true

shot() { xcrun simctl io "$UDID" screenshot "shots/$1.png"; }
launch() {
  xcrun simctl terminate "$UDID" $BUNDLE || true
  xcrun simctl launch "$UDID" $BUNDLE -demo "$1" -hasShownLocationPrompt YES -hasShownNotificationPrompt YES
}
tap() {
  printf 'appId: %s\n---\n- tapOn:\n    text: "%s"\n' "$BUNDLE" "$1" > /tmp/tap.yaml
  maestro test /tmp/tap.yaml || echo "::warning::Maestro n'a pas trouvé « $1 »"
  sleep 3
}
tap_point() {
  printf 'appId: %s\n---\n- tapOn:\n    point: "%s"\n' "$BUNDLE" "$1" > /tmp/tap.yaml
  maestro test /tmp/tap.yaml || echo "::warning::Maestro n'a pas touché $1"
  sleep 3
}

# Un premier lancement crée le dossier de cache, où l'on dépose ensuite le modèle et son reçu.
launch velov
sleep 8
xcrun simctl terminate "$UDID" $BUNDLE
CACHE="$(xcrun simctl get_app_container "$UDID" $BUNDLE data)/Library/Caches"
mkdir -p "$CACHE"
cp velov-prevision/amorce/modele.json "$CACHE/velov-prevision-modele.json"
python3 .github/ecrans/recu.py "$CACHE/velov-prevision-recu.json"
ls -la "$CACHE"

# 1. La carte des stations et son curseur d'heure.
launch velov
sleep 25
shot ios-1-carte-maintenant
maestro hierarchy > shots/ios-hierarchie-carte.json 2>/dev/null || true
tap "Heure de la prévision"
shot ios-2-carte-plus-12h

# 2. La fiche d'une station.
launch velov-station
sleep 25
shot ios-3-fiche-ouverture
maestro hierarchy > shots/ios-hierarchie-fiche.json 2>/dev/null || true
tap "Heure de la prévision"
shot ios-4-fiche-plus-12h
tap "Places"
shot ios-5-fiche-places
tap "Électriques"
shot ios-6-fiche-electriques
xcrun simctl ui "$UDID" appearance dark
sleep 4
shot ios-7-fiche-sombre
xcrun simctl ui "$UDID" appearance light
ls -la shots
