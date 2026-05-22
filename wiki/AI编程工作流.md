---
title: AI编程工作流
tags: [知识库, AI编程工作流]
updated: 2026-05-16
---

## 主题概要

AI 编程工具在 2026 年正从"Vibe Coding"（直接聊天写代码）走向"Spec-Driven"（先写结构化规范再让 AI 编码）。核心矛盾是：AI 代理缺乏结构化的工作流约束，导致代码风格飘忽、协作理解不一致、测试被跳过。Spec-Kit、OpenSpec、Superpowers 三款工具代表了三种不同哲学：规范可执行化、轻量规范层、技能驱动工作流。而渐进式 Spec 实战则揭示了如何在真实项目中落地这套方法论。

## 核心概念

- **Spec-Driven Development**：规范不只是"指导文档"，而是可执行的——能直接生成工作代码。翻转了传统软件开发中"规范与实现分离"的脚本。
- **本质复杂度 vs 偶然复杂度**：软件复杂度 = 业务逻辑本身（不可消除）+ 工具/流程引入的负担（可以且应该被消除）。AI Coding 工具的好坏标准：多高效地应对本质复杂度，同时自身引入的偶然复杂度有多低。
- **渐进式编码框架**：在让 AI 写代码之前，先用结构化文档（Spec）把"要做什么、怎么做、有什么约束"说清楚，然后 AI 围绕文档编码。解决 Vibe Coding 的四大工程问题。
- **三工具差异**：Spec-Kit（GitHub 官方，七阶段工厂流水线，规范可执行化）、OpenSpec（轻量规范层，fluid/iterative/easy，无需 API Key）、Superpowers（技能组合驱动，115K Star，test-driven-development 等技能可插拔）。

## 文章洞见

### [[2026 年 AI 编码的“渐进式 Spec”实战指南|2026 年 AI 编码的"渐进式 Spec"实战指南]]
> 逸驹 · 2026-05-10

从阿里内部项目实践出发，提出"模型是地基，方法论是上层建筑"的认知框架。T0 模型一次做对 vs T2 模型 15 轮还不一定对的差距，不在"能不能写"，而在一次做对的概率。渐进式 Spec 的核心是把"要做什么、怎么做、有什么约束"先写成结构化文档，再让 AI 围绕文档编码——既压缩了偶然复杂度，又保留了人的审查节点。

### [[AI 编程工作流选型：Spec-Kit、OpenSpec、Superpowers 深度对比|AI 编程工作流选型：Spec-Kit、OpenSpec、Superpowers 深度对比]]
> 运维有术 · 2026-05-10

三款工具底层哲学完全不同：Spec-Kit 像工厂流水线（七阶段严格输入输出），OpenSpec 像轻量协作文档（propose/apply/archive 活文档），Superpowers 像乐高积木（test-driven-development、systematic-debugging 等技能可组合）。选错就是工具束缚人——流程固定的团队适合 Spec-Kit，探索性强的团队适合 OpenSpec，已有测试文化的团队适合 Superpowers。

## 延伸阅读

- [[Claude Code工程]]
- [[Agent架构与设计]]
