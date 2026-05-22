---
title: 我用 Claude Code CLI 搭了一套「不丢上下文」的工作流
author: 卢灿伟同学
source: https://mp.weixin.qq.com/s/I7aZM-aWYtnEPktZ4mZtGg
clipped: 2026-05-10
---

卢灿伟同学 卢灿伟同学

在小说阅读器读本章

去阅读

用 Claude Code CLI 半年了，聊聊我踩过的坑和最后跑通的工作流。

跨项目共享记忆

context 一压缩，之前聊的全没了

这是 CLI 最大的痛点。你花 2 小时跟它对齐了架构决策、讨论了三种方案选了一个、确认了一堆约束条件——compact 之后，它全忘了。下次开 session 更惨，完全从零开始。

我试过在 CLAUDE.md 里写很长的项目说明，但 CLAUDE.md 解决的是「项目是什么」，解决不了「我们上次聊到哪了」和「之前做了什么决策」。

多项目上下文来回切

同时跑多个项目的人应该都有这个感受：每个项目一个 CLI session，互相看不到。在 A 项目讨论完一个架构方案，切到 B 项目想引用刚才的思路，得手动复制粘贴上下文。项目一多，你就变成了 AI 之间的人肉信息搬运工——没有一个统一的地方能看到所有项目的进展、做跨项目的决策。

用 Claude Code 开一个「指挥室」

我的做法是用 Claude Code 单独开一个文件夹（项目），里面不写任何代码，专门用来管所有项目的节奏——产品决策、需求文档、进度追踪。技术实现留在各自的 repo 里，指挥室只管「做什么」和「为什么」。

为什么要这样做？因为 Claude Code 的能力——读文件、搜索、调工具、记忆——在管理和决策场景下同样好用。你不需要另外开一个 Notion 或者飞书来做项目管理，CLI 本身就能承担这个角色，而且它能直接读你所有项目的代码和文档，这是任何外部工具做不到的。

跨项目感知靠一个 JSON 注册表（所有项目的名称和路径）。在指挥室打 \`/recap\`，AI 自动遍历所有项目的进度文件和工作日志，给出全局视图。在具体项目里打 \`/recap\` 只看当前项目——一开始没分这个场景，结果在 A 项目里打 recap 它告诉我 B 项目的进展，完全是噪音。

任务管理挂 Linear（换成你习惯的任务工具都行）。CLI 里直接查状态、改状态，checkpoint 的时候自动同步。Linear 管「做什么」，指挥室的文档管「为什么做、之前聊了什么」，两者配合。

工作流系统

第一版工作流：start-working + end-working

这个方案从另外一个推油分享的经验里学习的，根据我想要的需求让claude code生成的命令。

——开工时跑一遍环境检查（git 状态、进度文件、最近 commit），收工时跑一遍同步（更新文档、检查测试覆盖、写日志、提交代码）。听起来很完整。

实际跑了一周就废了，发现这种模式并不太适合我。核心问题是这套设计假设你的工作方式是「打卡制」——有明确的开始和结束。

但我的实际情况是：窗口一直开着，第二天接着干；凌晨想到个问题打开就写，写完就睡。start-working 要求我在开始时一次性读取所有状态，end-working 要求我在结束时一次性写入所有变更。但我没有这个「开始」和「结束」的时刻。

另外 end-working 塞了太多东西——同步文档、检查测试覆盖、检查埋点、写日志、git commit——很多跟当前任务无关（我可能只是在讨论需求，根本没写代码）。每次收工要等好几分钟，结果就是我永远不想打这个命令，然后上下文就丢了。

本质上，「一次性读取」和「一次性写入」这种批处理模式，不适合连续性的工作方式。

第二版：checkpoint + recap

既然批处理不行，那就改成流式——随时可存，随时可读。

\`/checkpoint\` — 存档。随时调用，把当前进展、决策、进行中的事写到 \`docs/memory/YYYY-MM-DD.md\`。三个关键改进：

```markdown
1. 交给 subagent 后台执行，不占主对话上下文，不打断工作流2. 不只是手动触发——对话太长快 compact 时、任务切换时，AI 自动存一次3. 除了写日志，还同步 progress.md 和 Linear 任务状态
```

\`/recap\` — 恢复。新 session 开头打一下，读最近的 memory 和 progress，告诉你「上次到哪了，继续哪个？」

没有顺序依赖，没有开始结束。想存就存，想恢复就恢复。从批处理变成了流式处理，跟实际的工作节奏对上了。

记忆系统：三层，各管各的

Claude Code 自带一套 auto memory（\`~/.claude/projects/\*/memory/\`），会自动记住你纠正过它的行为、你的偏好、项目背景。比如你说了一次「不要用 start-working」，它写一条 feedback 记忆，以后所有 session 自动加载，不会再犯。

但 auto memory 解决的是「你是谁」和「你怎么工作」，解决不了「今天干了什么」和「项目推进到哪了」。

所以我加了第二层——文件级工作日志。每次 \`/checkpoint\` 写入 \`docs/memory/YYYY-MM-DD.md\`，记录当天的完成事项、进行中的工作、做了什么决策。这个思路参考了 OpenClaw的做法——它给 Agent 设计了每日 memory 文件，Agent 每天把关键信息写进去，第二天启动时读取恢复状态。同样的逻辑搬到人和 AI 的协作里完全适用。

再加上 \`docs/progress.md\` 作为第三层——不是日志，是当前快照。进行中的是什么、待办是什么、卡在哪里。日志按天堆积越来越长，progress 永远只反映当前状态。

三层配合：

```bash
| 层 | 文件 | 解决什么 | 谁写 ||---|---|---|---|| auto memory | \`~/.claude/projects/*/memory/\` | 你是谁、怎么工作、踩过什么坑 | Claude 自动 + 你触发 || 工作日志 | \`docs/memory/YYYY-MM-DD.md\` | 今天干了什么、做了什么决策 | /checkpoint 写入 || 当前快照 | \`docs/progress.md\` | 现在在做什么、下一步是什么 | /checkpoint 同步更新 |
```

auto memory 跨项目生效（你在 A 项目纠正的行为，B 项目也知道），工作日志和 progress 是项目级的。\`/recap\` 开头把三层都读一遍，AI 就从「这个人是谁 → 这个项目在做什么 → 上次聊到哪」完整恢复上下文。

跨项目一致性：全局 CLAUDE.md

用 CLI 时间长了你会发现一个问题：你在 A 项目里跟 AI 磨合出来的规矩，到 B 项目完全不生效。需求文档的格式、commit message 的风格、文件命名的规范——每个项目都要重新教一遍。

Claude Code 的 CLAUDE.md 是项目级的，每个项目一份。但其实你还可以在 \`~/.claude/CLAUDE.md\` 放一份全局的，所有项目的 session 都会自动加载。

我把跨项目通用的规则都放在全局 CLAUDE.md 里——需求文档必须用三位数字编号、必须有 9 章标准结构、每个 docs 子目录必须有 README 索引。写一次，所有项目遵守。项目级的 CLAUDE.md 只放该项目特有的信息。

踩坑不白踩：/postmortem

软件工程里有个概念叫 postmortem（事后复盘，直译是「尸检」）——线上出了事故之后，团队坐下来复盘：发生了什么、根因是什么、怎么避免下次再犯。Google、Meta 这些公司内部都有标准化的 postmortem 流程。

一个人开发没有团队帮你复盘，但 AI 可以。我写了一个 \`/postmortem\` 命令，踩完坑之后调一下，它会：

1\. 还原时间线——问题怎么发现的、试了哪些方案、最后怎么解决的

2\. 分析根因——表面原因 vs 真正原因

3\. 写入 \`docs/postmortem/\` 存档

4\. 判断这个教训要不要写进 memory 或全局 CLAUDE.md，让所有 session 都受益

比如前面提到的文档规范返工，postmortem 之后发现根因是「规范只存在于单个项目内部」，于是建了全局 CLAUDE.md。下次 AI 不会再犯同样的错，因为教训已经变成了它的记忆。

一个人开发最怕的不是踩坑，是同一个坑踩两次。postmortem + memory 的组合就是解决这个问题的。

新项目怎么起步：/init-project

每次开新项目，最费劲的不是写第一行代码，而是搭项目骨架——CLAUDE.md、docs 目录结构、progress.md、.gitignore。手动弄一次还行，项目多了就烦。

我写了一个 \`/init-project\` 命令，基于模板（\`~/.claude/CLAUDE-TEMPLATE.md\`）自动生成：创建 CLAUDE.md、初始化 docs 目录（requirements、features、memory、postmortem）、创建 progress.md、初始化 git。模板里引用了全局 CLAUDE.md 的规范，所以新项目从第一天就知道文档怎么写。

整体结构

最后说一下文件怎么组织的，分两层看：

全局层（所有项目共享）：

```bash
~/.claude/CLAUDE.md             ← 全局规范（文档格式、命名规则）~/.claude/CLAUDE-TEMPLATE.md    ← 新项目模板~/.claude/commands/recap.md     ← 恢复上下文~/.claude/commands/checkpoint.md ← 存档进展~/.claude/commands/init-project.md ← 初始化新项目~/.claude/projects/*/memory/    ← auto memory（你是谁、怎么工作）
```

项目层（每个项目各一份）：

```bash
CLAUDE.md                       ← 项目专属信息（技术栈、命令、架构）docs/progress.md                ← 当前快照（在做什么、下一步）docs/memory/YYYY-MM-DD.md       ← 工作日志（checkpoint 写入）docs/requirements/README.md     ← 需求索引docs/features/                  ← 功能文档docs/postmortem/                ← 复盘记录
```

全局层管「你是谁」和「怎么做事」，项目层管「这个项目在做什么」和「做到哪了」。新 session 开头 \`/recap\` 把两层都读一遍，上下文就恢复了。

总结

回头看这套东西，其实就解决了一个问题：让 AI 不要每次都从零开始。

四个自定义命令各管一件事：

```markdown
- \`/checkpoint\` — 随时存档，不丢上下文- \`/recap\` — 新 session 秒恢复，不用重新解释- \`/postmortem\` — 踩坑变记忆，同一个错不犯两次- \`/init-project\` — 新项目自带规范，不用从头教
```

加一个指挥室项目统管全局，加一个全局 CLAUDE.md 统一规则。

本质上就是把 AI 需要的上下文从对话里搬到文件里。对话会 compact，文件不会。你跟 AI 磨合出来的工作方式、踩过的坑、做过的决策，全部沉淀在文件系统里，每次 session 自动加载。

这套东西不复杂，一天就能搭完。但搭完之后你会发现，跟 AI 协作的体感完全不一样——它终于像一个记得住事的同事了。

继续滑动看下一个

sanvi.dev

向上滑动看下一个

微信扫一扫  
使用小程序

： ， ， ， ， ， ， ， ， ， ， ， ， 。 视频 小程序 赞 ，轻点两下取消赞 在看 ，轻点两下取消在看 分享 留言 收藏 听过