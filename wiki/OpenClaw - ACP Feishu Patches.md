# OpenClaw — ACP Feishu Thread-Bound Resume Patches

**Created**: 2026-05-09
**OpenClaw 版本（pin）**: 2026.4.20
**作用范围**: family-finance feishu group 的 ACP cc-session 复用

`~/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/dist/` 下的两处本地补丁。`npm i -g openclaw@<newer>` 会把整个 dist/ 覆盖掉，**每次升级后都要照本笔记重打**。

---

## 为什么要打这两个 patch

family-finance agent 用 Kimi 当大脑，cc 通过 ACP harness（`@agentclientprotocol/claude-agent-acp`）当工具执行器。理想状态：飞书群里多条记账消息复用同一个 cc session（同一个 `~/.claude/projects/<workspace>/<uuid>.jsonl`）。但 openclaw 2026.4.20 有两处缺口：

1. **飞书 channel plugin 没实现 `resolveInboundConversation`**，且通用 conversationId 解析白名单（`channel:` / `conversation:` / `group:` / `room:` / `dm:`）不认 `chat:` 前缀 —— `sessions_spawn(thread:true)` 在飞书群里直接报 `thread_binding_invalid: Could not resolve a feishu conversation for ACP thread spawn`。
2. **spawn 流程不会自动 lookup 现有 thread binding 复用 cc-side ACP session** —— 即使 thread binding 已存在，每次都生成全新的 sessionKey 并起新的 cc-acp 子进程，导致 `~/.claude/projects/<workspace>/` 每条飞书消息冒一个新 jsonl。

打完后效果：飞书群多条消息共用同一个 `acpxSessionId`（cc-side 真实 session id），同一个 jsonl 持续 append。

---

## Patch 1 — 新建 feishu 的 thread-binding-api.js

**路径**: `~/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/dist/extensions/feishu/thread-binding-api.js`

openclaw 通过 `loadBundledChannelThreadBindingApi(channelId)` 在 `dist/extensions/<channelId>/thread-binding-api.js` 找这个 artifact。Matrix 是 v2026.4.20 唯一带这文件的，飞书 / discord / telegram / slack 都没有。

**全文（直接写入即可）**:

```js
// Local patch (xuxinyu, 2026-05-09): bundled thread-binding-api for feishu.
// Upstream openclaw v2026.4.20 ships matrix-only; without this file the ACP
// thread-bound spawn (sessions_spawn { thread:true }) fails with
// "Could not resolve a feishu conversation for ACP thread spawn." See
// dist/acp-spawn-BbFbKIcs.js:546 (resolveConversationRefForThreadBinding).
// NOTE: this file lives under node_modules and will be wiped on
// `npm i -g openclaw@latest`. Re-apply or upstream a PR.

const FEISHU_TARGET_PREFIXES = ["chat:", "user:", "feishu:"];

function trim(value) {
	return typeof value === "string" ? value.trim() : "";
}

function stripFeishuTargetPrefix(rawTarget) {
	const target = trim(rawTarget);
	if (!target) return "";
	for (const prefix of FEISHU_TARGET_PREFIXES) {
		if (target.startsWith(prefix)) return target.slice(prefix.length).trim();
	}
	return target;
}

const defaultTopLevelPlacement = "current";

function resolveInboundConversation(params) {
	const baseTarget = stripFeishuTargetPrefix(params.to) || stripFeishuTargetPrefix(params.conversationId);
	if (!baseTarget) return null;
	const threadId = params.threadId != null ? trim(String(params.threadId)) : "";
	if (threadId) {
		return {
			conversationId: threadId,
			parentConversationId: baseTarget
		};
	}
	return { conversationId: baseTarget };
}

export { defaultTopLevelPlacement, resolveInboundConversation };
```

升级版本前先检查 upstream 是不是已经补上了：如果 `dist/extensions/feishu/thread-binding-api.js` 已经存在并实现了 `resolveInboundConversation({to:"chat:oc_xxx"})` 返回 `{conversationId:"oc_xxx"}` 的等价行为，就不用打这个 patch 了。

---

## Patch 2 — 改 acp-spawn 让 thread:true 自动复用现有 ACP session

**路径**: `~/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/dist/acp-spawn-BbFbKIcs.js`

> ⚠️ 文件名带 build hash（`BbFbKIcs`），升级后会变。用 `grep -l "function resolveConversationRefForThreadBinding" dist/acp-spawn-*.js` 找新文件。

`prepareAcpThreadBinding` 成功后（即"飞书 conversation 解出来了"），如果当前没传 `resumeSessionId`，就反查现有 binding，提取它的 cc-side `acpxSessionId` 作为 fallback resumeSessionId。这样 spawn 表面上还是新建 sessionKey，但底层 cc-acp 会 resume 旧 session（同一个对话上下文 + 同一个 jsonl）。

### 改动 #1 — 顶部加 import

升级后先用以下命令找新的 `session-meta-*.js` 和 `session-identity-*.js` hash 后缀：

```bash
cd ~/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/dist/
grep -l "function readAcpSessionEntry" session-meta-*.js
grep -l "function resolveRuntimeResumeSessionId" session-identity-*.js
# 找到后再用以下命令对照 export alias 是否还是 n / l / u
grep -E "^export" session-meta-*.js session-identity-*.js
```

文件顶部原本只有：

```js
import { n as readAcpSessionEntry } from "./session-meta-DhSXkn3I.js";
```

改成（按实际 hash 替换）：

```js
import { n as readAcpSessionEntry } from "./session-meta-DhSXkn3I.js";
// LOCAL PATCH (xuxinyu, 2026-05-09): identity helpers used to extract the
// cc-side acpxSessionId from an existing thread-bound ACP session.
import { l as __patchResolveRuntimeResumeSessionId, u as __patchResolveSessionIdentityFromMeta } from "./session-identity-Bln4Y1go.js";
```

### 改动 #2 — `let preparedBinding = null;` 块加 lookup 逻辑

定位用：`grep -n "let preparedBinding = null" dist/acp-spawn-*.js`。

**原始（约 v2026.4.20 第 902-918 行）**:

```js
	let preparedBinding = null;
	if (requestThreadBinding) {
		const prepared = prepareAcpThreadBinding({
			cfg,
			channel: requesterState.origin?.channel,
			accountId: requesterState.origin?.accountId,
			to: requesterState.origin?.to,
			threadId: requesterState.origin?.threadId,
			groupId: ctx.agentGroupId
		});
		if (!prepared.ok) return createAcpSpawnFailure({
			status: "error",
			errorCode: "thread_binding_invalid",
			error: prepared.error
		});
		preparedBinding = prepared.binding;
	}
```

**改成**:

```js
	let preparedBinding = null;
	// LOCAL PATCH (xuxinyu, 2026-05-09): when thread:true and an ACP session is
	// already bound to this conversation, infer resumeSessionId so the new spawn
	// reuses the existing claude-agent-acp subprocess (same conversation context,
	// same ~/.claude/projects jsonl) instead of starting fresh. Upstream openclaw
	// v2026.4.20 only marks the new session as thread-bound, it never looks up an
	// existing binding before creating a new session.
	let inferredResumeSessionId = null;
	if (requestThreadBinding) {
		const prepared = prepareAcpThreadBinding({
			cfg,
			channel: requesterState.origin?.channel,
			accountId: requesterState.origin?.accountId,
			to: requesterState.origin?.to,
			threadId: requesterState.origin?.threadId,
			groupId: ctx.agentGroupId
		});
		if (!prepared.ok) return createAcpSpawnFailure({
			status: "error",
			errorCode: "thread_binding_invalid",
			error: prepared.error
		});
		preparedBinding = prepared.binding;
		if (!params.resumeSessionId) {
			try {
				const existing = getSessionBindingService().resolveByConversation({
					channel: prepared.binding.channel,
					accountId: prepared.binding.accountId,
					conversationId: prepared.binding.conversationId
				});
				const existingTargetKey = existing && typeof existing.targetSessionKey === "string" ? existing.targetSessionKey : "";
				if (/^agent:[^:]+:acp:.+$/.test(existingTargetKey)) {
					// Resolve the cc-side acpxSessionId (NOT the openclaw sessionKey suffix).
					// agents/<agent>/sessions/sessions.json stores acp.identity for each spawn.
					const existingEntry = readAcpSessionEntry({ sessionKey: existingTargetKey, cfg });
					const existingIdentity = __patchResolveSessionIdentityFromMeta(existingEntry?.acp);
					const existingResumeId = __patchResolveRuntimeResumeSessionId(existingIdentity);
					if (existingResumeId) inferredResumeSessionId = existingResumeId;
				}
			} catch {}
		}
	}
```

### 改动 #3 — `initializeAcpSpawnRuntime` 调用处把 `inferredResumeSessionId` 作 fallback

定位用：`grep -n "resumeSessionId: params.resumeSessionId" dist/acp-spawn-*.js`。

**原始（约 v2026.4.20 第 938 行附近）**:

```js
		const initializedSession = await initializeAcpSpawnRuntime({
			cfg,
			sessionKey,
			targetAgentId,
			runtimeMode,
			resumeSessionId: params.resumeSessionId,
			cwd: runtimeCwd
		});
```

**改成**:

```js
		const initializedSession = await initializeAcpSpawnRuntime({
			cfg,
			sessionKey,
			targetAgentId,
			runtimeMode,
			// LOCAL PATCH (xuxinyu, 2026-05-09): inferredResumeSessionId is set
			// above when thread:true matches an existing thread-bound ACP session.
			resumeSessionId: params.resumeSessionId ?? inferredResumeSessionId ?? void 0,
			cwd: runtimeCwd
		});
```

---

## 升级后的重打流程

```bash
# 0. 升级
npm i -g openclaw@<newer>

# 1. 先看 upstream 有没有自己 fix 了（可能 patch 1 和 / 或 patch 2 都不再需要）
ls ~/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/dist/extensions/feishu/thread-binding-api.js 2>&1

# 2. 重打 patch 1（参考上面的 Patch 1 全文）

# 3. 重打 patch 2 前先查清楚 hash 后缀和 export alias
cd ~/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/dist/
grep -l "function readAcpSessionEntry" session-meta-*.js                    # → 新的 session-meta-*.js
grep -l "function resolveRuntimeResumeSessionId" session-identity-*.js      # → 新的 session-identity-*.js
grep -l "function resolveConversationRefForThreadBinding" acp-spawn-*.js    # → 新的 acp-spawn-*.js
grep -E "^export" session-meta-*.js session-identity-*.js                   # 对照 alias n/l/u 是否还是这几个

# 4. 按改动 #1/#2/#3 编辑 acp-spawn-*.js

# 5. 语法检查
node --check ~/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/dist/acp-spawn-*.js

# 6. 单元验证 patch 2 的 lookup 函数（前提：~/.openclaw/agents/claude/sessions/sessions.json 里有历史 ACP entry）
node --input-type=module -e "
import { n as readAcpSessionEntry } from '/Users/xuxinyu/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/dist/session-meta-<NEW_HASH>.js';
import { l as resolveRuntimeResumeSessionId, u as resolveSessionIdentityFromMeta } from '/Users/xuxinyu/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/dist/session-identity-<NEW_HASH>.js';
import fs from 'node:fs';
const sess = JSON.parse(fs.readFileSync('/Users/xuxinyu/.openclaw/agents/claude/sessions/sessions.json','utf8'));
const k = Object.keys(sess).find(x => x.startsWith('agent:claude:acp:'));
const entry = readAcpSessionEntry({ sessionKey: k });
console.log(k, '->', resolveRuntimeResumeSessionId(resolveSessionIdentityFromMeta(entry?.acp)));
"

# 7. 重启 gateway
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway

# 8. 端到端验证：飞书群发 2 条小额测试记账消息（间隔 30s+），然后跑：
python3 -c "
import json
d=json.load(open('/Users/xuxinyu/.openclaw/agents/claude/sessions/sessions.json'))
acps=[(k,v.get('acp',{}).get('identity',{}).get('acpxSessionId'),v.get('acp',{}).get('identity',{}).get('lastUpdatedAt',0)) for k,v in d.items() if k.startswith('agent:claude:acp:')]
acps.sort(key=lambda kv:-kv[2])
print('latest 2 ACP sessions:')
for k,sid,_ in acps[:2]: print(f'  {k} -> acpxSessionId {sid}')
print('REUSE OK ✅' if len(acps)>=2 and acps[0][1]==acps[1][1] else 'REUSE BROKEN ❌')
"
# 期望输出 'REUSE OK ✅' —— 两个不同的 openclaw key 共用同一个 acpxSessionId
```

---

## 长期方向

- 给 openclaw 提 PR：(a) feishu plugin 加 `resolveInboundConversation`；(b) `acp-spawn` 在 thread:true 时自动 lookup-and-resume；(c) 支持 `agents.list[].threadBindings.{idleHours,maxAgeHours}` per-agent override（feishu adapter 内部 manager 闭包目前 read-once，per-agent 不易做）。
- 短期可以包装成 `patch-package`（把 patch 写成 diff 文件，`npm i` 后自动重打）：把这两处改动 export 成 `.patch` 放仓库里，写个 `postinstall` hook 调 `patch-package`。

---

## 受影响 agents（依赖这两个 patch 才能正常 ACP 复用）

2026-05-09 起，5 个 openclaw agent 的 ACP delegation 路径都依赖 patch 1+2：

| Agent | Workspace | model | 备注 |
|---|---|---|---|
| family-finance | `~/workspaces/family-finance` | sonnet | 飞书 group 记账，原型；TOOLS.md/SOUL.md/IDENTITY.md/CLAUDE.md 都已切到 sessions_spawn ACP |
| research | `~/workspaces/research` | opus | 科研主 agent，PDF 解析/Word/Excel/scientific-skills |
| pipeline-research | `~/workspaces/pipeline-research` | opus | 管线调研，临床试验/PubMed/FDA/市场报告 |
| literature-collector | `~/workspaces/literature-collector` | opus | 文献雷达，PubMed 检索/PDF 下载 |
| data-reporting | `~/workspaces/data-reporting` | opus | 数据图表/PPT/机制图/甘特图，pptx/scientific-visualization |

各 workspace 的 `.claude/settings.json` 里 pin 了 model（sonnet vs opus）。每个 workspace 的 TOOLS.md/SOUL.md/IDENTITY.md 都改成"用 sessions_spawn(runtime=acp, agentId=claude, thread:true, mode:'session', cwd=...) 委派"模式 + "派发后立刻 sessions_yield，禁中间状态消息"规则。

**全局 thread binding TTL**：`session.threadBindings.{idleHours: 6, maxAgeHours: 48}`。所有 agent 共享，6 小时无活动解绑、2 天硬上限。openclaw 当前版本不支持 per-agent TTL override（per-agent 需要更深 patch 改 feishu adapter 闭包，性价比低，暂用全局值）。

---

## 相关文件 / 路径

| 用途 | 路径 |
|---|---|
| openclaw 全局安装 | `~/.nvm/versions/node/v22.17.1/lib/node_modules/openclaw/` |
| openclaw config | `~/.openclaw/openclaw.json` |
| ACP child sessions index（看 acpxSessionId 用） | `~/.openclaw/agents/claude/sessions/sessions.json` |
| 各 agent session 索引 | `~/.openclaw/agents/<agent-id>/sessions/sessions.json` |
| cc 端对话 jsonl（每个 acpxSessionId 一个文件） | `~/.claude/projects/-Users-xuxinyu-workspaces-<agent>/<acpxSessionId>.jsonl` |
| 各 agent workspace 配置 | `~/workspaces/<agent>/{TOOLS,SOUL,IDENTITY,CLAUDE,LESSONS_LEARNED}.md` |
| 各 agent workspace 的 model pin | `~/workspaces/<agent>/.claude/settings.json` |
| gateway 日志 | `~/.openclaw/logs/gateway.log` + `/tmp/openclaw/openclaw-<date>.log` |
| Claude 自动记忆（同一份 patch 内容） | `~/.claude/memory/openclaw_acp_patches.md` |
