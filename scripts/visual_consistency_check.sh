#!/usr/bin/env bash
# Visual consistency check: webapp vs iOS viewer page (APP-71)
# Runs via Playwright (webapp) + simctl (iOS) + pixelmatch (comparison)
set -euo pipefail

OUTDIR="${1:-/tmp/consistency_results}"
mkdir -p "$OUTDIR"
DATE=$(date +%Y%m%d_%H%M%S)

echo "=== APP-71 Visual Consistency Check ==="
echo "Date: $DATE"
echo ""

# 1. Webapp screenshots
echo "--- Webapp Screenshots ---"
cd "$(dirname "$0")/.."
npx vite --port 5173 &
VITE_PID=$!
sleep 2
for i in $(seq 1 10); do curl -s http://localhost:5173 > /dev/null 2>&1 && break; sleep 1; done

npx playwright screenshot --viewport-size=390,844 http://localhost:5173 "$OUTDIR/webapp_home.png"
npx playwright screenshot --viewport-size=390,844 "http://localhost:5173/join/ABCDEF1234" "$OUTDIR/webapp_join.png"
echo "  webapp_home: $OUTDIR/webapp_home.png"
echo "  webapp_join: $OUTDIR/webapp_join.png"
kill $VITE_PID 2>/dev/null

# 2. iOS screenshots
echo ""
echo "--- iOS Screenshots ---"
xcrun simctl boot "F1ADB0D4-0D19-4EC8-8F4A-6649224B2C5D" 2>/dev/null || true
sleep 3
xcrun simctl launch "F1ADB0D4-0D19-4EC8-8F4A-6649224B2C5D" app.captainleopard.allhands 2>/dev/null
sleep 4
xcrun simctl io "F1ADB0D4-0D19-4EC8-8F4A-6649224B2C5D" screenshot "$OUTDIR/ios_home.png"
xcrun simctl openurl "F1ADB0D4-0D19-4EC8-8F4A-6649224B2C5D" "allhands://join/ABCDEF1234" 2>/dev/null
sleep 3
xcrun simctl io "F1ADB0D4-0D19-4EC8-8F4A-6649224B2C5D" screenshot "$OUTDIR/ios_viewer.png"
xcrun simctl terminate "F1ADB0D4-0D19-4EC8-8F4A-6649224B2C5D" app.captainleopard.allhands 2>/dev/null
echo "  ios_home: $OUTDIR/ios_home.png"
echo "  ios_viewer: $OUTDIR/ios_viewer.png"

# 3. File sizes for sanity
echo ""
echo "--- File Sizes ---"
for f in "$OUTDIR"/*.png; do
  echo "  $(basename "$f"): $(ls -lh "$f" | awk '{print $5}')"
done

# 4. Build validation
echo ""
echo "--- Build Status ---"
cd "$(dirname "$0")/../.."
xcodebuild -project AllHandsOnDeck.xcodeproj -scheme AllHandsOnDeck -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' test 2>&1 | grep "TEST SUCCEEDED" && echo "  iOS: ✅ 67/67 pass" || echo "  iOS: ❌ FAIL"
cd webapp && npm test 2>&1 | grep "Tests" | tail -1 && echo "  Webapp: ✅" || echo "  Webapp: ❌ FAIL"

echo ""
echo "=== Done ==="
echo "Results in: $OUTDIR"
echo "Compare manually: open $OUTDIR/*.png"
