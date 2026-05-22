---
title: Agent架构与设计
tags: [知识库, Agent架构与设计]
updated: 2026-05-22
---

## 主题概要

Agent 系统的核心矛盾不在于模型能力，而在于如何构建一个稳健的"Harness"——包裹 LLM 的完整软件基础设施。2026 年的行业共识是：同级别模型差异远小于 Harness 设计差异。从 ReAct、Plan-and-Execute 等控制模式，到 OpenClaw、DeerFlow 等生产级 Harness 实现，Agent 架构正从"Demo 可行"走向"工程可维护"。同时，定时调度、多智能体协作等能力标志着 Agent 从"工具"向"数字员工"的进化。

## 核心概念

- **Harness**：包裹 LLM 的完整运行时基础设施，包括编排循环、工具、记忆、上下文管理、错误处理、安全护栏等。 Harness 决定一切，同级别模型差异不大。
- **Agent Loop**：感知 → 决策 → 行动 → 反馈的循环，是 Agent 的基本控制流。循环本身稳定，新能力通过扩展工具、调整提示词、外化状态接入。
- **生产级 Harness 12 组件**：编排循环、工具、记忆、上下文管理、提示词构建、输出解析、状态管理、错误处理、护栏与安全、验证循环、子 Agent 委托、可观测性。
- **五种控制模式**：提示链（Prompt Chaining）、路由（Routing）、并行化（Parallelization）、编排器-工作者（Orchestrator-Workers）、评估器-优化器（Evaluator-Optimizer）。
- **Workflow vs Agent**：执行路径由代码预写的是 Workflow，由 LLM 动态决定的是 Agent。两者无高下，关键是匹配任务特征。

## 文章洞见

### [[AI Agent六大主流架构范式详解！|AI Agent六大主流架构范式详解！]]
> AI大模型Sam · 2026-05-11

把 2026 年主流的六种 Agent 架构范式（ReAct、Reflection、Plan-and-Execute、Tool Use、Multi-Agent、Computer Use）做了系统梳理。最有价值的是"强弱模型搭配"思路：Planner 用强模型调用 1 次，Executor 用弱模型调用 N 次，成本可降 70%–90%。同时指出 ReAct 短视易绕路，Plan-and-Execute 全局稳定，适合长流程。

### [[Agent Harness 解析：智能体架构深度拆解|Agent Harness 解析：智能体架构深度拆解]]
> AI寒武纪（原文：Akshay Pachaar） · 2026-05-11

提出了"问题不在模型，在模型周围的一切"的核心判断。LangChain 只改 Harness 就从 TerminalBench 30 名跳到第 5。把 Harness 比作操作系统，LLM 比作 CPU——上下文窗口是内存，外部数据库是硬盘，工具是设备驱动。生产级 Harness 的 12 个组件中，错误处理最关键：每步成功率 99% 的 10 步流程，端到端只有 90.4%。

### [[HARNESS决定一切 同级别模型无关重要|HARNESS决定一切 同级别模型无关重要]]
>  · 2026-05-10

（文章正文较短，核心观点与 Harness 解析一致：Harness 的工程化水平比模型选择更能决定 Agent 系统的实际表现。）

### [[Harness 顶级架构：DeerFlow 2.0 沙盒 Sandbox 架构设计、源码深度解析（史上最深 、价值 逆天）|Harness 顶级架构：DeerFlow 2.0 沙盒 Sandbox 架构设计]]
> 45岁老架构师 · 2026-05-10

从面试场景切入，系统拆解了 DeerFlow 2.0 的 Harness 架构。核心亮点是 14 层 Middleware 洋葱责任链模式，以及基于 PPAF 思维和 REPL 思维的 Lead-Agent 与 Sub-Agent 配合机制。对断点续跑、三级记忆架构、沙盒安全隔离等生产级需求都有工程化实现。

### [[5张图看懂OpenClaw的Harness设计|5张图看懂OpenClaw的Harness设计]]
> FloraCat · 2026-05-10

OpenClaw 是 Gateway-First 的 Harness 架构，上接多渠道入口，下连会话路由、插件扩展、记忆系统和运行时。Harness 层负责组装 prompt、挂载 tools、接入 skills 和 memory、处理策略与安全限制，再通过 Provider Adapter 与不同厂商 LLM 交互。这让 OpenClaw 不是"直接把文本丢给模型"，而是具备可扩展、可控制、可落地的 Agent 运行能力。

### [[硬核拆解 OpenClaw：如何构建真正稳健的生产级 Agent 系统？【上】|硬核拆解 OpenClaw：如何构建真正稳健的生产级 Agent 系统？]]
>  · 2026-05-10

（文章正文未在扫描中完整呈现，主题聚焦于 OpenClaw 生产级 Agent 系统的稳健性设计。）

### [[你不知道的 Agent：原理、架构与工程实践|你不知道的 Agent：原理、架构与工程实践]]
> 侑夕 · 2026-05-10

从阿里内部实践出发，对比了更贵模型 vs Harness/测试质量对成功率的影响——后者往往更大。提出调试 Agent 应优先检查工具定义，因为多数工具选择错误出在描述不准确。五种控制模式的组合足以覆盖大多数 AI 系统，无需盲目追求完整 Agent 自主权。

### [[Agent从一问一答到自主执行面临哪些挑战|Agent从一问一答到自主执行面临哪些挑战？]]
> 阿里云开发者 · 2026-05-13

指出定时调度是 Agent 走向自主运行的最主要触发形态，主流商业产品均将其放在付费档位。开源 Agent 定时任务的五大痛点（无高可用、运维成本高、权限管理弱、可观测弱、资源利用率低）的解法是把调度层从 Agent 内抽离，由平台统一管理。会话管理三模式中，"任务隔离"是推荐默认。

### [[Anthropic长文：多智能体协作模式，五种方法及其适用场景|Anthropic长文：多智能体协作模式，五种方法及其适用场景]]
>  · 2026-05-10

（文章正文在剪藏中主要为 UI 元素，核心内容未完整提取。主题为 Anthropic 对多智能体协作五种方法的系统性论述。）

### [[Agent大战，赢家暗自在哪下功夫|Agent大战，赢家暗自在哪下功夫？]]
> 亲爱的数据 · 2026-05-21

（小红书图片型笔记，共 14 张图片，正文无额外可提取文本。主题为 Agent 市场竞争格局与赢家关键要素分析。）

### [[Harness其实就是控制论，别被FOMO吓到了|Harness其实就是控制论，别被FOMO吓到了]]
> 碳基智 · 2026-05-21

用控制论（Cybernetics）的框架重新诠释了 Harness Engineering。Norbert Wiener 和 William Ross Ashby 提出的控制论核心命题——"如何驾驭一个你无法完全理解其内部工作原理的复杂系统"——恰好解释了为什么 Harness 在 2026 年成为 Agent 工程的核心范式。大模型是最纯粹的黑箱，Harness 的每个组件都有控制论对应物：System Prompt 是方向盘（行为边界），Eval 是仪表盘（偏差测量），RAG/Context Window 是控制带宽，Retry/Fallback/人工审批是纠偏执行器。整体构成教科书般的负反馈控制回路。

### [[Agent核心技术概念与范式发生了哪些演变以及背后的思考|Agent核心技术概念与范式发生了哪些演变以及背后的思考]]
> 飞樰 · 2026-05-22

系统梳理了 2023~2026 年 Agent 从"被动式 ReAct"→"工作流 Agent"→"自主 Agent"→"自进化 Agent" 的四阶段演化，以及 Prompt、Planning、Memory、Tools、Workflow、Environment 六个核心概念的范式转移。最有价值的判断：Memory 正从"向量数据库主导"向"文件系统主导"回归（事项型记忆用 Markdown 日志，知识型记忆用本地文件系统 + Obsidian + 轻量化向量检索混合）；Tools 从 Function Call 走向 CLI/Script 原生利用，核心是从"人为适配模型"转向"利用模型原生能力"；Workflow 从刚性编排走向"Skill 为主、Workflow 为辅/兜底"的混合架构。核心思想始终是"通过工程化手段构建确定性，以承载模型不确定性"。

### [[重磅 |完备的 AI Agent 学习路线，最详细的资源整理！|重磅 | 完备的 AI Agent 学习路线，最详细的资源整理！]]
> 陈思州 / Datawhale · 2026-05-22

Datawhale 整理的系统性 Agent 学习路线图，从最小 Agent Loop、工具调用、RAG、Memory，到现代 Agent Harness（Claude Code / OpenClaw / Hermes）、Skills、MCP、A2A、评测、trace 和安全，分五个 Part 覆盖入门→进阶→工程化→项目实践→精选资源。附带开源仓库 Agent-Learning-Hub，收录了 learn-claude-code、claw0、hello-agents、OpenClaw、Hermes、DeerFlow、smolagents 等值得读源码/跟做的项目。适合作为 Agent 领域的"学习地图"按图索骥。

## 延伸阅读

- [[Claude Code工程]]
- [[Agent记忆系统]]
- [[知识图谱应用]]
