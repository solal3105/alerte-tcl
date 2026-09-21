#!/bin/sh
# Xcode Cloud : prépare ce dont la phase de build « Module partagé Kotlin » a besoin.
# Les machines Xcode Cloud n'ont ni JDK ni SDK Android, et local.properties n'est pas
# versionné : sans cette préparation, Gradle échoue et l'archive s'arrête sur
# « Command PhaseScriptExecution failed ».
set -eu

REPO="${CI_PRIMARY_REPOSITORY_PATH:-$(cd "$(dirname "$0")/.." && pwd)}"

case "$(uname -m)" in
  arm64|aarch64) JDK_ARCH="aarch64" ;;
  *) JDK_ARCH="x64" ;;
esac

# JDK 17 : même version que le poste de développement, au chemin que la phase de build
# essaie en premier (~/jdks/jdk-17.0.12.jdk).
JDK_HOME="$HOME/jdks/jdk-17.0.12.jdk/Contents/Home"
if [ -x "$JDK_HOME/bin/javac" ]; then
  echo "JDK déjà installé : $JDK_HOME"
else
  echo "Installation du JDK 17.0.12 (Temurin, $JDK_ARCH)"
  mkdir -p "$HOME/jdks/jdk-17.0.12.jdk"
  curl -fsSL "https://api.adoptium.net/v3/binary/version/jdk-17.0.12%2B7/mac/$JDK_ARCH/jdk/hotspot/normal/eclipse" \
    | tar xz -C "$HOME/jdks/jdk-17.0.12.jdk" --strip-components=1
fi
JAVA_HOME="$JDK_HOME"
export JAVA_HOME
PATH="$JAVA_HOME/bin:$PATH"
export PATH

# SDK Android : le module partagé applique le plugin Android library, donc Gradle exige
# un SDK même pour construire le framework iOS.
ANDROID_SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
SDKMANAGER="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  echo "Installation des outils en ligne de commande Android dans $ANDROID_SDK"
  mkdir -p "$ANDROID_SDK/cmdline-tools"
  TOOLS_ZIP="$ANDROID_SDK/cmdline-tools/tools.zip"
  curl -fsSL -o "$TOOLS_ZIP" \
    "https://dl.google.com/android/repository/commandlinetools-mac-11076708_latest.zip"
  rm -rf "$ANDROID_SDK/cmdline-tools/latest"
  unzip -q "$TOOLS_ZIP" -d "$ANDROID_SDK/cmdline-tools"
  mv "$ANDROID_SDK/cmdline-tools/cmdline-tools" "$ANDROID_SDK/cmdline-tools/latest"
  rm -f "$TOOLS_ZIP"
fi

if [ ! -d "$ANDROID_SDK/platforms/android-35" ]; then
  echo "Installation de la plateforme Android 35"
  yes | "$SDKMANAGER" --licenses > /dev/null
  "$SDKMANAGER" "platforms;android-35" "build-tools;35.0.0" > /dev/null
fi

# Gradle lit l'emplacement du SDK ici ; le fichier est ignoré par git, donc absent du clone.
if [ ! -f "$REPO/local.properties" ]; then
  echo "sdk.dir=$ANDROID_SDK" > "$REPO/local.properties"
  echo "local.properties écrit : sdk.dir=$ANDROID_SDK"
fi

echo "Préparation terminée : $("$JAVA_HOME/bin/java" -version 2>&1 | head -1)"
