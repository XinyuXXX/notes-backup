---
title: Claude Code 大型代码库实践：把代码库变成 Agent 能工作的现场
author: 若飞
source: https://mp.weixin.qq.com/s/Lr3iL6untDGvb8Ahple2iw
clipped: 2026-05-16
---

若飞 若飞

在小说阅读器读本章

去阅读

---

Anthropic 5 月 14 日在 Claude Code at scale 系列里发了一篇新文，题目是《How Claude Code works in large codebases: Best practices and where to start》。

Anthropic 把 CLAUDE.md、Hooks、Skills、Plugins、MCP、LSP、Subagents 放到同一套大型代码库实践里。

如果只沿着功能名往下读，很容易把它看成一份扩展能力清单。

我想换个角度看，把它放回我们最近讨论的脉络里： [上下文操作](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409293&idx=1&sn=28327b5f4426c9f2060dfda8a19161c4&scene=21#wechat_redirect) 、 [CLAUDE.md](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409311&idx=1&sn=b49adb6c9a4760084bcac7bfa7e08232&scene=21#wechat_redirect) 、 [Memory](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409319&idx=1&sn=0301eb71a592e20188e071a238fcd9c8&scene=21#wechat_redirect) 、 [Goal](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409345&idx=1&sn=50d9b14861961fa8e6d994ad50bfad7e&scene=21#wechat_redirect) ，再到 [Subagents](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409171&idx=1&sn=f1205a72f8219032770c1144307d1efa&scene=21#wechat_redirect) 、 [Harness](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409162&idx=1&sn=62556a10e227bcb8d977a4f3e0006c8b&scene=21#wechat_redirect) ，这些线索其实一直在绕着同一个问题打转：

**一个真实的代码库，要怎么样才能变成 Agent 能稳定工作的现场。**

Claude Code 能进百万行 monorepo、遗留系统和多仓库架构里干活，不是因为模型突然“读懂了一切”。

更朴素地讲，是代码库、工具链和组织流程，开始被整理成 Agent 能导航、能执行、能验证、能复用的工程环境。

这个变化，值得多花点时间看。

---

## 太长不看

- • 我读到的核心提示是：大型代码库要为 Agent 准备好入口、边界、工具和责任人。
- • Claude Code 一次任务的基本循环大致是这样：加载任务和项目上下文 → 搜索 / 阅读当前工作区 → 沿引用和诊断缩小范围 → 编辑代码 → 跑测试或检查 → 再根据反馈继续迭代。
- • 大型代码库的难点常常不只在行数，更多是知识散落：目录不自解释、测试命令分散、局部约定没人写、生成文件和第三方代码混在一起。
- • RAG 和索引在代码场景里容易遇到新鲜度问题，Agentic Search 的价值是直接面对当前工作区；但这不等于所有知识库都该放弃 RAG。
- • CLAUDE.md 更像一份轻量行为契约：根目录给全局地图，子目录给局部约定，越短越值钱。
- • Skills、Hooks、Plugins、MCP、LSP、Subagents 不是功能堆叠，它们分别在处理专业知识、确定性动作、组织分发、外部工具、符号导航和上下文隔离。
- • 组件顺序也很关键。先让代码库可读，再把确定性检查交给工具，再做知识分发和内部连接。基础没搭好，MCP 只会把混乱接进更多系统里。
- • 企业缺的往往不只是“再买一个更强的模型”，更多是缺一个人去把有效经验沉淀成团队的默认环境。
- • 大规模推广也不是“开账号、发权限”这么简单。它属于开发者体验工程：第一次接触就能跑通，后面才会有采用率。
- • 一个对 Agent 友好的代码库，通常也会对新人、维护者和架构演进更友好。

---

## Claude Code 一次任务是怎么跑的

如果只说一句“Claude Code 会读代码库”，这个说法还是太粗了。

更贴近官方文档的说法是 agentic loop：先收集上下文，再采取动作，最后验证结果。放进大型代码库里，大致可以拆成七个动作。

![](https://mmbiz.qpic.cn/sz_mmbiz_png/Fnx2G2wYdEJQrPAvJzy9CmWyzJLvQGwickh28tV0brqvfzxKQwIibMARKu8gzKbgwhN08ic3eVNbibXkTLh4UpeT7FoAqXnsDz5vmjoHwczltPc/640?wx_fmt=png&from=appmsg)

Claude Code 在大型代码库里的一次任务循环

第一步，先拿到任务和启动上下文。

用户提出一个任务：“支付流程里，过期卡用户结账失败，帮我查一下。”Claude Code 不会从头读完整个仓库，它会先看当前目录，再沿途加载到的 `CLAUDE.md` ：根目录给仓库地图，子目录给局部约定，比如这个服务怎么跑测试、哪些文件不能改、迁移脚本在哪。

如果任务一开始就给了具体路径，比如 `src/payments/` ，搜索半径会小很多；如果只给了一个很泛的描述，它就得自己先找入口。

第二步，在当前工作区里找线索。

这一层不走提前传到服务器的全量索引路线，主要靠本地工作区里的文件系统、glob、grep、文件读取。它会搜关键词、错误栈、测试名、路由名、配置项，比如：

```
expired card
payment token
checkout failure
src/payments
```

搜到几个可疑入口后，它不会一股脑把结果全塞进上下文，而是挑看起来相关的几个继续读。读到函数名、错误类型、接口名以后，再反向搜调用方，一步步把工作集收敛到几组文件。

第三步，沿着代码关系确认“是不是同一个问题”。

纯文本搜索只能告诉它“哪里出现了这个字符串”。在大仓库里，这远远不够。同名函数、同名错误码、同名配置项可能散落在好几种语言、好几个模块里。

LSP 在这里就很关键了。装好 code intelligence plugin 和对应 language server 之后，Claude 就能拿到跳转定义、查找引用、类型诊断这类原本只有 IDE 才有的能力。看到 `refreshPaymentToken` ，可以继续追到定义和调用方；看到类型错误，也能在编辑后立刻拿到诊断反馈。

第四步，形成一个很小的修改假设。

它不会真的“理解整个百万行代码库”。更常见的情况是，它把问题压缩成一个很局部的假设：

> 过期卡场景下，token refresh 失败后没有进入重试分支，导致 checkout 状态被提前标记为失败。

这个假设可能对，也可能错。关键是后面有没有验证的手段。

第五步，编辑代码之前，先有权限和回滚边界。

Claude Code 的文件修改也需要边界。官方文档里有两个很实际的安全面：permissions 和 checkpoints。

permissions 决定它能不能直接改文件、能不能跑某些命令；checkpoints 会在编辑前记录文件快照，方便回退。涉及数据库、API、部署这类带外部副作用的命令，是没办法靠 checkpoint 兜底的，所以授权上要更保守。

这也是为什么大团队会把权限写进 `.claude/settings.json` 或者组织策略里，而不是寄希望于每个人临场判断。

第六步，改完之后跑一轮局部验证。

比较理想的情况是，子目录 `CLAUDE.md` 已经写好了这个服务对应的命令：

```
npm test -- payments
npm run lint -- src/payments
```

Claude 改完之后会跑这些命令。失败了，就读失败输出，再回到搜索、阅读、编辑这条循环里。输出太大的时候，它还要学会丢掉噪音，只留下和当前改动相关的失败。

这里的关键在验证。没有测试、lint、type check，Claude 也只能凭语言模型自己判断“看起来对了”。有了可执行反馈，一次改动才能从“合理猜测”推进到“有证据支持”。

第七步，把高噪声的探索隔离出去。

任务一旦变大，比如“先理解整个支付子系统”，主会话如果直接承担所有探索，很容易被搜索结果、日志和失败路径填满。Subagents 的用处就在这里：让一个只读 subagent 先去摸清子系统，最后只把结论、关键文件和证据交回主会话。

这样主 Agent 开始编辑时，手里拿到的是一份整理过的工作集，而不是一堆中间噪音。

所以 Claude Code 在大仓库里到底是“怎么干活的”，核心并不是一次性把所有代码读懂。

更接近的描述是：一个被工具加强过的工程师，先找入口、再读局部、再追引用、再提出修改假设、再靠测试和诊断验证。大型代码库的改造，就是让这条循环少猜一点、少绕一点、少误伤一点。

---

## 先把几条外部线索放在一起

这条线并不只来自 Anthropic。

Tobi Lütke 那条关于 context engineering 的 X，我读下来像一句工程提醒：prompt 写得漂亮还不够，任务要可解，关键是把必要的上下文放进模型能工作的范围里。

Karpathy 在 Sequoia Ascent 2026 的整理稿里，把 Software 3.0 描述成通过 prompts、context、tools、examples、memory、instructions 来编程。他还提到，编程的单位正在从“一行一行敲代码”，走向委托更大的 macro actions：实现一个功能、重构一个子系统、调研一个库、写测试再修复失败。

这句话放到 Claude Code 大型代码库实践里看，就能落到工程细节上。

这里说的上下文，已经不只是聊天窗口里的那点背景材料。它会落到仓库结构、 `CLAUDE.md` 、目录规则、日志、测试、权限、插件和 MCP 上。工具也不只是“可以调几个函数”，而是搜索、编辑、运行命令、看诊断、查引用、访问内部系统的一整套操作面。前面梳理上下文工作集时，我们聊的也是同一件事：上下文应该按工作集来运营，不能只当聊天记录。

Boris Cherny 在 Latent Space 那次 Claude Code 访谈里，给了另一个产品侧的线索：Claude Code 早期试过 RAG / code index，后来转向 agentic search。这条经验很容易被读成“索引无用”，但那样太粗。更贴近代码场景的说法是，“找上下文”已经成了 Agent 运行循环的一部分。开发工具正在从 IDE 走向 Agent 控制台，也能从这里看到原因。

Simon Willison 用 Agentic Engineering 指的是：专业工程师使用 Claude Code、Codex 这类能生成并执行代码的 coding agents，通过测试和反馈自己迭代。Addy Osmani 的说法更偏工程纪律一点：AI 可以加速实现，但架构、质量和正确性，仍然要人来负责。

Karpathy 的 `autoresearch` 是一个小型实验剖面：让 Agent 只改 `train.py` ，人维护 `program.md` ，每次训练固定 5 分钟，用 `val_bpb` 这样的指标来判断有没有改善。最值得借鉴的点很朴素：自主循环被关进了一个很窄的框架，范围清楚、预算固定、指标可比、结果可回滚。这也能解释前面讲 goal 和工作现场时，为什么要反复强调范围、预算和反馈。

把这些线索合在一起看，Claude Code 大型代码库实践就不只是工具教程了。

它在说一个更工程化的变化：Agent 能做更大动作之后，代码库本身也得跟着变得更可编程。上下文、工具、记忆、规则、测试、指标、权限、回滚，都会成为 Agent 工作现场的一部分。

---

## 大型代码库难在哪里

很多人听到“大型代码库”，第一反应就是代码行数。

百万行、千万行、几十个仓库、几千个开发者，光听这些数字就够吓人的。

但从我的使用经验看，代码行数只是表层压力。更容易让 Agent 跑偏的，往往是这些缺口：

- • 不知道该从哪个目录开始看；
- • 不知道这个服务的测试命令和别的服务不一样；
- • 不知道某个文件是生成物、不能手改；
- • 不知道同名函数到底属于哪种语言、哪个模块；
- • 不知道局部团队有哪些历史约定；
- • 不知道改完以后，什么证据才算“做完了”；
- • 不知道哪类工具输出只是噪音，哪类才是关键线索。

这些问题，人类工程师也一样会遇到。

新人入职一个大仓库，完整文档当然有用。但第一时间能帮他少走弯路的，往往是一张地图：入口在哪里、哪些地方别动、常见命令怎么跑、出了错先找谁。

Agent 也一样。

只是它更容易把这些缺口放大。

人看不懂会停下来问同事；Agent 很多时候会继续猜。猜对了像生产力，猜错了就是一串看上去合理、实际却偏离现场的改动。

所以读官方长文时，我会留意那条反复出现的暗线：

**Claude Code 在大型代码库里能做到哪一步，很大程度上取决于这个代码库本身可不可被导航。**

这句话，比“模型多强”更接近工程现实。

---

## Agentic Search 的重点不在 grep

官方文章里有一个很容易被单独拿出来看的细节：Claude Code 不依赖提前构建和上传代码库索引，它就在开发者本地遍历文件系统、读文件、用 grep 找线索、沿引用关系继续追。

这和 Boris Cherny 之前在 Latent Space 访谈里提到的路线是能对上的：Claude Code 早期试过 RAG / 代码索引，后来转向了 agentic search。

前面梳理“从代码检索到上下文操作”时，我们也专门聊过这个变化。

这里需要补一个边界：这不是“grep 打败了 RAG”。

更准确的说法是：

**在代码任务里，搜索正在从系统预处理模块，搬到 Agent 的运行循环里去。**

![](https://mmbiz.qpic.cn/mmbiz_png/Fnx2G2wYdEIp30eLqW7mqC0wsyzicBqXNvJa3OpkJTvcQmTBKCNujKibGxxngnuhbfBLpeAL8GqJZiatLPkKIkJWzqBb2JcIRkiaL1cLrtf3Ig0/640?wx_fmt=png&from=appmsg)

代码检索从前置索引到运行时搜索

传统 RAG 是一条前置 pipeline：先切块、建索引、召回，再把结果丢给模型。

Agentic Search 则更像工程师自己进现场：先看目录，再搜入口，读到一个函数名就顺着去找调用方，跑测试拿到报错，再换关键词缩小范围。

代码库天然有很多高精度锚点：函数名、路径、错误栈、测试名、配置项、环境变量、commit message。很多时候，精确搜索 + 实时文件读取，比一份旧索引更贴近当前工作区。

但这不等于语义搜索就没价值了。

在自然语言问题、跨模块概念查询、大型 monorepo 的模糊定位里，语义检索仍然能补上 grep 找不到的那一部分。成熟的系统通常不会做二选一，而是把 grep、glob、LSP、语义搜索、测试反馈一起放进 Agent 的工作循环里。

这里更值得架构师关注的，是 Agent 有没有权力、工具和预算去做这些动作：

- • 搜索当前工作区；
- • 读取必要文件；
- • 追符号引用；
- • 运行测试和 lint；
- • 把低价值输出丢掉；
- • 把关键发现沉淀下来；
- • 在证据不足时停止或者缩小范围。

搜索只是第一步。

能不能把搜索、阅读、修改、验证和收束这一串动作串起来，才是 Harness 这一层要操心的事。

---

## CLAUDE.md 要短，才值钱

官方文章把 CLAUDE.md 放在第一层，这个顺序我是认同的。

但这一层也最容易写重。

很多团队一看到 CLAUDE.md 有用，就开始往里面塞东西：项目背景、架构设计、编码规范、测试命令、部署流程、历史坑位、安全要求、个人偏好，最后写成一份长长的“希望模型都记住”的说明书。

问题在于，CLAUDE.md 每次会话都会加载。

多塞一点无关内容，就会挤占当前任务需要的上下文。更麻烦的是，规则一多就会互相打架，模型也未必知道哪一条优先。

所以我会把 CLAUDE.md 看成一份轻量行为契约。

根目录只放三类东西：

- • 这个仓库的最高层地图；
- • 跨团队都必须遵守的少量约束；
- • 最容易造成严重事故的关键提醒。

子目录再放局部约定：

- • 这个服务怎么跑测试；
- • 哪些文件不能直接改；
- • 这里的命名、错误处理、迁移方式有哪些特殊要求；
- • 常见失败先看哪些日志或者命令。

这样做的好处是，Claude Code 在相关目录启动时，能自动拿到沿途的上下文。根目录不丢，局部规则也不会污染到整个仓库。

这条思路和前面整理 CLAUDE.md 时的结论是一条线：规则文件有用的地方，是把真实的失败模式沉淀成最小必要约束，而不是指望模型“记住所有要求”。

可复用的专业知识不太适合塞进 CLAUDE.md。

像安全审查、数据库迁移、发布检查、文档更新这种，更适合做成 Skills，按需加载。

确定性的动作也不适合继续写成提示词。

像格式化、lint、命令拦截、会话结束后更新建议这种，更适合直接交给 Hooks。

放到工程视角里，这其实很普通：能用代码保证的，优先交给代码；能按需加载的，优先按需加载，避免让每一轮上下文背太多东西。

只是到了 Agent 时代，我们又要把这套老经验重新过一遍。

---

## 三层工作现场

官方文章列了很多组件：CLAUDE.md、Hooks、Skills、Plugins、MCP、LSP、Subagents。

如果逐个讲，很容易写成功能清单。

我会把它们压成三层。

![](https://mmbiz.qpic.cn/mmbiz_png/Fnx2G2wYdEKIMRIDs3Tdu2jXg4ExnWIS6DHQzdqHdOXxE5xvA2bV8Z23fHhLx02cZNyCrnycRLJhbpLDXp0vezn7TrCAQjTT6DdXUaBr0EA/640?wx_fmt=png&from=appmsg)

Agent 可工作的代码库现场三层结构

第一层是上下文层。

它回答的是：Agent 进入代码库时，先看什么，怎么少猜一点。

这里包括：

- • 分层 CLAUDE.md；
- • 代码库地图；
- • 目录级测试和构建命令；
- • Skills；
- • Memory；
- • 能够被引用的设计文档和 ADR。

这一层处理的是“知道去哪里看”。

第二层是执行层。

它回答的是：Agent 真动手时，怎么少犯低级错，怎么拿到可靠反馈。

这里包括：

- • grep / glob / 文件读取；
- • LSP 符号导航；
- • tests / lint / type checker；
- • permissions；
- • Hooks；
- • MCP 连接的内部工具；
- • sandbox / worktree / CI。

这一层处理的是“动手以后怎么验证”。

第三层是治理层。

它回答的是：一个人调出来的好配置，怎么变成团队默认能力。

这里包括：

- • Plugins；
- • 统一 marketplace；
- • DRI 或 Agent Manager；
- • 安全和权限策略；
- • code review 流程；
- • 配置审查节奏；
- • 组织级推广路线。

这一层处理的是“经验怎么复用，风险怎么收口”。

放在这三层里看，Anthropic 想说的就不只是“装一堆扩展”了。

它讲的是：要让 Agent 在大型代码库里稳定可用，得把原本散在工程师脑子里、终端历史里、团队群消息里、CI 配置里、局部脚本里的那些知识，整理成一个可进入、可执行、可追踪的现场。

还有一个容易被忽略的点： **顺序比数量重要。**

Claude Code 的扩展层不是堆得越多越好。

根目录 CLAUDE.md 还没写清楚，团队就急着接一堆 MCP，结果往往只是让 Agent 更快地访问到更多不稳定信息。局部测试命令还没沉淀，先去搞复杂的插件市场，也只是把半成品配置分发给了更多人。生成文件、第三方代码、构建产物都还没排除，就先讨论多 Agent 并行，主 Agent 和子 Agent 只会一起把上下文吃掉。

一般来说，可以按这个顺序来看：

1. 1\. 先让代码库可导航：目录地图、分层 CLAUDE.md、ignore、局部命令。
2. 2\. 再让动作可验证：测试、lint、类型检查、权限、Hooks。
3. 3\. 再让经验可复用：Skills、Plugins、团队模板。
4. 4\. 最后再去接外部系统：MCP、内部搜索、工单、文档、数据平台。

这个顺序最大的好处就是少返工。

Agent 进入大型代码库以后，风险经常不在能力不够，而在能力已经很多，却没有上下文边界、没有验证证据、没有权限收口。

前面聊 [Cursor Harness](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409236&idx=1&sn=71ae43ca6ec5b3cb1f82c258b1542271&scene=21#wechat_redirect) 和 [Martin Fowler 的 Harness Engineering](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409277&idx=1&sn=f73a7d925414775f9b8dfe9f2ce5ef88&scene=21#wechat_redirect) 时，我们反复绕回一句话： **模型决定能力上限，Harness 决定生产下限。** 放到 Anthropic 这组实践里看，这个下限有很大一部分来自顺序：先把现场整理干净，再把能力接进来。

这也能解释为什么官方会反复强调 DRI 和 Agent Manager。

没有人负责，这套东西很快就会碎。

张三在自己电脑上写了一个好 hook，李四不知道；某个支付团队整理了一份很好的 CLAUDE.md，另一个团队照抄过去反而误导；一个 MCP 工具没人维护，几个月后权限模型变了还在被调用。

自下而上的热情当然重要，但只靠热情，经验会停在小圈子里。

大组织最后拼的，往往不是第一个人有多会用。更关键的是，有效用法能不能沉淀成默认环境。

---

## LSP 是被低估的一层

官方文章专门提到了 LSP，这一点值得再放大一些。

grep 能找到字符串，但它不懂符号。

大型代码库里，一个常见函数名可能出现几千次。没有符号级导航，Agent 就只能打开一堆文件，靠上下文慢慢猜哪个才是目标。

这会烧掉大量窗口，也会增加误判。

LSP 的价值在于：它把 IDE 里“跳转到定义”“查找引用”“区分同名符号”这些能力，直接暴露给了 Agent。

这一点对 C、C++、Java、C#、TypeScript 这类语言尤其重要。

Claude Code 官方现在把 code intelligence plugins 放进了插件市场这一层：TypeScript 对应 `typescript-language-server` ，Python 对应 `pyright-langserver` ，Rust 对应 `rust-analyzer` ，Go 对应 `gopls` ，C / C++ 对应 `clangd` 。

落地时有两个细节容易漏掉。

第一，LSP 不是装了 Claude Code 就天然能用的。对应的 language server binary 得在 `$PATH` 里，仓库本身也要让语言服务器能正确理解项目结构。

第二，大仓库里 LSP 也是有成本的。 `rust-analyzer` 、 `pyright` 这类服务可能吃掉不少内存；monorepo 配置不完整时，还会报一些 unresolved import 之类的假阳性。这时候既不能盲信诊断，也不能因为有几个误报就不用它。更实际的做法是把它当成一个高价值信号源，再和测试、编译、人工 review 合在一起判断。

大型代码库里很多错误，不是搜不到文本造成的。更常见的是找错层级、找错实现、找错重载、找错生成代码。

如果说 grep 是“先找到线索”，那 LSP 负责“确认这条线索是不是同一个代码事实”。

这里也顺带提醒一句：面向 Agent 的工程改造，不一定都得很新。

很多能力本来就在开发者工具链里，只不过过去服务的是人类 IDE，现在要变成 Agent 能调用的接口。

测试也是同样的道理。

lint、type check、unit test、integration test、snapshot test，本来都是人类工程师用来收束不确定性的工具。Agent 进来以后，它们不仅没有过时，反而更重要。

Addy Osmani 在写 Agentic Engineering 时反复强调质量和测试，Martin Fowler 讲 Harness Engineering 时也在强调外层控制结构。两位的侧重点不完全一样，但底层逻辑很接近：

**模型越能自己动手，外层验证就越不能松。**

---

## Subagents 的重点还是上下文隔离

官方文章还给了一个很实用的处理方式：Subagents 把探索和编辑分开。

这和我们 4 月底梳理 [Subagents](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409171&idx=1&sn=f1205a72f8219032770c1144307d1efa&scene=21#wechat_redirect) 时的问题，可以放在同一条线里读。

很多长任务最后跑坏，并不是主 Agent 不聪明。它一边探索、一边编辑、一边看日志、一边改计划，窗口很快就被填满。旧假设、无关搜索结果、失败路径、临时输出全都留在主上下文里，后面越跑越乱。

Subagent 的价值，也不在“多几个智能体显得高级”。

它做的事情是把高噪声的任务挪到独立工作区里：

- • 让一个只读 subagent 先摸清某个子系统；
- • 让另一个 subagent 整理测试失败原因；
- • 让主 Agent 只接收结论和证据；
- • 开始编辑的时候，主 Agent 保持一份相对干净的工作集。

这和大型团队里“先调研，再动手”的节奏很像。

只是以前调研报告是人写给人看，现在变成一个 Agent 写给另一个 Agent，最后仍然要能被人审。

这也是我一直比较警惕“多智能体”这个词的原因。前面讨论 Sub-Agent 和 Agent Team 的差别时，我们把这个问题拆得更细一些。

角色数量并不重要。

上下文边界才重要。

边界切错了，多个 Agent 只会把混乱并行化；边界切对了，Subagents 才能把探索噪音关在主任务之外。

---

## 推广先从第一次体验做起

官方原文里有一段组织层面的内容，容易被前面的功能章节盖过去，但落地时很关键。

Anthropic 观察到一个现象：推广最快的团队，往往会在大范围开放之前，先让一个小团队把基础设施搭好，插件、MCP、CLAUDE.md 层级、权限策略、代码审查流程，至少先跑出一条能让普通工程师顺手用起来的路径。

这一点也能和“开发工具正在从 IDE 变成 Agent 控制台”的判断放在一起看。

以前开发者体验更多是围绕人来设计的：新同事怎么拉代码、怎么跑测试、怎么发版、怎么查日志。现在多了一个新使用者：Agent。它同样需要入口、手册、权限、工具目录和反馈回路。

如果一个开发者第一次接触 Claude Code 的体验是：

- • 不知道该从哪个目录启动；
- • 一改文件就跑全量测试，一等就是超时；
- • 读到一堆生成代码和第三方依赖；
- • 需要的内部文档根本不在工作区里；
- • 代码审查流程跟 AI 改动完全没对齐；
- • 出错以后没人知道该改 CLAUDE.md、还是改 Hook、还是改工具描述。

那他很快就会得出一个结论：这东西不适合我们。

这个结论未必公平，但很难逆转。

所以我现在会把 Agent 落地当成开发者体验工程来做，而不只是当成一次 AI 工具采购。

小团队里，至少得有一个 DRI，能拍板：哪些规则进仓库、哪些 Skills 允许共享、哪些 MCP 可以接、哪些目录先试点、什么时候该把过期配置删掉。

大组织里，尤其是金融、医疗、政企、车企这类受监管场景，还要更早一点把工程、信息安全和治理拉到一张桌子上。谁能装插件、谁能发布 Skill、AI 生成代码怎么走 review、哪些工具只读、哪些工具可写，这些问题如果不提前定下来，后面会被每个团队各自实现一遍。

这听上去像管理问题。

但落到 Agent Harness 里，它其实就是架构问题：权限、审计、分发、回滚、责任边界，最后都会变成系统的一部分。

---

## 落地的几个事

如果一个团队明天就想把 Claude Code 放进一个大仓库，我并不建议一上来就铺一个完整平台。

更稳的做法，是先挑一个真实但边界清楚的试点目录，然后做几件小事。

第零步，先判断边界。

Anthropic 的经验样本，主要来自比较常规的软件工程现场：主要贡献者是工程师，仓库走 Git，目录结构大体标准，代码以文本文件为主。

如果面对的是大型游戏引擎、重二进制资产仓库、非 Git 版本控制，或者大量非工程师也在改代码的系统，改造成本会高得多。不是不能做，只是不能照抄“分层 CLAUDE.md + LSP + 子目录命令”就指望马上能跑顺。

第一件事，写一份极短的根目录 CLAUDE.md。

篇幅尽量控制在一页以内，只写仓库地图、全局硬约束、最重要的命令入口，以及严重禁区。

第二件事，在试点目录加局部 CLAUDE.md。

写清楚这个目录的测试、lint、构建、生成文件、迁移规则、常见坑位。只写这里适用的内容，避免写成全公司规范。

第三件事，补一张代码库地图。

如果顶层目录很多，先写前两层。每个目录一句话就够，不追求完整设计文档，只追求让 Agent 和新人都知道从哪里开始。

第四件事，把 ignore 和权限配好。

生成文件、第三方代码、构建产物、大日志、敏感文件先排掉。能在仓库里版本化的规则尽量版本化，减少对每个开发者个人记忆的依赖。

第五件事，把确定性检查交给工具。

格式化、lint、type check、单测命令、危险命令拦截，尽量做成脚本或者 hook。停留在“请记得运行测试”这种提醒，效果通常很有限。

第六件事，把专项流程做成 Skills。

比如安全 review、数据库迁移、发布检查、API 变更、文档更新。这些更适合在任务需要时按需加载，而不是挤在每个会话里。

第七件事，把 LSP 跑起来。

尤其是多语言、强类型、历史包袱重的仓库。符号级导航能省下大量无效搜索。

第八件事，指定一个明确负责的人。

这个人不用一上来就叫 Agent Manager，但要有人能拍板：规则怎么写、插件怎么发、权限怎么收、哪些经验进团队默认配置、哪些配置三个月后该删掉。

第九件事，把 review 和发布流程先对齐。

AI 改的代码仍然要按人的代码一样进 review、跑 CI、留记录。试点阶段尤其不适合给 Agent 绕过质量门禁的特权。越早把这条线说清楚，后面解释成本越少。

这些事看上去都不炫。

但它们比“再换一个更大的模型”更接近大型代码库里的有效杠杆。

---

## 配置也会过期

Anthropic 文章里还有一个提醒很实在：随着模型能力变化，旧配置可能会变成负担。

这点在工程现场很常见。

早期模型做不好跨文件重构，于是团队写规则要求它每次只改一个文件。这条规则当时确实有用。等模型已经能处理更大范围改动了，它反而可能开始限制 Agent 去做正确的事。

Hooks 也是一样的。

某些 hook 当初是为了弥补旧工具不支持某个环境。后来工具原生支持了，这个 hook 就该删掉。

这跟传统软件工程没什么两样。

所有配置都会老化。区别只在于：Agent 配置老化后不一定报错，它可能只是让系统变慢、变啰嗦、变保守，或者在某些任务里不断绕远路。

所以我并不太相信“一份终极 CLAUDE.md”这种说法。

更合理的做法是定期审查：

- • 哪些规则还映射真实的失败模式；
- • 哪些规则只是历史焦虑的产物；
- • 哪些 Skills 使用频率很低；
- • 哪些 Hooks 已经被新版本能力替代了；
- • 哪些 MCP 工具权限给得太大；
- • 哪些配置让 Agent 花更多 token，却没有更好的结果。

官方建议每三到六个月做一次配置 review。这个节奏比较稳。

尤其是大模型发布、Claude Code 或者 Codex 这类工具出大版本以后，更应该回头看一眼。

Agentic Engineering 不是规则写完就结束。

它是在持续维护一个研发现场。

---

## 写在最后

把 Anthropic 这次长文和最近几篇放在一起看，我自己的思路又被理清了一层。

前面梳理 [上下文操作](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409293&idx=1&sn=28327b5f4426c9f2060dfda8a19161c4&scene=21#wechat_redirect) 的时候，我们更关心 Agent 怎么拿到搜索、阅读、执行和验证的“上下文操作权”。

写 [CLAUDE.md](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409311&idx=1&sn=b49adb6c9a4760084bcac7bfa7e08232&scene=21#wechat_redirect) 时，我们把规则文件从“提示词崇拜”里拿了出来，放回到轻量行为契约这一层。

写 [Memory](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409319&idx=1&sn=0301eb71a592e20188e071a238fcd9c8&scene=21#wechat_redirect) 和 [Goal](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409336&idx=1&sn=bbf6617f88f4138851ddf0fb202dbdf5&scene=21#wechat_redirect) 时，问题又往前走了一步：过去的信息凭什么影响未来，目标如何从一句 prompt 变成运行时的控制面。

这次官方长文，刚好把这些线索一起放进了大型代码库这个现场里。

**当代码库足够大，AI Coding 的问题就已经不只是“模型会不会写代码”了。**

它会变成一组更工程化的问题：

- • Agent 有没有入口；
- • 上下文有没有分层；
- • 动作有没有权限；
- • 修改有没有验证；
- • 经验有没有分发；
- • 错误有没有复盘；
- • 配置有没有人维护。

这些问题听起来一点都不新。

它们本来就是软件工程，只不过调用方从人类开发者，多了一个会搜索、会编辑、会执行、也会犯错的 Agent。

所以我现在越来越觉得，一个对 Agent 友好的代码库，并不意味着为机器牺牲人的体验。

很多时候恰好相反。

一个 Agent 更容易进入的代码库，新人也更容易进入；一个 Agent 更容易验证的改动，人类 reviewer 也更容易审；一个 Agent 更容易接管的工作现场，团队在人员变化、系统迁移和架构演进的时候，也更不容易失控。

这可能才是 Claude Code 大型代码库实践里最值得带走的部分。

重点不在某个工具终于能读懂百万行代码。

更值得留意的是，我们终于被迫把代码库里那些长期靠经验、靠口口相传、靠“老同事知道”撑着的东西，整理成了工程资产。

这些工作做好以后，受益的不只是 Agent。

人也会轻松很多。

---

## 参考来源

- • Anthropic：How Claude Code works in large codebases: Best practices and where to start  
	https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start
- • Claude Code Docs：How Claude Code works  
	https://code.claude.com/docs/en/how-claude-code-works
- • Claude Code Docs：Memory / Hooks / Skills / Plugins / Subagents  
	https://code.claude.com/docs/en/memory
- • Claude Code Docs：Discover plugins / Code intelligence  
	https://code.claude.com/docs/en/discover-plugins
- • Latent Space：Claude Code: Anthropic's Agent in Your Terminal  
	https://www.latent.space/p/claude-code
- • Tobi Lütke：Context engineering  
	https://x.com/tobi/status/1935533422589399127
- • Andrej Karpathy：Sequoia Ascent 2026 summary  
	https://karpathy.bearblog.dev/sequoia-ascent-2026/
- • Andrej Karpathy：autoresearch  
	https://github.com/karpathy/autoresearch
- • Simon Willison：Writing about Agentic Engineering Patterns  
	https://simonwillison.net/2026/Feb/23/agentic-engineering-patterns/
- • Addy Osmani：Agentic Engineering  
	https://addyosmani.com/blog/agentic-engineering/
- • Martin Fowler：Harness Engineering  
	https://martinfowler.com/articles/harness-engineering.html

如喜欢本文，请点击右上角，把文章分享到朋友圈

如有想了解学习的技术点，请留言给若飞安排分享

**因公众号更改推送规则，请点“在看”并加“星标”第一时间获取精彩技术分享**

**·END·**

```
相关阅读：刚刚，Claude Code“代码泄露”背后：如何重新看 Agent Harness大家都在讲 Harness，但它到底该怎么理解模型越来越强，为什么大家却开始重写 Harness如何让单个 Agent 做长任务不失真：Anthropic 给出了一套更工程化的答案Claude Code高手的 8 个 Claude Code 实战习惯别从 README 开始：一个架构师会怎样翻 Codex 仓库Spec 不是代码的替代品，它是 AI Coding 的上下文管理层如何让 Agents 自己设计、升级 AgentsOpenAI怎么把开源项目维护做成工作流：Skills、AGENTS.md 和 CI 的一套组合拳Claude Skills 入门：把“会用 AI”变成“可复制的工程能力”一套可复制的 Claude Code 配置方案：CLAUDE.md、Rules、Commands、HooksClaude Code 最佳实践：把上下文变成生产力（团队可落地版）把 AI 当成新同事：Agent Coding 的上下文与验证体系一周写百万行的背后：Cursor长时间运行 Agent 的工程方法论我真不敢相信，AI 先加速的是工程师。扒一扒 Claude Cowork 系统提示词：Anthropic 如何打造数字同事Cowork 安全架构深度解析：从 Claude Code 到 Cowork，Anthropic 如何把“可控”做成产品Anthropic官方万字长文：AI Agent评估的系统化方法论银弹还是枷锁？Claude Agent SDK 的架构真相Claude Code创始人亲授13条使用技巧Claude Code 内部工具开源 code-simplifier：终结 AI 屎山代码的终极方案
```

> 版权申明：内容来源网络，仅供学习研究，版权归原创者所有。如有侵权烦请告知，我们会立即删除并表示歉意。谢谢!

**架构师**

我们都是架构师！

![图片](https://mmbiz.qpic.cn/mmbiz/sXiaukvjR0RB58TtkIHwhn4lpsqLnZgian9d5tr1BibP7XpibGTFFib1nq9YuYq209XZUEfCOqMzepDOBbN9KD9wMSg/640?wx_fmt=jpeg&wxfrom=5&wx_lazy=1&tp=webp#imgIndex=2)

****关注** 架构师(JiaGouX)，添加“星标”**

**获取每天 AI 技术干货，一起成为牛逼架构师**

**AI/Agent群请** **加若飞：** **1321113940** **进群**

投稿、合作、版权等邮箱： **admin@137x.com**

继续滑动看下一个

架构师

向上滑动看下一个

微信扫一扫  
使用小程序

： ， ， ， ， ， ， ， ， ， ， ， ， 。 视频 小程序 赞 ，轻点两下取消赞 在看 ，轻点两下取消在看 分享 留言 收藏 听过
