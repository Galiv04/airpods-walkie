#!/bin/bash
# Screenshot automatici dell'app nel simulatore iOS (usato dalla CI, gira anche su un Mac).
# L'app parte in "modalità demo" (-demo <stato>): stati finti, niente audio né rete.
# Uso: tools/ci-screenshots.sh <cartella-output>
set -euo pipefail
OUT="${1:-screenshots}"
mkdir -p "$OUT"
BUNDLE=com.galiv04.airpodswalkie

xcodebuild -project AirPodsWalkie.xcodeproj -scheme AirPodsWalkie -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build-sim \
  CODE_SIGNING_ALLOWED=NO build -quiet
APP=build-sim/Build/Products/Debug-iphonesimulator/AirPodsWalkie.app

# Un iPhone piccolo e uno grande tra quelli disponibili.
DEVICES=$(xcrun simctl list devices available -j | python3 -c '
import json, re, sys
devs = [d for rt, ds in json.load(sys.stdin)["devices"].items() if "iOS" in rt for d in ds]
def first(pat):
    return next((d for d in devs if re.search(pat, d["name"])), None)
picked = []
for pat in (r"^iPhone SE", r"^iPhone 1[0-9]e$", r"^iPhone 1[0-9]$"):
    d = first(pat)
    if d: picked.append(d); break
d = first(r"Pro Max$")
if d: picked.append(d)
if not picked: picked = [d for d in devs if d["name"].startswith("iPhone")][:1]
for d in picked: print(d["udid"] + "|" + d["name"])
')
echo "$DEVICES"

while IFS='|' read -r UDID NAME; do
  [ -z "$UDID" ] && continue
  SLUG=$(echo "$NAME" | tr ' ' '-' | tr -cd 'A-Za-z0-9-')
  xcrun simctl boot "$UDID" || true
  xcrun simctl bootstatus "$UDID" -b
  xcrun simctl status_bar "$UDID" override --time 9:41 --batteryLevel 100 --cellularBars 4 || true
  xcrun simctl install "$UDID" "$APP"
  for STATE in off waiting linked talking remote settings; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE" -demo "$STATE"
    sleep 5
    xcrun simctl io "$UDID" screenshot "$OUT/${SLUG}_${STATE}.png"
  done
  xcrun simctl shutdown "$UDID" || true
done <<< "$DEVICES"
ls -la "$OUT"
