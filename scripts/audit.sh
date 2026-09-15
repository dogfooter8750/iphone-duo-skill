#!/usr/bin/env bash
# iPhone Duo readiness audit.
# Greps Swift sources and Info.plist files for patterns that break on a two-display,
# foldable, multi-scene iPhone. Prints a Markdown report. Exit code 0 always; read the report.
#
# Usage: bash scripts/audit.sh [path]   (default: current directory)
# Works with bash 3.2 (macOS default). Needs grep and find only.

set -u
ROOT="${1:-.}"
if [ ! -d "$ROOT" ]; then echo "not a directory: $ROOT" >&2; exit 2; fi

# Swift sources, excluding dependency and build folders.
SWIFT_FILES=$(find "$ROOT" -type f -name '*.swift' \
  -not -path '*/Pods/*' -not -path '*/.build/*' -not -path '*/DerivedData/*' \
  -not -path '*/Carthage/*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null)
PLIST_FILES=$(find "$ROOT" -type f -name 'Info.plist' \
  -not -path '*/Pods/*' -not -path '*/.build/*' -not -path '*/DerivedData/*' \
  -not -path '*/Carthage/*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null)

SWIFT_COUNT=$(printf '%s\n' "$SWIFT_FILES" | grep -c . || true)
TOTAL=0

echo "# iPhone Duo audit"
echo
echo "Root: \`$ROOT\` · Swift files: $SWIFT_COUNT · $(date '+%Y-%m-%d %H:%M')"
echo

# section <title> <why> <grep -E pattern>
section() {
  local title="$1" why="$2" pattern="$3" hits n
  if [ -z "$SWIFT_FILES" ]; then hits=""; else
    hits=$(printf '%s\n' "$SWIFT_FILES" | xargs grep -nE "$pattern" 2>/dev/null || true)
  fi
  n=$(printf '%s\n' "$hits" | grep -c . || true)
  TOTAL=$((TOTAL + n))
  echo "## $title ($n)"
  echo
  echo "$why"
  echo
  if [ "$n" -gt 0 ]; then
    printf '%s\n' "$hits" | sed 's/^/- `/; s/$/`/'
    echo
  fi
}

section "Screen references" \
  "Two displays: \`UIScreen.main\` is ambiguous. Use \`window?.windowScene?.screen\` and \`traitCollection.displayScale\`." \
  'UIScreen\.(main|screens)'

section "Orientation used for layout" \
  "The inner display does not honor supported interface orientations. Decide layout by size class." \
  'UIDevice\.current\.orientation|\.interfaceOrientation|isLandscape|isPortrait|UIDeviceOrientation|UIInterfaceOrientation(Mask)?\.(landscape|portrait)'

section "Idiom checks that pick a layout" \
  "The inner display is regular×regular on a phone. Replace idiom branches with size-class branches." \
  'userInterfaceIdiom|UIUserInterfaceIdiom\.(pad|phone)'

section "Symmetric safe-area math" \
  "Bars sit on one edge; insets are asymmetric. Use \`bounds.inset(by: safeAreaInsets)\`." \
  'safeAreaInsets\.(left|right|top|bottom)[[:space:]]*\*[[:space:]]*2|safeAreaInsets\.(left|right)[[:space:]]*\+[[:space:]]*[a-zA-Z.]*safeAreaInsets\.(left|right)'

section "Custom bar instances" \
  "Only \`UINavigationController\` / \`UITabBarController\` (UIKit) and \`NavigationStack\` / \`NavigationSplitView\` / \`TabView\` (SwiftUI) get the vertical bar layout." \
  'UIToolbar\(|UINavigationBar\(|UITabBar\('

section "Hard-coded iPhone widths (noisy)" \
  "Numbers that match known iPhone point widths next to frame/width/size. Review each; most are false positives." \
  '(width|frame|CGSize|CGRect|maxWidth|minWidth)[^0-9\n]{0,40}\b(320|375|390|393|402|414|428|430|440)\b'

section "Window lookup via UIApplication" \
  "With multiple scenes there is no single key window. Get the window from the view or the scene." \
  'UIApplication\.shared\.(keyWindow|windows)'

section "Hinge angle used in layout (review)" \
  "Hinge data is for effects. Layout should use reserved regions and arrangements." \
  'onHingeChange|UIHingeInteraction'

echo "## Info.plist"
echo
if [ -z "$PLIST_FILES" ]; then
  echo "- no Info.plist found under root (SwiftUI-only targets may generate it; check build settings)"
else
  printf '%s\n' "$PLIST_FILES" | while IFS= read -r p; do
    [ -z "$p" ] && continue
    fs=$(grep -n 'UIRequiresFullScreen' "$p" 2>/dev/null | head -1)
    sm=$(grep -c 'UIApplicationSceneManifest' "$p" 2>/dev/null || true)
    echo "- \`$p\`"
    if [ -n "$fs" ]; then echo "  - has \`UIRequiresFullScreen\` (line ${fs%%:*}): opts out of resizable multitasking; remove for Split View"; fi
    if [ "$sm" -eq 0 ]; then echo "  - no \`UIApplicationSceneManifest\`: app is not on the scene lifecycle; multiple scenes and Split View need it"; else echo "  - scene manifest present"; fi
  done
fi
echo
echo "## Summary"
echo
echo "- code hits: $TOTAL (excluding Info.plist)"
echo "- next: fix by category in SKILL.md §2, then verify in the iPhone Duo simulator (Device Hub poses + Split View)"
