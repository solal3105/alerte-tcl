#!/usr/bin/env bash
# Temporaire : lancé sur l'émulateur par android-emulator-runner. Passe l'intro et l'accueil, dépose le
# modèle d'amorce de la prévision Vélo'v (le relais ne le publie pas encore), puis capture la carte et
# la fiche d'une station.
set -x
APP=com.alertetcl.android
mkdir -p shots
shot() { adb exec-out screencap -p > "shots/$1.png"; }
launch() { adb shell am force-stop $APP; adb shell am start -n $APP/.MainActivity --es demo "$1"; }
dump() {
  rm -f /tmp/ui.xml
  timeout 30 adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  timeout 10 adb shell cat /sdcard/ui.xml > /tmp/ui.xml 2>/dev/null
  grep -q '<hierarchy' /tmp/ui.xml || : > /tmp/ui.xml
}
has() { grep -q "text=\"$1" /tmp/ui.xml; }
# Touche le nœud dont l'attribut $1 commence par $2, à la fraction $3 de sa largeur (0.5 par défaut).
tap_node() {
  local xy
  xy=$(python3 - "$1" "$2" "${3:-0.5}" <<'PY'
import re, sys
xml = open('/tmp/ui.xml', encoding='utf-8', errors='ignore').read()
m = re.search(r'%s="%s[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"' % (sys.argv[1], re.escape(sys.argv[2])), xml)
if m:
    x1, y1, x2, y2 = map(int, m.groups())
    print(int(x1 + (x2 - x1) * float(sys.argv[3])), (y1 + y2) // 2)
PY
)
  [ -n "$xy" ] && adb shell input tap $xy
}
tap_text() { tap_node text "$1"; }

# Le lanceur Pixel se fige souvent sur l'émulateur de GitHub ; l'application est lancée directement.
adb shell pm disable-user --user 0 com.google.android.apps.nexuslauncher || true
sleep 20
APK=$(find androidApp/build/outputs/apk/debug -name '*.apk' | head -1)
adb install -r -g "$APK"
adb emu geo fix 4.8320 45.7578 || true
launch velov
sleep 15
shot android-0-lancement
# 1. L'intro : « Passer l'intro » (à sa place connue si l'écran animé ne se laisse pas lire).
for i in $(seq 1 8); do
  dump
  if has "Wait"; then tap_text "Wait"
  elif has "Passer l"; then tap_text "Passer l"; break
  elif [ ! -s /tmp/ui.xml ]; then adb shell input tap 900 204; break
  fi
  sleep 3
done
sleep 5
# 2. L'accueil : feuilles « localisation » puis « notifications », « Plus tard » ou Retour.
for i in 1 2 3; do
  dump
  if has "Wait"; then tap_text "Wait"; fi
  if has "Plus tard"; then tap_text "Plus tard"; else adb shell input keyevent KEYCODE_BACK; fi
  sleep 4
done
adb shell am force-stop $APP

# 3. Le modèle et son reçu, dans le dossier de cache de l'application.
python3 .github/ecrans/recu.py /tmp/recu.json
adb push velov-prevision/amorce/modele.json /data/local/tmp/modele.json
adb push /tmp/recu.json /data/local/tmp/recu.json
adb shell chmod 644 /data/local/tmp/modele.json /data/local/tmp/recu.json
adb shell "run-as $APP sh -c 'mkdir -p cache && cat /data/local/tmp/modele.json > cache/velov-prevision-modele.json && cat /data/local/tmp/recu.json > cache/velov-prevision-recu.json && ls -la cache'"

# 4. La carte des stations et son curseur d'heure.
adb logcat -c
launch velov
sleep 30
dump
if has "Wait"; then tap_text "Wait"; sleep 3; fi
shot android-1-carte-maintenant
dump
tap_node content-desc "Heure de la pr" 0.09
sleep 4
shot android-2-carte-plus-2h
tap_node content-desc "Heure de la pr" 0.5
sleep 4
shot android-3-carte-demain
adb logcat -d | grep -i -E "mbgl|maplibre|AndroidRuntime|velov" | tail -150 > shots/android-journal-carte.txt

# 4 bis. La même carte vue de plus loin (points de couleur), pour vérifier que les stations se dessinent.
launch velov-electriques
sleep 30
shot android-3b-carte-loin
dump
tap_node content-desc "Heure de la pr" 0.5
sleep 4
shot android-3c-carte-loin-demain

# 5. La fiche d'une station.
launch velov-station
sleep 30
shot android-4-fiche-ouverture
dump
tap_node content-desc "Heure de la pr" 0.09
sleep 3
shot android-5-fiche-plus-2h
tap_node content-desc "Heure de la pr" 0.5
sleep 3
shot android-6-fiche-demain
dump
tap_text "Places"
sleep 3
shot android-7-fiche-places
dump
tap_text "Électriques"
sleep 3
shot android-8-fiche-electriques
dump
tap_text "Classiques"
sleep 3
shot android-9-fiche-classiques
adb shell cmd uimode night yes
sleep 8
dump
shot android-10-sombre
adb shell cmd uimode night no
ls -la shots
