#!/bin/bash

# frendetta (made by redstonekasi with pain)

# specify $ANDROID_SERIAL to install to a specific device
# i'm making an actual patcher app in the future so neither a pc or adb will be required

OS=$(uname)
case $OS in
  'Darwin')
    DATA=$(mktemp -d -t "frendetta.XXXXXXXX")
    ;;
  *)
    DATA=$(mktemp --directory --tmpdir "frendetta.XXXXXXXX")
    ;;
esac

exec > >(tee "$DATA/frendetta.log") 2>&1

echo "+ storing data and logs in $DATA"

function die {
  [ -z "$@" ] || echo "- $@"
  exit 1
}

function download {
  if [[ -x "$(command -v wget)" ]]; then
      wget -qO "${2:--}" "$1"
      return $?
  elif [[ -x "$(command -v curl)" ]]; then
      curl -fsSL "$1" -o "${2:--}"
      return $?
  fi
  die "failed to download $1. curl or wget not installed"
}

echo "+ checking for availability of dependencies"
java -version || die "java has to be installed and available on path"
adb start-server || die "adb has to be installed and available on path"

echo "+ downloading necessary files"
download "https://github.com/vendetta-mod/VendettaXposed/releases/latest/download/app-release.apk" "$DATA/vendetta.apk" || die "could not download latest vendetta module, contact beef"
download "https://github.com/LSPosed/LSPatch/releases/download/v0.5.1/lspatch.jar" "$DATA/lspatch.jar" || die "could not download lspatch"

echo "+ waiting for device to connect to adb"
adb wait-for-device

echo "+ fetching discord"
DISCORD_PATHS=$(adb shell pm path com.discord) || die "discord is not installed on your phone"

BASE_APK=${DISCORD_PATHS%%$'\n'*}
adb shell unzip -l "${BASE_APK#"package:"}" | grep -q lspatch && die "vendetta is already installed"

mkdir "$DATA/original"
while IFS= read -r file; do
  NAME=${file#"package:"}
  adb pull $NAME "$DATA/original/$(basename $NAME)"
done <<< "$DISCORD_PATHS"

echo "+ patching discord"
FILES="$DATA/original/*.apk"
java -jar "$DATA/lspatch.jar" -m "$DATA/vendetta.apk" -l 2 -o "$DATA/patched" $FILES

echo "+ uninstalling discord"
adb uninstall com.discord

echo "+ installing vendetta"
PATCHED="$DATA/patched/*.apk"
adb install-multiple $PATCHED

[[ "$(read -e -p "+ vendetta is now installed, delete temporary files (including logs!) at $DATA [y/N]?> "; echo $REPLY)" == [Yy]* ]] && rm -rf $DATA || exit 0
