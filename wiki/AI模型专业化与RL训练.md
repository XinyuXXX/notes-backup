---
title: AI模型专业化与RL训练
tags: [知识库, AI模型专业化与RL训练]
updated: 2026-05-27
---

## 主题概要

2026 年，应用公司正从"用现成模型 + 提示词工程"走向"自训专用模型"。核心逻辑是：模型权重容量有限，把所有 bits 分配给单一任务，既能超越 Prompt 工程的天花板，又能大幅降低推理成本。Cursor 训练 Composer 2 的案例是这条路线最完整的公开记录：自顶向下路径（先 RL + mid-training，不从预训练起步）、全球分布式异步 RL、weight delta 跨 WAN 同步、MoE router replay 对齐、self-summarization 纳入 RL 循环。

## 核心概念

- **模型专用化（Model Specialization）**：把模型权重有限的"存储容量"全部分配给应用所需的一个任务，结果是既更精准又更便宜。每个有足够用户数据的应用公司最终都值得走这条路。Prompt 工程有硬上限；只有 fine-tuning + RL 才能突破。
- **自顶向下训练路径**：不从预训练起步，而是先用开源 base → 大规模 RL（快速获得可用模型）→ 再做 mid-training。对应下游目标倒推，快速交付用户价值。
- **三段式训练**：(1) **Base model**（开源，如 Kimi 2.5，1T MoE 30B active）→ (2) **Mid-training**（近乎预训练规模的代码 token，学代码知识和分布）→ (3) **RL on harness**（学工具调用、正确性、harness 行为）。Mid-training 教"如何写代码"，RL 教"写正确代码"。
- **Async / Pipeline RL**：Trainer 与 rollout 永远并行运转，互不等待。相比同步 RL（trainer 等 rollout、rollout 等 trainer），资源利用率翻倍，代价是引入 staleness（rollout 完成时模型权重已更新）。off-policy 算法（GRPO 等）可吸收这种 staleness。
- **全球分布式 RL**：Training cluster 集中（需要高速网络互联），Inference cluster 分布在全球小集群甚至生产 GPU 低峰时段复用。关键：inference 对互连要求低，可跨代、跨型号、跨地域混用。
- **Weight Delta 压缩**：RL 每步只改变部分权重，delta 通常比全量模型小 20 倍。Lossless 压缩 + 分片并行上传，跨 WAN 同步可在 <1 分钟完成，inference server 换权只需暂停 ~30 秒。
- **MoE 数值不匹配（Numerical Mismatch）**：浮点加法不满足交换律，同一模型在 inference 与 training 端重跑 forward pass 得到不同 log probabilities。对 MoE 尤其严重：router 处微小数值差异会导致选择不同 expert，大幅放大偏差。解法：**Router Replay**（inference 把激活的 expert index 附带传给 trainer）+ batch-invariant GPU kernels（统一加法顺序）。
- **Self-Summarization（自摘要）**：把 context compaction 纳入 RL 训练循环。模型在 RL 中联合学习"产生高质量摘要"和"根据摘要继续完成任务"，使有限 context window 的模型实际上可运行几百万 token。关键：harness 行为与模型能力端到端联合优化。
- **实时 RL（Real-time RL）**：采集生产流量中的用户满意/不满意信号，每几小时更新模型并持续上线。与离线模拟 RL 互补：离线 RL 用来"从零建立能力"，实时 RL 用来"持续精炼生产中的模型"。实时 RL 的悖论：模型必须先足够好才能从用户处获得有效反馈。
- **RL 的本质作用**：不只是"让模型学会做任务"，更是"告诉模型你是专家，要把事做对"（sharpening the distribution）。预训练模型面对问题时不知道自己该是"学生"还是"专家"；RL 把这个 knob 调到"专家"。适用于任何有可描述评判标准的任务，不限于 coding。
- **LLM-as-Judge**：生成比判别更难，LLM 更擅长判别。可以通过精确描述 rubric（风格、事实性、多维度）驱动 RL 奖励，无需手动标注，可扩展。最可靠的是可验证奖励（代码能不能编译/运行），LLM-as-judge 是次优补充。
- **应用层 RL 环境三件套**：(1) **Harness**（工具调用层，可移植）；(2) **Operating System**（模型所在的真实环境状态，关键！普通容器不够，需 VM 栈或接近生产的隔离环境）；(3) **Reward 组件**（验证结果正确性）。最强大的 RL 环境就是你自己的生产产品。

## 文章洞见

### [[Cursor如何训练Composer2：分布式RL与专用模型|Cursor如何训练 Composer 2：分布式 RL 与专用模型]]
> Sequoia Capital（Federico Cassano / Cursor + Dmytro Dzhulgakov / Fireworks AI）· 2026-05-27

Cursor 训练 Composer 2 的完整工程实录。核心判断：应用公司有足够用户数据后，自训专用模型是必然路径，上限远高于 Prompt 工程。工程亮点：(1) 自顶向下路径，快速交付用户价值；(2) 全球 4 个集群分布式异步 RL，通过 weight delta 压缩解决 WAN 同步延迟；(3) MoE router replay 消除 training/inference 数值偏差；(4) self-summarization 纳入 RL 循环实现有效无限上下文；(5) 实时 RL 每几小时更新生产模型。"模型知道自己在假环境里会开始作弊——RL 非常擅长鼓励作弊。"

## 延伸阅读

- [[Agent架构与设计]]
- [[AI编程工作流]]
- [[Claude Code工程]]
