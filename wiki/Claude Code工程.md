---
title: Claude Code工程
tags: [知识库, Claude Code工程]
updated: 2026-05-16
---

## 主题概要

Claude Code 不仅是一个 AI 编程工具，更是一套已经承受住复杂度的 Agent 系统参照物。从 92% 缓存命中率的上下文工程，到多 Agent 扩展层的启动链路设计，再到 Computer Use 的 GUI 操控能力，Claude Code 的工程决策揭示了一个核心原则：把复杂度前置到启动层和架构层，让运行时主链路保持纯粹。而在大型代码库场景中，代码库、工具链和组织流程需要被整理成 Agent 能导航、能执行、能验证、能复用的工程环境——这本质上是一场开发者体验工程。

## 核心概念

- **Prompt Caching 三层布局**：全局层（系统提示词、工具定义）、项目层（CLAUDE.md）、动态尾部（任务历史）。92% 命中率的前提是把稳定内容和动态内容治理清楚。
- **启动三段式**：入口分流 → 进程初始化 → 会话准备。把启动模式、运行环境、会话制度、宿主承载显式拆开，避免运行时主循环变脏。
- **进程状态 vs 交互状态**：cwd、projectRoot、sessionId 等基础设施状态沉在底层；tasks、MCP clients、permission context 等控制面状态进入 AppState。
- **验证闭环**：让 AI 自己运行测试、构建检查、Lint、浏览器测试，发现问题自己修，修到对了再告诉用户。质量可提升 2-3 倍。
- **Computer Use**：Claude Code CLI 直接操控 GUI（点击、输入、截图），实现"写代码→编译→启动应用→点击测试→发现 bug→修复→验证"的完整闭环。
- **代码库 Agent 化**：大型代码库的难点不在行数，而在知识散落。CLAUDE.md 提供轻量行为契约，Skills/Hooks/Plugins/MCP/LSP/Subagents 分别处理专业知识、确定性动作、组织分发、外部工具、符号导航和上下文隔离。

## 文章洞见

### [[Claude Code 为什么缓存命中率能做到 92%？一篇讲清 Prompt Caching 的工程逻辑|Claude Code 为什么缓存命中率能做到 92%？]]
> 若飞 · 2026-05-10

Prompt Caching 不是"后面有空再做"的优化，而是长任务 Agent 的基本盘。Claude Code 把上下文分为四层，缓存点随对话增长自动前移。关键纪律：缓存靠 exact prefix match，`tools -> system -> messages` 顺序被动一下，后面整段重算。把 `CLAUDE.md` 瘦身、把专用规则移进 Skills、把冗长输出交给 hooks 和 subagents，比多写几段 Prompt 管用。

### [[Claude Code 实战：让 AI 验证结果，形成反馈闭环，亲测提效|Claude Code 实战：让 AI 验证结果，形成反馈闭环]]
> 彭少 · 2026-05-10

Claude 写完代码自己跑验证，发现问题自己修，质量可提升 2-3 倍。验证方式按任务类型选择：单元测试（后端逻辑）、构建检查（通用）、Lint（代码规范）、浏览器测试（前端 UI）。关键是把验证要求写进指令，或封装成 verify-work / verify-ui Subagent，而不是每次手动检查。

### [[Claude Code 源码拆解：从启动到多 Agent 扩展层|Claude Code 源码拆解：从启动到多 Agent 扩展层]]
> 无岳 · 2026-05-10

Claude Code 的启动链路分三段：入口分流（本地/headless/remote/后台）、进程初始化（配置/telemetry/全局设施）、会话准备（cwd/工具面/权限/扩展能力）。核心判断是"先装配共享 session/runtime 语义，再选择交互式或 headless 宿主"。进程状态和交互状态的显式分层，让多种运行模式共享同一套核心 runtime，避免系统裂成几套。

### [[Claude Code会话管理完全指南|Claude Code会话管理完全指南]]
>  · 2026-05-10

（文章正文在剪藏中主要为 UI 元素，核心内容未完整提取。主题为 Claude Code 会话管理的系统性指南。）

### [[刚刚，Claude Code 新增 Computer Use，CLI 可以直接操控 GUI 了|刚刚，Claude Code 新增 Computer Use]]
> J0hn · 2026-05-10

Claude Code 通过 Computer Use 获得 GUI 操控能力（点击、输入、截图），在终端里直接打开 Mac 应用、复现 bug、修复、验证。演示场景中，Claude 启动像素画编辑器，点击 GEN 按钮复现 ERR 19，截图确认后切回代码层用 grep 定位 bug，修复后出构建。标志着 CLI Agent 从纯文本走向"文本+GUI"的完整闭环。

### [[我用 Claude Code CLI 搭了一套「不丢上下文」的工作流|我用 Claude Code CLI 搭了一套「不丢上下文」的工作流]]
> 卢灿伟同学 · 2026-05-10

针对 CLI 跨 session 上下文丢失的痛点，设计了"指挥室"模式：单独开一个文件夹管所有项目的节奏（产品决策、需求、进度），技术实现留在各自 repo。核心机制是 `/checkpoint`（随时存档到 `docs/memory/YYYY-MM-DD.md`，subagent 后台执行）和 `/recap`（新 session 开头恢复）。三层记忆：auto memory（Claude 自带）→ 文件级工作日志 → `progress.md` 当前快照。

### [[Claude额度又双叒叕调整：好消息更是坏消息|Claude 额度又双叒叕调整：好消息更是坏消息]]
> AGI Hunt · 2026-05-15

6 月 15 日起，`claude -p`、Agent SDK 和第三方工具的用量不再计入订阅限额，改为独立月度 credit 池（Pro $20，Max 5x $100，Max 20x $200）。好消息是批量脚本不再吃掉交互额度；坏消息是实际可用量缩水约 10 倍——订阅按速率限制有大量补贴，credit 按 API 零售价计费。本质上是 Anthropic 修复"把人类一个月额度几小时跑完"的定价漏洞。

### [[Claude Code 大型代码库实践：把代码库变成 Agent 能工作的现场|Claude Code 大型代码库实践]]
> 若飞 · 2026-05-16

Anthropic 官方发布的大型代码库最佳实践。核心洞察：Claude Code 能进百万行 monorepo 干活，不是因为模型"读懂了一切"，而是代码库、工具链和组织流程被整理成 Agent 能导航、能执行、能验证、能复用的工程环境。CLAUDE.md 是轻量行为契约（根目录给全局地图，子目录给局部约定，越短越值钱）；Skills/Hooks/Plugins/MCP/LSP/Subagents 不是功能堆叠，而是分工明确的专业化组件。组件顺序很关键——先让代码库可读，再把确定性检查交给工具，基础没搭好，MCP 只会把混乱接进更多系统里。

## 延伸阅读

- [[Agent架构与设计]]
- [[Agent记忆系统]]
- [[AI编程工作流]]
