#!/usr/bin/env zsh
set -e

export JAVA_HOME=~/jdks/jdk-17.0.12.jdk/Contents/Home
export ANDROID_HOME=~/Library/Android/sdk
export PATH=$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH

# Démarrer l'émulateur s'il n'y a pas de device connecté
if ! adb devices | grep -q "emulator\|device$"; then
  echo "Démarrage de l'émulateur Pixel_8…"
  emulator -avd Pixel_8 -no-snapshot-save &
  echo "Attente du boot…"
  adb wait-for-device
  adb shell 'while [[ "$(getprop sys.boot_completed)" != "1" ]]; do sleep 1; done'
  echo "Émulateur prêt."
fi

./gradlew :androidApp:installDebug
adb shell am start -n com.alertetcl.android/.MainActivity
echo "App lancée !"
