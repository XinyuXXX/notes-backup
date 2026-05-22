---
type: reference
tags: [infra/tailscale, infra/macos, status/active]
created: 2026-05-09
updated: 2026-05-10
---

# Tailscale 本机配置

本机（xuxinyudemacbook-pro）的 Tailscale 暴露策略与常用命令。

## 当前状态（2026-05-09 起）

**仅 tailnet 内访问，公网已关闭**。

```
tailnet IP        : 100.92.47.86
hostname (MagicDNS): xuxinyudemacbook-pro.tail3223b9.ts.net
所属用户          : zrnndc6q9r@
```

## Serve / Funnel 规则

| URL | 端口 | 后端 | 谁能访问 | 用途 |
|---|---|---|---|---|
| `https://xuxinyudemacbook-pro.tail3223b9.ts.net` | 443 | `127.0.0.1:5175` | 仅 tailnet | ai-assistants-web (含 CC Agent `/cc`) |
| `https://xuxinyudemacbook-pro.tail3223b9.ts.net:8443` | 8443 | `localhost:9000` | 仅 tailnet | openclaw-gateway |

**Funnel（公网）已全部关闭**。如果以后想恢复公网，见下方"恢复公网"。

## 常用命令

```bash
# 查看状态
tailscale serve status
tailscale funnel status
tailscale status                      # tailnet 设备列表

# 切公网（开启 Funnel）
sudo tailscale funnel --bg --https=443 http://127.0.0.1:5175

# 切回仅 tailnet（关 Funnel + 重新加 Serve）
sudo tailscale funnel --https=443 off
sudo tailscale serve --bg --https=443 http://127.0.0.1:5175

# 完全关闭 443 上的代理
sudo tailscale serve --https=443 off
```

## 验证访问可达性

```bash
# 本机 dev server
curl -s http://localhost:5175/ -o /dev/null -w "%{http_code}\n"

# tailnet 直连（绕开公网 DNS，强制走 100.x）
curl -sk --noproxy '*' \
  --resolve xuxinyudemacbook-pro.tail3223b9.ts.net:443:100.92.47.86 \
  https://xuxinyudemacbook-pro.tail3223b9.ts.net/

# 公网视角（应失败：208.111.x.x 网关拒接）
curl -s --max-time 8 https://xuxinyudemacbook-pro.tail3223b9.ts.net/
```

## DNS 解析的微妙之处

- 设备**装了 Tailscale 客户端**：MagicDNS 把 `*.ts.net` 解析成 `100.x.x.x`（tailnet IP）→ 走加密隧道
- 设备**没装**：公网 DNS 解析到 `208.111.x.x`（Tailscale 公网网关）→ 因为 Funnel 关，TLS 直接拒
- iPhone/iPad 装了 Tailscale 但**关闭客户端**时，会走公网 DNS → 也连不上
- 想重新连：打开 Tailscale 客户端

## 邀请家人到 tailnet（未来用）

1. 访问 https://login.tailscale.com/admin/users
2. 右上角 **Invite users** → 输入家人邮箱
3. 家人收邮件 → 注册/登录 Tailscale → 装客户端
4. 家人登录后自动加入 tailnet → 可访问 `https://xuxinyudemacbook-pro.tail3223b9.ts.net`
5. 验证：`tailscale status` 应该看到家人的设备出现

**Free 套餐限额**：3 user × 100 device。家人 ≥ 4 人需升级 Personal Pro。

## 恢复公网（紧急情况）

```bash
sudo tailscale funnel --bg --https=443 http://127.0.0.1:5175
tailscale funnel status   # 确认 "Funnel on"
```

## 后台服务依赖

详见 [[本机后台服务 launchd]]（如还没建可在 wiki/ 起一篇）

| 进程 | 端口 | plist | KeepAlive |
|---|---|---|---|
| tailscaled | — | `/Library/LaunchDaemons/com.tailscale.tailscaled.plist` | 系统级 |
| ai-assistants-web (vite dev) | 5175 | `~/Library/LaunchAgents/com.xuxinyu.ai-assistants-web.plist` | true |
| openclaw-gateway | 9000 | `~/Library/LaunchAgents/ai.openclaw.gateway.plist` | true |

## 历史变更

- **2026-05-10**：修复 HMR WebSocket 配置，添加 `wss` + `clientPort: 443` 支持 Tailscale HTTPS 访问。项目改名 `kid-cogtrain` → `ai-assistants-web`。
- **2026-05-09**：从 Funnel（公网）切到 Serve（仅 tailnet）。原因：公网暴露面太大，CC Agent 能跑命令、文件浏览，仅靠 `CC_TOKEN` 防御不够稳。先关公网，仅手机自己用，后续考虑邀请家人到 tailnet。
