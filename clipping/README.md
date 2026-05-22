# raw/clipping/

网页剪藏存放目录。把外部文章（公众号 / 博客 / 论文等）抓成干净 markdown，保留出处元信息，便于以后翻阅、引用、提炼到 `wiki/`。

## 命名约定

```
<文章标题>-<YYYY-MM-DD>.md
```

- 标题保留原文（含中文、空格、`！`等都可），日期为剪藏当日
- 如果同一篇要重新抓取，覆盖即可（symlink 时代不必心疼旧版）

## Frontmatter

每篇至少含这四项：

```yaml
---
title:    文章原标题
author:   作者 / 公众号名
source:   原始 URL
clipped:  YYYY-MM-DD
---
```

## 添加新剪藏（defuddle）

[defuddle](https://github.com/kepano/defuddle) CLI 自动剥掉网页导航/广告/侧栏，输出干净 markdown：

```bash
URL='<paste-here>'
DATE=$(date +%F)
TITLE=$(defuddle parse "$URL" -p title 2>/dev/null)
AUTHOR=$(defuddle parse "$URL" -p author 2>/dev/null)
DEST="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Xinyu's Vault/raw/clipping/${TITLE}-${DATE}.md"

{
  printf -- "---\ntitle: %s\nauthor: %s\nsource: %s\nclipped: %s\n---\n\n" \
    "$TITLE" "$AUTHOR" "$URL" "$DATE"
  defuddle parse "$URL" --md
} > "$DEST"
```

未装 defuddle：`npm install -g defuddle`

## 批量抓取（多 URL）

**实测教训**：`mp.weixin.qq.com` 在 8 路并行下偶发限流——某些请求会返回空 `title` / 空 markdown（页面结构正常但 defuddle 解析为空）。所以批量必须**两阶段**：

1. **Phase 1** — 8 路并行跑全部 URL
2. **Phase 2** — 收集 Phase 1 失败的，**单线程**逐个重试（限流通常解除）

下面这段开箱即用，改 `URLS=[...]` 后 paste 到 shell：

```bash
python3 << 'PYEOF'
import json, subprocess, os, re
from datetime import date
from concurrent.futures import ThreadPoolExecutor, as_completed

URLS = [
    "https://mp.weixin.qq.com/s/xxxxx",
    "https://mp.weixin.qq.com/s/yyyyy",
]

DEST_DIR = os.path.expanduser(
    "~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Xinyu's Vault/raw/clipping"
)
DATE = date.today().isoformat()
os.makedirs(DEST_DIR, exist_ok=True)

def fetch(url):
    try:
        r = subprocess.run(['defuddle', 'parse', url, '--json'],
                           capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            return (url, None, f"exit={r.returncode}")
        d = json.loads(r.stdout)
        title = (d.get('title') or '').strip()
        author = (d.get('author') or '').strip()
        md = d.get('contentMarkdown') or ''
        if not title or not md:
            return (url, None, "empty title/md (likely rate-limited)")
        safe = re.sub(r'[/:]', '_', title)[:120].rstrip()
        fname = f"{safe}-{DATE}.md"
        path = os.path.join(DEST_DIR, fname)
        fm = (f"---\ntitle: {title}\nauthor: {author}\n"
              f"source: {url}\nclipped: {DATE}\n---\n\n")
        with open(path, 'w') as f:
            f.write(fm + md)
        return (url, fname, None)
    except Exception as e:
        return (url, None, f"{type(e).__name__}: {e}")

# Phase 1: 8 路并行
fail = []
with ThreadPoolExecutor(max_workers=8) as ex:
    for fut in as_completed({ex.submit(fetch, u): u for u in URLS}):
        url, fname, err = fut.result()
        if err:
            fail.append(url); print(f"✗ {url}: {err}")
        else:
            print(f"✓ {fname}")

# Phase 2: 失败的单线程重试
if fail:
    print(f"\n--- retry {len(fail)} failures sequentially ---")
    for url in fail:
        url, fname, err = fetch(url)
        print(f"{'✓ ' + fname if fname else '✗ ' + url + ': ' + err}")

print(f"\nDone. Saved to: {DEST_DIR}")
PYEOF
```

## 与 `wiki/` 的分工

| 目录 | 用途 |
|---|---|
| `raw/clipping/` | **未处理**的原始抓取，按文章原貌保存 |
| `wiki/` | 自己消化、提炼、加入观点后的主题型笔记 |

剪藏看完觉得有长期价值 → 整理重点写到 `wiki/<主题>.md`，原文留在这里作为引用源。

## 跟 raw/daily/ 的区别

`raw/daily/YYYY-MM-DD.md` 是**当天日志**（一日一文件，可含多事）；`raw/clipping/` 是**单篇剪藏**（一篇一文件，按文章而非日期组织）。
