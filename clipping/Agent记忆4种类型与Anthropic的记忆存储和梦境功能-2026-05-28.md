---
title: "你能亲眼看到Claude在做什么'梦'！Agent的梦境、记忆存储和4种记忆类型"
source: https://mp.weixin.qq.com/s/iuZeWgAfQlrIhSAJS--9xg
author: 玉澄 / 51CTO技术栈（整合自 IBM Martin Keen + Anthropic Kevin Chen 演讲）
date: 2026-05-28
tags: [Agent, 记忆系统, CoALA, Memory Store, Dream, Anthropic]
---

> **核心观点**：记忆才是真正将聊天 Bot 与 Agent 区分开来的东西。Anthropic 工程师 Kevin Chen 介绍了两个新功能——"记忆存储"（Memory Store，文件系统挂载式跨会话持久化）和"梦境"（Dream，异步多 Agent 记忆整理 Harness）；IBM 的 Martin Keen 用 CoALA 框架梳理了 Agent 的 4 种记忆类型。

---

## 一、AI Agent 的 4 种记忆类型（CoALA 框架）

基于普林斯顿研究团队提出的 **CoALA（语言智能体认知架构）** 框架，Agent 的记忆与人类记忆一一对应：

| Agent 记忆 | 对应人类记忆 | 工程实现 |
|---|---|---|
| **工作记忆**（Working Memory） | 短期记忆（此刻大脑活跃内容） | 上下文窗口（Context Window） |
| **语义记忆**（Semantic Memory） | 事实性知识（"Python 是解释型语言"） | 知识库 Markdown 文件，如 CLAUDE.md |
| **程序性记忆**（Procedural Memory） | 习得技能（写代码、主持会议） | Agent Skills / skill.md |
| **情景记忆**（Episodic Memory） | 个人经历（过去的交互和决策） | 跨会话经验提炼，最难实现 |

### 各类型详解

**工作记忆**：Agent 的上下文窗口。当前会话、系统指令、加载的文件都在窗口里。像 RAM，速度极快，但是易失的（会话结束即消失）。上限现已可达 100 万 Token+，但塞太多信息模型会"漏掉"中间内容。

**语义记忆**：Agent 的知识库。生产级 Agent 中通常就是 Markdown 文件（如 Claude Code 的 CLAUDE.md）。每次会话开始时加载进上下文窗口，防止 Agent 反复犯同样的错误。

**程序性记忆**：Agent 知道"怎么做事"。开发标准是 Agent Skills（skill.md 格式）。采用"渐进式披露"机制——先展示具备哪些技能，需要时再加载指令，执行时按需拉取资源。

**情景记忆**：最难的一类。Agent 跨会话工作时，不是记录一切，而是提炼和压缩对未来有帮助的内容。工程核心难题是**遗忘**：该删什么？信息何时过时？用户换工作了，还保留旧项目记忆吗？"人类其实很擅长遗忘，但对于 Agent 来说，遗忘是一个工程难题。"

### 不同 Agent 需要的记忆类型不同

- **客服 Agent**（如密码重置）：工作记忆 + 程序性记忆（2 种）
- **编程 Agent**（如 Claude Code）：全部 4 种——上下文 + 产品知识 + Skills + 跨会话经验

> "记忆才是真正将聊天 Bot 与 Agent 区分开来的东西，因为聊天 Bot 只是给出一个回复，而 Agent 给出的回复是可以由持久化知识和积累的经验所塑造的。"

---

## 二、Anthropic 的两个新功能

来自 Anthropic 工程师 Kevin Chen 在官方频道的演讲。

### 记忆存储（Memory Store）

**问题**：没有 Memory Store 之前，Agent 无法跨会话搜索信息。在 A 会话告诉 Agent 某件事，在 B 会话问它，它完全不知道。

**方案**：Memory Store 是一个**类文件系统的持久化存储库**，作为一种资源附加（挂载）到会话容器中，模型拥有对其进行读写的工具。

特点：
- 可以为每个用户、每个工作区分别创建独立的 Memory Store，自定义边界
- 用户可以用类 bash 工具探索文件系统，Agent 可以用 `grep` 搜索关键词，读取文件
- 额外提供 CLI endpoints，允许手动检查和直接编辑记忆文件

> "对模型来说，把'记忆存储'文件系统挂载到会话上，是一种非常强大的接口。"

### 梦境（Dream）

**问题**：随着时间推移，Memory Store 容量不断增长。防止 Agent 在记忆容器里"胡乱倾倒信息"，需要定期整理。

**方案**："梦境"是一个**后台异步批处理任务**，可通过 Anthropic API 或控制台启动。

工作方式：
1. 指定输入 Memory Store + 一组历史会话文本（Transcripts）
2. 运行多 Agent Harness：多个子 Agent 各自检查对话文本（每个有专属 system prompt），编排器（Orchestrator）确保所有子 Agent 正常运行
3. 仔细浏览内容：事实核查、用日期/标识符丰富细节、检查重复内容并修补漏洞
4. 输出**克隆版本**的 Memory Store（非破坏性——不直接修改原始记忆文件）
5. 最终给出输入与输出 Memory Store 的 **Diff**

可配置参数：
- 每次处理 10 / 20 / 100 个会话（可调节）
- 可附加指令，如"重点关注极度精确的细节"

**成本**：预计消耗大量 Token，但实际成本远低于预期。"梦境"功能缓存命中率约 **95%**，缓存命中 Token 价格仅为普通输入 Token 的 1/10（或更低）。

**可观测性**："梦境"功能本身基于云管理 Agent 底层构建，运行时会创建一个独立会话，可以点进去亲眼看到"梦"在做什么，支持诊断和排查。

---

## 三层递进架构总结

```
会话（Session）
  ↓ 产生对话文本（Transcripts）
记忆存储（Memory Store）← 跨会话读写，文件系统接口
  ↓ 定期触发
梦境（Dream）← 异步整理、去重、补全、生成 Diff
  ↓
更新后的记忆存储（优化后的持久化知识）
```

通过三层结构，随着会话数量增加，记忆库保持在合理规模——可管理、不无限膨胀、内容保持最新。

---

参考视频：
- IBM Martin Keen: https://www.youtube.com/watch?v=BacJ6sEhqMo
- Anthropic Kevin Chen: https://www.youtube.com/watch?v=geUv4CjPpxI
