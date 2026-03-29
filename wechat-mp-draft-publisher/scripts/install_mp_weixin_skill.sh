#!/usr/bin/env bash
set -euo pipefail

REPO=""
TAG="latest"
ASSET_NAME=""
OUT=""

usage() {
  cat <<'EOF'
Usage:
  install_mp_weixin_skill.sh --repo owner/repo [--tag latest|vX.Y.Z] [--asset asset-name] [--out /path/to/mp-weixin-skill]

Options:
  --repo    GitHub repository in owner/repo format (required)
  --tag     Release tag, default latest
  --asset   Release asset name; if omitted, auto-detect by platform
  --out     Output binary path; default: <skill>/bin/mp-weixin-skill
  -h, --help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)
      REPO="$2"; shift 2 ;;
    --tag)
      TAG="$2"; shift 2 ;;
    --asset)
      ASSET_NAME="$2"; shift 2 ;;
    --out)
      OUT="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [ -z "$REPO" ]; then
  echo "--repo is required" >&2
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -z "$OUT" ]; then
  OUT="$SKILL_DIR/bin/mp-weixin-skill"
fi
mkdir -p "$(dirname "$OUT")"

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in
  arm64|aarch64) arch="arm64" ;;
  x86_64|amd64) arch="amd64" ;;
esac

if [ -z "$ASSET_NAME" ]; then
  ASSET_NAME="mp-weixin-skill-${os}-${arch}"
  if [ "$os" = "windows" ]; then
    ASSET_NAME="${ASSET_NAME}.exe"
  fi
fi

if [ "$TAG" = "latest" ]; then
  api_url="https://api.github.com/repos/${REPO}/releases/latest"
else
  api_url="https://api.github.com/repos/${REPO}/releases/tags/${TAG}"
fi

auth_header=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

release_json="$(curl -fsSL "${auth_header[@]}" -H "Accept: application/vnd.github+json" "$api_url")"
asset_url="$(
  printf '%s' "$release_json" | python3 - "$ASSET_NAME" <<'PY'
import json, sys
asset_name = sys.argv[1]
data = json.loads(sys.stdin.read())
assets = data.get("assets", [])
exact = [a for a in assets if a.get("name") == asset_name]
if exact:
    print(exact[0].get("browser_download_url", ""))
    raise SystemExit(0)
contains = [a for a in assets if asset_name in (a.get("name") or "")]
if contains:
    print(contains[0].get("browser_download_url", ""))
    raise SystemExit(0)
print("")
PY
)"

if [ -z "$asset_url" ]; then
  echo "Asset not found in release." >&2
  echo "repo: $REPO, tag: $TAG, expected asset: $ASSET_NAME" >&2
  exit 1
fi

tmp_file="${OUT}.download"
curl -fsSL "${auth_header[@]}" -H "Accept: application/octet-stream" -o "$tmp_file" "$asset_url"
chmod +x "$tmp_file"
mv "$tmp_file" "$OUT"

echo "Installed mp-weixin-skill to: $OUT"
