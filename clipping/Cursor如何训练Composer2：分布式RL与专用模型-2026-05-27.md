---
title: "How Cursor Trained Composer on Fireworks: Distributed Infrastructure for High-Performance RL"
source: https://sequoiacap.com/podcast/how-cursor-trained-composer-on-fireworks-distributed-infrastructure-for-high-performance-rl/
author: Sequoia Capital（主持：Sonya Huang；嘉宾：Federico Cassano / Cursor、Dmytro Dzhulgakov / Fireworks AI）
date: 2026-05-27
tags: [Cursor, Composer, RL训练, 分布式推理, 专用模型, Fireworks, MoE]
---

> **摘要**：Cursor 研究负责人 Federico Cassano 与 Fireworks AI 的 Dmytro Dzhulgakov 详述了 Composer 2 的训练过程。核心洞见：模型权重容量有限，把所有 bits 专注于一个任务，既更强又更便宜。他们采用自顶向下路径（先 RL 再 mid-training），依托 Fireworks 构建全球分布式 RL 基础设施，实现了 weight delta 压缩跨集群同步、MoE router replay 对齐，以及把 context compaction 纳入 RL 循环的 self-summarization 能力。

---

**Sonya Huang:** I'm delighted to welcome Federico from Cursor and Dima from Fireworks to the podcast today. Federico, you are the research lead on Composer 2 at Cursor—Cursor's new agentic coding model. And Dima, you spent several of the last few months moonlighting at Cursor in order to support a lot of the infrastructure required to make this gargantuan training task happen.

---

## 为什么 Cursor 要自己训模型

**Federico Cassano:** The reason why we started looking into training our own models is you can sort of think about the model as sort of like a storage drive. It has a certain amount of bits that it can store in its weights.

We care about only one task. We don't even care about coding or programming necessarily. We care about software engineering inside Cursor and inside Cursor only. And so what if we were to allocate all of the bits of information that can be stored inside the model weights to that one particular task?

Also, Composer is an order of magnitude less expensive than Opus and other coding models because we can simply specialize all of the model weights to that particular task.

**Dmytro Dzhulgakov:** The most leveraged attribute of your application is actual usage of user data or particular specific aspects of how the application works. The right way to capture that: you can do a little bit of that through prompting, but really the right way to do this is craft your model to act in your environment.

There's kind of an upper bound of how far you can get with prompt engineering. And if you want to craft really great AI products, you have to go through fine-tuning and influencing model behavior. When you start getting into model training, you can really push the quality/speed/cost trade-off much further.

---

## 关于"Bitter Lesson"的回应

**Federico Cassano:** If we believe in the bitter lesson, we are just pushing very hard on the data dimension and we know that the models inherently have finite capacity. And so if we want to saturate all that capacity, we need to scale data. And in order to ingest more data, we need to free up the weights from distractions the model may have.

---

## Composer 2 训练方案

**Federico Cassano:** We started from Kimi 2.5. That's a one trillion parameter MoE that's 30B active—so very sparse. Composer 2 pushes in two different axes: continual pre-training (mid-training) and reinforcement learning.

We started off by doing lots of **mid-training** on code tokens—almost pre-training scale. Then coming out of that mid-training run, we did very large-scale **RL** on lots and lots of tasks.

**In mid-training**: learning about code libraries, specific code patterns, world knowledge. Creating a wider distribution that RL can then sharpen on.

**In RL**: the model gets to play directly with the Cursor harness—it learns how to call tools properly, navigate its environment, write *correct* code. Mid-training teaches how to write code; RL teaches how to write *correct* code.

### 自顶向下路径（Top-down approach）

How do we get a model that's useful to users in the least time possible? If we were to start from the bottom (pre-training → mid-training → RL), that would take very long. By doing it top-down, we gave users a useful model quickly. Hopefully next Composer versions will be trained on our own pre-trained model.

---

## RL 基础设施难题

**Dmytro Dzhulgakov:** When you do RL, you're not just predicting the next token. You're running the entire harness, letting the model act in the environment, see how it performs for a given **rollout**, and assign reward.

A rollout = entire agent session from Cursor. ~50 turns. The model takes your initial prompt, calls tools, generates code—simulate the entire session as part of training. Get final reward, use signal to update weights.

### Async / Pipeline RL

Naive approach: stop trainer → do rollouts (5–10+ min each) → pause inference → update. Very system-inefficient: half capacity idle.

**Pipeline approach**: trainer and rollouts buildings always churning. Rollouts always take latest model and simulate new sessions. Trainer always takes new outcomes as they come.

Trade-off: **staleness**—by the time a rollout finishes, model weights may have been updated. But the flip side is all GPUs are loaded and churning all the time. You lose a few percent from asynchrony but more than compensate by not leaving half capacity idle.

---

## 全球分布式 RL

**Federico Cassano:** Very large contiguous clusters are hard to find. Instead: one cluster for training + globally distribute inference across small clusters all over the world. For Composer 2: four clusters total, all over the world. We even used production inference GPUs during off-peak hours (Composer 1.5 serving production; low-use periods → repurposed for RL inference).

**Dmytro Dzhulgakov:** By disaggregating components, you don't need to find such a big cluster. For inference you don't need wide interconnect—can use smaller GPU groups, heterogeneous GPU types, different generations. Inference is easy to scale up/down and share between production traffic and simulated RL environments.

### Weight Delta 压缩

The model (Kimi 2.5) is one terabyte. A training step takes 5–15 minutes. How to ship new weights to clusters around the world quickly?

**Key insight**: Not all weights change every step. RL does very precise adjustments, especially as training progresses. So there are regular patterns in which subset of weights changes. Delta between steps might be ~20x smaller than shipping the full model.

Build a compression algorithm leveraging this → lossless (bit-equivalent model on the other side), ships in under a minute, inference server pauses only ~30 seconds to swap weights.

Also: fully saturate cluster egress by sharding the upload and download.

---

## MoE 数值不匹配问题

**Federico Cassano:** In async RL, when we ship generations back to the trainer, we have to rerun the forward pass to reproduce log probabilities. Even with the same model version, you get slightly or sometimes very different log probability values for the same tokens—"numerical mismatch."

**Dmytro Dzhulgakov:** Floating point arithmetic is non-deterministic. A+B+C ≠ C+B+A in floating point. These tiny differences get amplified through millions of operations. For regular inference it doesn't matter. But RL uses a very weak signal—the noise from numerical differences can make or break training.

**For MoEs specifically**: the gating layer (router) picks top-8 experts out of 384. Tiny numerical differences can flip which expert gets selected (expert 7 vs expert 9 at cutoff). Suddenly you activated a totally different part of the model, and in training you're updating the wrong expert.

**Solution: Router Replay**—inference passes extra info to trainer: "I activated expert 7 for this token." Trainer uses that to align. Combined with batch-invariant GPU kernels (careful about addition order), you can drive divergence close to zero. Trade-off: maybe 2–3x slower for certain kernels, but worth it.

---

## RL 环境与 Harness

**Federico Cassano:** RL environments = three components:
1. **Harness**: where the model submits tools and tools get executed (relatively portable)
2. **Operating system**: the actual world/state the model interacts with (the key part; normal containers don't work well)
3. **Reward component**: checks that work is done correctly

Cursor built a full virtual machine stack—can spin up VMs very quickly and very burstily (100,000 VMs on demand).

**Models can detect fake environments**: "Oh, I'm in a fake environment? I will learn a few tricks to get a better reward in this environment." → **Models love to cheat. RL is really good at encouraging cheating.**

Solution: make environments mirror production as closely as possible.

---

## Self-Summarization（自摘要）：无限上下文

**Federico Cassano:** Composer has a 200,000 context window model, but in reality it can go on for millions of tokens because of **self-summarization**.

We put **compaction inside the RL loop**. During RL, the agent actually learns how to continue and go on forever. It can summarize its work and restart its context window while still accomplishing the task.

Through RL—because RL pushes the model toward the goal—we jointly train the model to: (1) produce a good summary, and (2) listen to that summary well. Both optimized end-to-end.

**Dmytro:** Usually context management is considered part of the harness. Here you're **co-optimizing model + harness together** and throwing all of it into the optimization loop. The more you throw compute at the problem, the more you can solve end-to-end.

---

## 实时 RL（Real-time RL）

**Federico Cassano:** We find user signals where the user was happy or sad about a particular model generation, and we update the model live, then ship a new version continuously every few hours. We're working on decreasing that time.

The paradox of real-time RL: you can't use this to create the model from scratch, because users need to be using the model and it has to be good already. You can only make it better. Offline simulated RL is how you bootstrap to "good enough."

---

## RL 的更广泛适用性

**Federico Cassano:** RL fits everywhere. For Tab (autocomplete), we also use RL. When you pre-train a model, it ingests all of human knowledge and doesn't know "what kind of person it is"—expert or student. One thing that happens during RL is we're tuning this knob, letting the model know: **"You are the expert, you need to do things correctly."**

**Dmytro:** Continual pre-training / mid-training / SFT = transfer of new knowledge in abstract form. RL = sharpening behavior or particular qualities. You usually need both.

Even for summarization: RL very useful—LLM-as-judge lets you state precise rubrics you want; model experiments with different styles; another LLM evaluates whether it matches your rubric.

---

## RL 回报信号

**Dmytro:** The more verifiable your reward, the better—allows you to scale compute and get a better outcome. If it's math or coding and you can craft something deterministic, that's the best.

LLM-as-judge works because judging is easier than creating (generator-discriminator). Break down complex evals into multiple rubrics (style, factuality, etc.)—some verifiable, some LLM-based. That guides model behavior. Turn on more compute → see the graph go up.

**Experts are still needed**: crafting the task definition and encoding the product experience you want—that's what matters. Craft the evaluation rules, look at examples, look at where your product fails, nudge the model in the right direction.

---

## 对应用公司的启示

**Federico Cassano:** If they are using AI and they're producing lots of tokens and they have a product to optimize against, I think it's the right move to train models.

**Dmytro:** The most powerful environment is your own product. If you're trying to build the best model for your product, specialize and tailor it, use your production environment (properly isolated).

General pattern: start prototyping with off-the-shelf model → prompt engineering → fine-tuning → RL on your own harness. Most leveraged attribute = actual usage data from your product.
