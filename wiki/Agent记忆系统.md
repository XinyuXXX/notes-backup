---
title: Agent记忆系统
tags: [知识库, Agent记忆系统]
updated: 2026-05-28
---

## 主题概要

Agent 的记忆不是"有没有"的问题，而是"把什么东西当成长期资产、放在运行时哪一层"的工程问题。2026 年的趋势表明：提示词工程是语法，上下文工程是基础设施；RAG 的 retrieve-read-retrieve 循环正在让位于 Knowledge Compilation；而搜索本质正在演变为 Agent Memory。从 Hermes 的三层学习机制到 Pinecone 的 KnowQL，记忆系统正从简单的向量检索进化为带结构、可演进的知识基础设施。

## 核心概念

- **上下文三层结构**：即时上下文（提示词本身）、会话上下文（文件/历史/系统指令）、持久上下文（跨会话的记忆/知识库/偏好）。最大的杠杆在第三层，几乎没有人真正用好。
- **三层记忆**：事实记忆（用户偏好、环境约定）、会话检索（历史对话、踩过的坑）、过程记忆（同类任务该怎么做——Skill）。Hermes 把这三层显式分开。
- **Knowledge Compilation**：把"推理"提前，将源数据预编译成带类型、可引用、面向任务的知识产物（artifacts）。Agent 查询的不再是原始语料库，而是编译后的产物。
- **幻觉全链路约束**：Prompt 约束（管边界）、工具调用约束（防止乱行动）、证据约束（有据可依）、输出校验（生成完不是结束）。Agent 幻觉不是一句 Prompt 能兜住的。
- **Query 构造即一切**：即使记忆系统链路全对，只要 Query 构造错了（如 multilingual query 转译偏差），整个检索就是废的。
- **CoALA 4 种记忆类型**（普林斯顿框架）：工作记忆（上下文窗口，易失）、语义记忆（CLAUDE.md 等知识库文件，跨会话）、程序性记忆（Skills/skill.md，怎么做事）、情景记忆（跨会话经验提炼，最难）。不是每个 Agent 都需要全部 4 种：客服 Agent 只需 2 种，编程 Agent 需要全部。"遗忘是一个工程难题"。
- **Memory Store（记忆存储）**：Anthropic 推出的跨会话持久化方案。将文件系统挂载到会话容器，模型可 read/write，用 grep 搜索关键词。可为每个用户/工作区独立创建，边界自定义。文件系统接口远比向量库直接——这是当前生产级情景记忆的主流形态（见 Hermes、Claude Code）。
- **Dream（梦境）**：Anthropic 的异步记忆整理功能。后台批处理，输入 Memory Store + 历史 Transcripts，运行多 Agent Harness（子 Agent 各自检查，Orchestrator 编排），输出克隆版 Memory Store 的 Diff（非破坏性）。缓存命中率 ~95%，实际成本远低于预期。核心价值：防止记忆库无限膨胀、去重、补全过时信息。

## 文章洞见

### [[别再死磕提示词了，真正拉开差距的是上下文工程|别再死磕提示词了，真正拉开差距的是上下文工程]]
> Khairallah AL-Awady · 2026-05-12

提示词工程是 2024 年的技能，上下文工程是 2026 年及之后的技能。上下文工程包含模型能读取的文件、会话记忆、工具、规则、示例。提出"四个核心文件"：身份文件、受众文件、标准文件、项目文件，每个控制在 2000 词以内。动态上下文加载按任务类型匹配文件，避免把整个知识库塞进每次对话。

### [[2026 年做搜索就是做 Agent Memory|2026 年做搜索就是做 Agent Memory]]
> Jina AI · 2026-05-10

搜索技术从 BM25 → 向量搜索 → 混合搜索 → RAG → Deep Research → Agent Memory 的演进脉络中，核心不变的是"检索底座"。Agent Memory 的痛点不是技术链路不全，而是 Query 构造错误导致检索失败。Jina AI 沉淀的三件套（Embedding、Reranker、Reader）正成为 Agent Memory 的基础设施。

### [[我反问面试官：“如何避免Agent系统中大模型的幻觉？”，面试官：“我会写提示词，让他不要瞎编”，我笑了：“你面其他人吧，我撤了”|我反问面试官：如何避免Agent系统中大模型的幻觉？]]
> 程序员Carl · 2026-05-16

Agent 幻觉分三类：知识幻觉（编造事实）、工具幻觉（调用不存在工具）、参数幻觉（瞎填参数）。工程解法要从输入、工具、证据、输出、兜底全链路约束，不能指望一层防线解决所有问题。约束之后仍幻觉，需要监控-告警-人工复核-归因分析-更新约束的闭环治理。

### [[拆解 Hermes Agent 的三层学习机制：OpenClaw 加自总结 Skills 后，差异还剩什么？|拆解 Hermes Agent 的三层学习机制]]
> 架构师 · 2026-05-10

Hermes 把长期资产分成事实记忆（`MEMORY.md` / `USER.md` frozen snapshot）、会话检索（SQLite + FTS5 档案室）、过程记忆（`skill_manage` 允许后续 patch/edit/delete）。最值得拆的是 skill_manage——它把"这类任务以后怎么做"写成 skill，属于 procedural memory。如果 OpenClaw 也把这个做成系统主路径，差异就从"有没有"变成"这件事被放在运行时的什么位置"。

### [[把 RAG 做成主流的公司，现在开始"做空"RAG 了|把 RAG 做成主流的公司，现在开始"做空"RAG 了]]
> InfoQ · 2026-05-12

Pinecone 发布 Nexus 知识引擎，宣告 RAG 时代结束。核心判断：retrieve-read-retrieve 循环的任务完成率只有 50%–60%，Agent 85% 精力耗在"找上下文"。新范式 Knowledge Compilation 提前把源数据编译成 artifacts，配合 KnowQL（Agent 知识检索的"SQL"），声称任务完成率提升到 90% 以上，token 开销降低 90%。

### [[Agent记忆4种类型与Anthropic的记忆存储和梦境功能|Agent 记忆 4 种类型与 Anthropic 的记忆存储和梦境功能]]
> 玉澄 / 51CTO 技术栈（整合自 IBM Martin Keen + Anthropic Kevin Chen）· 2026-05-28

整合了两个视频演讲的精华。IBM 的 Martin Keen 用 CoALA 框架梳理 4 种记忆类型，最核心洞见是：情景记忆（跨会话经验提炼）是 Agent 和聊天 Bot 的本质分野，也是工程难度最高的部分，难点不在"记什么"而在"忘什么"。Anthropic 工程师 Kevin Chen 演示了 Memory Store（文件系统挂载，grep 搜索，跨会话读写）和 Dream（异步多 Agent Harness，克隆→检查→Diff 输出，95% 缓存命中率，成本极低）。两个功能合起来形成三层架构：会话 → Memory Store → Dream 定期整理，记忆库保持可管理规模。

### [[拆解 Hermes Agent 的记忆系统：一个生产级 AI 记忆是怎么设计的|拆解 Hermes Agent 的记忆系统]]
> VibeCoder · 2026-05-18

Hermes 的记忆是完整工程方案而非简单持久化。三层架构：Layer 1（`MEMORY.md` + `USER.md`，2200/1375 字符上限，始终注入系统提示）、Layer 2（八个可插拔外部后端，同时只激活一个）、Layer 3（SQLite + FTS5 历史回溯）。最精妙的是**冻结快照模式**——会话开始时拍快照注入系统提示，中途写入不修改 prompt，以牺牲本次会话内记忆可见性为代价，换取 prefix cache 稳定和 API 成本可控。单 Provider 约束防止工具 schema 膨胀；`<memory-context>` 上下文围栏防御 prompt injection 攻击。

## 延伸阅读

- [[Agent架构与设计]]
- [[知识图谱应用]]
- [[AI编程工作流]]
