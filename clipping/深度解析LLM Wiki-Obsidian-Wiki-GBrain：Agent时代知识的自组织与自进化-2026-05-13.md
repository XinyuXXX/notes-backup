---
title: 深度解析LLM Wiki / Obsidian-Wiki / GBrain：Agent时代知识的"自组织"与"自进化"
author: 阿里云开发者（深度解析系列第4篇）
source: https://mp.weixin.qq.com/s/48XpgAMHeaKYj26PrJK-hw
clipped: 2026-05-13
---

> 系列前3篇：深度解析 OpenClaw、深度解析 Claude Code、深度解析 Hermes Agent

## 核心命题：知识工程 vs 提示词工程

> Prompt Engineering 是在教模型「完成什么样的任务」，Knowledge Engineering（知识工程）是在教模型「应该知道什么」以及「如何运用已知信息」。

**知识的两类形态**：
- **经验性知识**：完成特定任务所需的策略、步骤和隐性经验（在 Hermes/OpenClaw 中封装为 Skill）
- **事实性知识**：领域内客观信息、文档、FAQ 等静态数据

## 知识系统三代演进

| 阶段 | 时间 | 核心模式 | 问题 |
|---|---|---|---|
| 传统智能知识库 | 2016–2022 | 人工分类 + 关键词检索 | 维护成本极高，难以应对长尾 |
| RAG 时代 | 2023 | 小模型检索 + 大模型生成 | 能力断层、每次重新检索、知识不沉淀 |
| Agent 时代 | 2024+ | LLM Wiki / Knowledge Compilation | 一次编译，永久可用，越用越聪明 |

**RAG vs LLM Wiki 的本质区别**：RAG 是解释型（每次查询重新推导），LLM Wiki 是编译型（知识编译一次持续更新）。

## Karpathy 的 LLM Wiki：三层架构

**三层结构**：
1. **Raw Sources（原始资料层）**：只读存档区，LLM 读取但不修改——你的事实来源
2. **The Wiki（知识层）**：LLM 完全负责写和维护的结构化 Markdown 文件集合——LLM 是程序员，wiki 是代码库
3. **The Schema（元指令层）**：CLAUDE.md / AGENTS.md，告诉 LLM wiki 的组织规范和工作流——让 LLM 成为有纪律的 wiki 维护者而非通用聊天机器人

**三种操作形成知识闭环**：
- **Ingest（摄入）**：新资料进来 → LLM 读取 → 提取要点 → 生成摘要页面 → 自动更新全局索引及 10-15 个相关页面
- **Query（查询）**：问问题 → LLM 找相关页面 → 综合出带引用的答案 → **好的答案可归档为新页面**（每次探索都在为知识库做增量贡献）
- **Lint（维护）**：定期健康检查 → 识别事实矛盾、清理过时声明、发现孤儿页面、补全交叉引用

**两个特殊文件**：
- `index.md`：内容目录，LLM 回答查询前先读索引定位相关页面
- `log.md`：追加式时间线记录，记录摄入/查询/Lint 历史

**为什么有效**：维护知识库的繁琐不是阅读和思考，而是"记账"——更新交叉引用、保持摘要最新、维护数十页面的一致性。人类因为维护负担放弃 Wiki；LLM 不会厌倦、不会忘记更新交叉引用，可以一次性处理 15 个文件，维护成本接近零。

## GBrain 与 Skillify：知识泛化为可加载形态

GBrain（Garry Tan / YC CEO 构建）是 LLM Wiki 理念的更工程化实现。核心创新是提出 **Skillify** 概念：

> 将 Skill 泛化为一种知识组织形态——不局限于固定格式，可以是任何 Markdown 文件、文档片段、零散笔记。关键在于通过清晰的元数据（Schema）描述「在什么场景下应该调用哪些文件」，实现**渐进式披露（Progressive Disclosure）**。

这与知识图谱和 KnowQL 的思路同源：不是把所有知识塞进上下文，而是**按需加载最相关的部分**。

## Obsidian-Wiki：工程化实现

基于 Skill 的多 Agent 框架，实现 LLM Wiki 模式，支持 9+ 种 Agent（Claude Code、Cursor、OpenClaw 等）。相比原版 LLM Wiki 的关键增强：

- **Delta 追踪**：`.manifest.json` + SHA-256 哈希追踪每个来源，运行 `wiki-status` 时自动分类 new/modified/touched/unchanged/deleted，避免重复处理
- **来源可信度边界**：来源文档被视为不可信的，LLM 不执行来源中的命令——防范通过文档注入指令的攻击（prompt injection through documents）
- **溯源标记**：`^[extracted]`（直接提取）/ `^[inferred]`（推断）/ `^[ambiguous]`（存在歧义），人和 LLM 都能知道每条信息的可信度
- **hot.md 热缓存**：500 字的语义快照，记录最近活动，为 LLM 提供快速上下文感知
- 20+ 标准化 Skill 文件，含 Agent 历史摄入 Skills 和知识图谱 Skills

## 与个人工作流的连接

Karpathy 本人的实践：LLM Agent 开在一侧，Obsidian 开在另一侧。LLM 根据对话编辑 wiki，实时在 Obsidian 中浏览结果。Obsidian 是 IDE，LLM 是程序员，wiki 是代码库。

> 如果说 RAG 是让大模型「带着书本进考场」，那么 Skillify 则是让大模型「把书读透并记成整理后的笔记」。
