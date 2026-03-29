#!/usr/bin/env bash
set -euo pipefail

BIN="～/mp-article/mp-weixin-skill"
AUTHOR="vicent"
WORKDIR_BASE="～/mp-article"
TOPIC=""
NO_PUBLISH="0"

usage() {
  cat <<'EOF'
Usage:
  publish_topic.sh "主题" [--author NAME] [--bin /path/to/mp-weixin-skill] [--workdir-base /path] [--no-publish]

Options:
  --author        Author name (default: vicent)
  --bin           Path to mp-weixin-skill executable
  --workdir-base  Base directory for generated files
  --no-publish    Only generate files, skip API publish calls
  -h, --help      Show this help
EOF
}

json_field() {
  local input="$1"
  local key="$2"
  printf '%s' "$input" | python3 -c 'import json,sys
key=sys.argv[1]
raw=sys.stdin.read().strip()
if not raw:
    print("")
    raise SystemExit(0)
try:
    d=json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)
print(d.get(key, "") if isinstance(d, dict) else "")' "$key"
}

ensure_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing command: $1" >&2; exit 1; }
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --author)
      AUTHOR="$2"; shift 2 ;;
    --bin)
      BIN="$2"; shift 2 ;;
    --workdir-base)
      WORKDIR_BASE="$2"; shift 2 ;;
    --no-publish)
      NO_PUBLISH="1"; shift ;;
    -h|--help)
      usage; exit 0 ;;
    --*)
      echo "Unknown option: $1" >&2
      usage
      exit 1 ;;
    *)
      if [ -z "$TOPIC" ]; then
        TOPIC="$1"
      else
        echo "Unexpected argument: $1" >&2
        usage
        exit 1
      fi
      shift ;;
  esac
done

if [ -z "$TOPIC" ]; then
  usage
  exit 1
fi

ensure_cmd python3
if [ "$NO_PUBLISH" = "0" ]; then
  ensure_cmd "$BIN"
fi

DATE_TAG="$(date +%Y%m%d-%H%M%S)"
WORKDIR="$WORKDIR_BASE/run-$DATE_TAG"
mkdir -p "$WORKDIR"

ARTICLE_IMAGE="$WORKDIR/article-image.png"
COVER_IMAGE="$WORKDIR/cover-1080x463.png"
CONTENT_TEMPLATE="$WORKDIR/content.template.txt"
CONTENT_FILE="$WORKDIR/content.final.txt"

# Generate deterministic local images without external dependencies.
python3 - "$ARTICLE_IMAGE" "$COVER_IMAGE" <<'PY'
import struct,zlib,sys
article,cover=sys.argv[1],sys.argv[2]

def write_png(path,w,h,pf):
    raw=bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            raw.extend(pf(x,y,w,h))
    def chunk(tag,data):
        return (struct.pack('>I',len(data))+tag+data+
                struct.pack('>I',zlib.crc32(tag+data)&0xffffffff))
    ihdr=struct.pack('>IIBBBBB',w,h,8,2,0,0,0)
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',ihdr)+chunk(b'IDAT',zlib.compress(bytes(raw),9))+chunk(b'IEND',b'')
    with open(path,'wb') as f:
        f.write(png)

def p1(x,y,w,h):
    r=245-(y*90//h); g=235-(x*60//w); b=220-(y*50//h)
    if (x//40)%2==0: b=min(255,b+18)
    return max(0,r),max(0,g),max(0,b)

def p2(x,y,w,h):
    r=25+(x*30//w); g=92+(y*70//h); b=150+(x*80//w)
    if ((x+y)//28)%2==0: r=min(255,r+8); g=min(255,g+8)
    return r,g,b

write_png(article,900,500,p1)
write_png(cover,1080,463,p2)
PY

TITLE="${TOPIC}：从入门到高效实战"
DIGEST="围绕${TOPIC}的快速上手教程，包含工具选择、提示词方法、工作流搭建与一周落地建议。"

cat > "$CONTENT_TEMPLATE" <<EOF
<h1>${TOPIC}：普通人一周就能上手</h1>
<p>这是一篇面向新手的实用教程，目标是用最短时间把${TOPIC}真正用起来。你不需要复杂技术背景，只要抓住“任务拆解、提示词表达、结果迭代”这三个核心动作，就能让AI工具稳定服务日常工作。</p>
<p>第一步是明确目标任务。不要先问“哪个工具最强”，而要先问“我今天要完成什么”。如果是写作，就让AI给出提纲、初稿和改写版；如果是资料整理，就让AI做结构化对比；如果是视觉表达，就用文生图生成封面和配图。任务先清晰，工具选择自然就简单。</p>
<p>第二步是把提示词写具体。可直接套用这个模板：背景 + 目标 + 约束 + 输出格式。比如：我是运营，要写一篇800字教程，读者是零基础用户，语气口语化，分三段，每段有小标题，最后给行动清单。与其一次性追求完美，不如快速得到第一版，再进行多轮精修。</p>
<p>第三步是建立自己的小工作流。你可以固定成“主题输入→提纲→正文→摘要→配图→发布”六步法，每次沿着同一流程执行。这样做的好处是结果稳定、效率可复制，也便于团队协作和复盘优化。</p>
<p>下面是一张示意图，展示从任务到结果的基本路径：</p>
<p><img src="__ARTICLE_IMAGE_URL__" alt="${TOPIC}流程示意图" /></p>
<p>最后给一个一周落地节奏：第1天确定任务场景，第2天完成一篇正文，第3天做一次资料整理，第4天生成封面，第5天沉淀模板，第6天复盘提示词，第7天形成个人SOP。持续一周，你会明显感受到${TOPIC}从“看起来很强”变成“每天真能用”。</p>
EOF

if [ "$NO_PUBLISH" = "1" ]; then
  cp "$CONTENT_TEMPLATE" "$CONTENT_FILE"
  printf '{"workdir":"%s","title":"%s","author":"%s","digest":"%s","content_file":"%s","article_image":"%s","cover_image":"%s","published":false}\n' \
    "$WORKDIR" "$TITLE" "$AUTHOR" "$DIGEST" "$CONTENT_FILE" "$ARTICLE_IMAGE" "$COVER_IMAGE"
  exit 0
fi

if [ ! -f "${HOME}/.weixin_credentials" ]; then
  echo "Missing credentials file: ${HOME}/.weixin_credentials" >&2
  echo "Expected format:" >&2
  echo "  appid=YOUR_APP_ID" >&2
  echo "  secret=YOUR_APP_SECRET" >&2
  exit 1
fi

AUTH_JSON="$($BIN getAuth)"
ACCESS_TOKEN="$(json_field "$AUTH_JSON" access_token)"
[ -n "$ACCESS_TOKEN" ] || { echo "getAuth returned empty access_token: $AUTH_JSON" >&2; exit 1; }

ARTICLE_JSON="$($BIN uploadArticleImage --token "$ACCESS_TOKEN" --path "$ARTICLE_IMAGE")"
ARTICLE_URL="$(json_field "$ARTICLE_JSON" url)"
[ -n "$ARTICLE_URL" ] || { echo "uploadArticleImage returned empty url: $ARTICLE_JSON" >&2; exit 1; }

sed "s|__ARTICLE_IMAGE_URL__|$ARTICLE_URL|g" "$CONTENT_TEMPLATE" > "$CONTENT_FILE"

COVER_JSON="$($BIN uploadCoverImage --token "$ACCESS_TOKEN" --path "$COVER_IMAGE")"
THUMB_MEDIA_ID="$(printf '%s' "$COVER_JSON" | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
try:
    d=json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)
print((d.get("mediaId") or d.get("media_id") or d.get("url") or ""))')"
[ -n "$THUMB_MEDIA_ID" ] || { echo "uploadCoverImage returned empty media id: $COVER_JSON" >&2; exit 1; }

DRAFT_JSON="$($BIN addDraft --token "$ACCESS_TOKEN" --title "$TITLE" --author "$AUTHOR" --content-file "$CONTENT_FILE" --digest "$DIGEST" --thumb-media-id "$THUMB_MEDIA_ID")"
DRAFT_MEDIA_ID="$(json_field "$DRAFT_JSON" media_id)"
[ -n "$DRAFT_MEDIA_ID" ] || { echo "addDraft returned empty media_id: $DRAFT_JSON" >&2; exit 1; }

printf '{"workdir":"%s","title":"%s","author":"%s","digest":"%s","content_file":"%s","article_image":"%s","cover_image":"%s","article_url":"%s","thumb_media_id":"%s","draft_media_id":"%s","published":true}\n' \
  "$WORKDIR" "$TITLE" "$AUTHOR" "$DIGEST" "$CONTENT_FILE" "$ARTICLE_IMAGE" "$COVER_IMAGE" "$ARTICLE_URL" "$THUMB_MEDIA_ID" "$DRAFT_MEDIA_ID"
