---
title: 拆解 Hermes Agent 的三层学习机制：OpenClaw 加自总结 Skills 后，差异还剩什么？
author: 架构师
source: https://mp.weixin.qq.com/s/twOGltgevrfhLv6f90SCgg
clipped: 2026-05-10
---

架构师 架构师

在小说阅读器读本章

去阅读

昨天那篇《 [OpenClaw vs Hermes：一文深入理解两大通用 Agent](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409010&idx=1&sn=04b9836fa07ff877c459e300707ddcff&scene=21#wechat_redirect) 》发出去后，评论区有个问题很值得单独拎出来讲。

大意是：

如果给 OpenClaw 加一套自我总结、自动沉淀 skills 的机制，那它和 Hermes 还有什么区别？

还有，记忆这块看起来也没差太多。OpenClaw 也有 Markdown 记忆文件，长期还是靠 SQLite / FTS 检索，Hermes 好像也一样。

这个问题把一个很关键的边界问出来了。

我重新翻了一遍 Hermes Agent 的官方文档和本地仓库源码，也补看了 OpenClaw 官方 memory 文档。我不想把它当成一个误解。它确实问到了关键处，只是还需要继续拆开。

如果只看"有没有长期记忆""有没有全文检索""有没有 Markdown 记忆文件"，OpenClaw 和 Hermes 的确越来越像。

但如果只停在"OpenClaw 有没有记忆""Hermes 有没有 SQLite"这一层，很容易漏掉另一个问题：

**一个 Agent 系统到底把什么东西当成长期资产，又把这些资产放在运行时的哪一层。**

在 Hermes Agent 里，这件事被拆成了三层：

- • 事实记忆：它需要长期知道的事实、偏好和环境约定。
- • 会话检索：它过去做过什么、聊过什么、哪里踩过坑。
- • 过程记忆：它下次遇到同类任务时，可以按什么方法做。

这三层合起来，才让 Hermes 所谓 closed learning loop 变得更像一套工程机制。

---

## 太长不看版

- • Hermes 的内置记忆使用 `MEMORY.md` 和 `USER.md` 两个小型 Markdown 文件，而非 SQLite；启动新会话时，它们会作为 frozen snapshot 注入系统提示词。
- • Hermes 的 SQLite + FTS5 主要服务 `session_search` ，也就是跨会话历史检索。它更像档案室，不是随身备忘录。
- • Hermes 的外部 memory provider，比如 Honcho、Mem0、Hindsight、Supermemory，是叠加能力，不会替换内置的 `MEMORY.md` / `USER.md` 。
- • Hermes 最值得拆的是 `skill_manage` 。它把"这类任务以后怎么做"写成 skill，并允许后续 patch、edit、delete。这属于 procedural memory，和事实记忆分属两层。
- • 这套学习机制没有写成"达到阈值就必然写 skill"的硬规则。源码里更像一套 best-effort review：主任务先完成，后台再判断是否有东西值得保存。
- • OpenClaw 现在也有 Honcho、memory\_search 和 experimental dreaming。我不太建议再把它简单理解成静态 Markdown。
- • 如果 OpenClaw 也把自动 skill 沉淀、触发、复用、修补、安全扫描做成系统主路径，它在 learning loop 这一层会非常接近 Hermes。后面的差异，就会从"有没有"变成"这件事被放在运行时的什么位置"。

---

## 先把"记忆"拆开

很多 Agent 对比会卡住，是因为大家把三件事都叫"记忆"：

第一种是事实记忆。

比如用户偏好、项目路径、常用命令、某台服务器的特殊配置、某个项目的测试方式。这类信息不一定来自一段完整会话，但下次继续工作时最好一直可见。

第二种是会话检索。

比如"上次我们怎么修的那个 Docker 网络问题""上个月聊过的报价方案在哪里""之前那次 code review 改了什么"。这类信息不适合每次都塞进上下文，但需要时又要能搜回来。

第三种是过程记忆。

这就更进一步了。它记录的对象，从用户偏好和历史对话，转向了"这类事情可以怎么做"。

比如一个复杂 PR review 的检查流程、一个部署失败后的排查顺序、一个固定格式的数据清洗工作流。

事实记忆回答的是"我是谁、环境是什么"。会话检索解决的是"上次聊过什么、踩过哪些坑"。过程记忆再往前走一步： **这类事下次应该怎么做。**

Hermes Agent 把这三层分开了。这个分层，比单独讨论"有没有记忆"更值得展开。

图 1：Hermes 的三层学习机制

![](https://mmbiz.qpic.cn/sz_mmbiz_png/Fnx2G2wYdEK7YV9lh8ibHJtLRcTGmMNEnbYCKNqukbKlFnkETPSfUOYyS3XibUicjQAEtxCkExRmAoXpHAfzFRC1W534jb1rKYIaN0c2qg9T5M/640?wx_fmt=png&from=appmsg)

*图 1：事实、历史、流程，是三种不同的长期资产。*

这张图的重点不在于说 Hermes 独占这些能力。

OpenClaw 也在做记忆检索，也能接 Honcho，也有实验性的 dreaming。

区别在于，Hermes 把"过程记忆"这一层提到了很显眼的位置，并把它写进了工具、提示词和后台 review 流程里。

---

## 第一层：小而硬的事实记忆

先补一个容易混淆的点： **Hermes 的内置长期记忆并不放在 SQLite。**

官方 memory 文档和源码 `tools/memory_tool.py` 都写得很清楚。Hermes 的 built-in memory 由两个文件组成：

- • `~/.hermes/memories/MEMORY.md`
- • `~/.hermes/memories/USER.md`

`MEMORY.md` 主要放 agent 的个人笔记，比如环境事实、项目约定、工具 quirks、学到的经验。

`USER.md` 主要放用户画像，比如偏好、沟通风格、预期和工作习惯。

默认容量也很克制：

- • `MEMORY.md` ：2,200 字符，大约 800 tokens。
- • `USER.md` ：1,375 字符，大约 500 tokens。

它更像一张很短的工作卡片，而不是一个"大而全"的知识库。

源码里有个细节很能说明它的取舍：这两个文件在会话开始时被加载成 frozen snapshot。 `MemoryStore.load_from_disk()` 方法执行完毕后，会立刻把当前内容捕获到 `_system_prompt_snapshot` 字典里。会话中途如果写入 memory，会立刻落盘，但不会改变当前会话的 system prompt。

原因也很工程化：保护 prompt cache。

如果每一轮都改 system prompt，缓存前缀就会不断失效，成本和延迟都会被放大。Hermes 的做法是：本轮先保持系统提示稳定，新的记忆等下一轮新会话再进入主上下文。

这个设计挺克制。

它的选择是：不把所有历史都塞进"长期记忆"，把最该一直带着的事实压到一个很小的空间里，其余的交给别的机制。

源码里还有几个小细节，也能说明这层 memory 的定位。

先看安全扫描。 `tools/memory_tool.py` 定义了一组 `_MEMORY_THREAT_PATTERNS` ，在写入 memory 前，会扫描不可见 Unicode 字符和常见 prompt injection / exfiltration 模式，比如 `ignore previous instructions` 、 `curl` 带密钥环境变量、 `cat .env` 读取凭据等。原因很直接：这些 memory 以后会进入 system prompt，写进去的东西不只是普通笔记。

再看写入方式。 `MemoryStore._write_file()` 没有简单用 `open("w")` 覆盖文件。它先写到同目录下的临时文件（ `tempfile.mkstemp` ），再调用 `os.fsync()` 确保数据落盘，最后用 `os.replace()` 做原子替换。读写互斥则靠 `_file_lock()` 用 `fcntl.flock` 获取排他锁。换句话说，Hermes 在保护这个小文件时，用的是运行时资产的规格，而非普通日志的规格。

第三个是工具 schema 里的引导。 `MEMORY_SCHEMA` 的 description 明确告诉模型保存的优先级：用户纠正和偏好 > 环境事实 > 程序性知识。同时明确写了"Do NOT save task progress, session outcomes, completed-work logs"。这条边界很重要：进展和状态不进 memory，留在 transcript 里，需要时用 `session_search` 找回来。

---

## 第二层：SQLite + FTS5 是档案室

那 SQLite + FTS5 在 Hermes 里干什么？

放在当前源码里看，答案主要是 session search。

`hermes_state.py` 里定义了 `~/.hermes/state.db` ，使用 WAL 模式支持并发读写。数据库里存 sessions、messages、model config 等信息。它还创建了一个 `messages_fts` 的 FTS5 virtual table，用来对消息内容做全文检索。数据库还通过 trigger 自动维护 FTS 索引：每次 `INSERT` 、 `DELETE` 、 `UPDATE` messages 表，都会同步更新 `messages_fts` 。

`tools/session_search_tool.py` 里的流程也很直接：

1. 1\. 用 FTS5 在历史消息里找匹配内容，一次最多拉 50 条结果。
2. 2\. 把子会话沿 `parent_session_id` 链解析回根会话，按 session 聚合，排除当前会话。
3. 3\. 读取对应会话的完整对话，格式化成可读 transcript。
4. 4\. 用 `_truncate_around_matches()` 截断到匹配点附近，默认 100k 字符窗口。截断策略会优先找全文短语匹配，再找多词近邻共现（200 字符内），最后回退到单词位置，选覆盖匹配位置最多的窗口。
5. 5\. 并行调用快速模型做 focused summary（ `asyncio.gather` ），再返回给主 Agent。

这个工具还有一个容易被忽略的模式：不传 query 时，它会走 recent sessions，返回最近会话的标题、预览和时间戳，不调 LLM，零成本。传 query 时，才进入关键词搜索和摘要召回。

工具说明里还专门提醒了一句：FTS5 默认更接近 AND 语义，宽泛召回时更适合用 `OR` 连接关键词。如果宽查询没有结果，可以把关键词拆成多个独立搜索并行跑。这个细节很工程化：Hermes 这里说的 recall，落下来就是一套可调的历史检索工具。

所以这里的 SQLite + FTS5，不能当成 `MEMORY.md` / `USER.md` 的替代品。

它解决的是另一类问题：

**当用户说"上次那个问题""我们之前聊过的方案""你还记得那次怎么修的吗"，更稳的做法，是让 Agent 去历史会话里搜，少靠猜，也少让用户重讲一遍。**

这就像档案室。

档案室很重要，但它不等于随身备忘录。人也不会把档案室每个柜子都背在身上。

Hermes 的 memory guidance（ `prompt_builder.py` 里的 `MEMORY_GUIDANCE` ）也在区分这件事：用户偏好、环境事实、稳定约定进 memory；任务进展、临时 TODO、完成记录更适合留在历史 transcript 里，需要时再用 `session_search` 找回来。

发现了新的做事方法？那就保存成 skill，而不是继续塞进 memory 或留在 transcript 里等下次搜。

这个边界很容易被忽略。

很多人说"Hermes 记忆靠 SQLite + FTS5"，其实是把内置事实记忆和历史会话检索混在一起了。分开看才能看到 Hermes 到底在做什么取舍。

---

## 第三层：更值得细看的是过程记忆

Hermes 最有意思的地方，在 skill。准确说，是 `skill_manage` 。

`tools/skill_manager_tool.py` 开头的说明很直白。我转述一下：skills 是 agent 的 procedural memory，用来保存某类任务该怎么做； `MEMORY.md` 、 `USER.md` 更偏宽泛的声明式信息，skills 则更窄、更可执行。

翻成工程语言就是： **skill 记录的不是偏好或聊天记录，记录的是做事方法。**

它捕获的是某一类任务的可复用流程。比如：

- • 什么条件下适合触发这个 workflow；
- • 具体步骤是什么；
- • 常见失败模式有哪些；
- • 怎么验证结果；
- • 哪些命令、脚本、参考资料可以复用。

Hermes 的 `skill_manage` 支持这些动作：

- • `create` ：创建新的 skill，需要包含 YAML frontmatter（name + description）和 markdown 正文；
- • `patch` ：做局部修补，用 old\_string / new\_string 精确定位替换；
- • `edit` ：完整重写 SKILL.md 内容，适合大改；
- • `delete` ：删除整个 skill 目录；
- • `write_file` ：给 skill 添加参考文件、模板、脚本或资产，路径需要落在 `references/` 、 `templates/` 、 `scripts/` 、 `assets/` 四个子目录下；
- • `remove_file` ：移除支持文件。

我更在意的是，它没有只把工具暴露出来。

`agent/prompt_builder.py` 里的 `SKILLS_GUIDANCE` 也很直白。大意是：复杂任务完成后、棘手错误修好后、发现非平凡 workflow 后，可以把这条路径保存成 skill，下次复用；如果用 skill 时发现它过时、不完整或错误，就应该马上 patch。

这两句话的信息密度很高。第一句划了创建阈值：5 次以上工具调用的复杂任务、棘手错误、非平凡工作流。第二句提醒了另一个风险：过时的 skill 不是无害的旧文件，它会误导 Agent。

`run_agent.py` 里还有 skill nudge 和 background review。实现上，memory 和 skill 的触发机制是分开的：

- • **Memory review** 按用户对话轮次计数（ `_turns_since_memory` ），默认每 10 轮触发一次。
- • **Skill review** 按单轮内的工具调用迭代次数计数（ `_iters_since_skill` ），默认累计 10 次迭代后，在本轮主任务结束时触发。

两者的阈值都通过配置文件可调。

但这里要说准确一点： **源码里没有硬编码"满 10 次就一定写 skill"。**

触发条件满足后，系统在 `_spawn_background_review()` 里 fork 一个安静的 review agent。这个 review agent 共享主 agent 的 `_memory_store` ，但运行在独立线程中，stdout 和 stderr 都重定向到 `/dev/null` ，最多跑 8 轮迭代。

源码里有三个 review prompt，按触发条件组合选取：

如果只触发了 memory review，用 `_MEMORY_REVIEW_PROMPT` ，重点看用户有没有透露偏好、人设、工作风格。

如果只触发了 skill review，用 `_SKILL_REVIEW_PROMPT` 。我转述一下这个 prompt 的重点：回看刚才的对话，判断是否用了一个非平凡方法，是否经历了试错、改道，或者用户是否明确期待另一种做法；如果有可复用经验，就考虑创建或更新 skill。

如果两者同时触发，用 `_COMBINED_REVIEW_PROMPT` ，一次性评估两件事。

如果回看后认为没有值得沉淀的东西，review agent 只需说 `Nothing to save.` 然后结束。

review 完成后，系统会扫描 review agent 的消息历史，提取成功的工具操作（created、updated、added、removed），生成一行紧凑的摘要通知用户，比如 `💾 Memory updated · Skill 'docker-network-fix' created` 。

放在产品层面看，这个设计思路很清晰：经验沉淀是好事，但不能抢主任务的注意力。先把活干完，复盘的事后台跑。

另外，agent 创建 skill 时也有防线。 `skill_manager_tool.py` 引入了 `tools.skills_guard` 做安全扫描。每次 `create` 、 `edit` 、 `patch` 、 `write_file` 操作完成后，都会调用 `_security_scan_skill()` 对整个 skill 目录做检查。如果安全扫描判定为阻止（ `should_allow_install` 返回 False），写入会被回滚： `create` 会删除整个目录， `edit` 和 `patch` 会恢复原始内容， `write_file` 会恢复或删除新文件。

这也是 Hermes 和"给一个 skills 文件夹自己写"之间的差别。 **它把"经验能不能变成可维护流程"这件事放进了 Agent Runtime，从创建、修补到安全审查，都有工具兜着。**

当然，这里也要讲边界。

自动生成 skill 不保证一定生成好 skill。

错误经验也可能被固化。过拟合到某个具体项目的流程，也可能在别的上下文里误导 Agent。所以 Hermes 的 schema 里也强调：简单一次性任务无需保存（"Skip for simple one-offs"）；创建和删除要先跟用户确认（"Confirm with user before creating/deleting"）；skill 如果过时要立刻修。

坦率说，离"魔法"还很远。更像是给 Agent 加了一套"写工作笔记、复盘、修订 SOP"的机制。但对于一个连续跑几十轮任务的 Agent 来说，有没有这套机制的体感差异可能比换一个模型还大。这个判断我还在验证中。

---

## Honcho、Mem0 这些外部记忆算哪一层？

Hermes 还有一个容易被混淆的点：外部 memory provider。

官方文档里列了多个 external memory provider，包括 Honcho、OpenViking、Mem0、Hindsight、Holographic、RetainDB、ByteRover、Supermemory。

`agent/memory_provider.py` 的文件头注释把设计边界写得很清楚：built-in memory 永远是第一层 provider，不能被移除；Honcho、Hindsight、Mem0 这类 external provider 是 additive，不会禁用内置 memory；同一时间只运行一个外部 provider，避免工具 schema 膨胀和多个记忆后端互相冲突。

再往 `agent/memory_manager.py` 和 `run_agent.py` 里看，外部 provider 的接入方式也分得比较细。

它会在 tool loop 前对当前用户消息做一次 `prefetch_all()` ，收集所有 provider 的召回结果。召回内容经过 `sanitize_context()` 清洗（防止 `</memory-context>` 之类的 fence-escape），再用 `build_memory_context_block()` 包装成带系统提示的隔离块，注入到用户消息旁边，而不是改 system prompt。主响应结束后，再调用 `sync_all()` 把这一轮问答同步到外部记忆系统，并用 `queue_prefetch_all()` 为下一轮做预取排队。

这个设计和内置 memory 的 frozen snapshot 逻辑是同一个方向：system prompt 尽量保持稳定，动态召回放在更靠近当前 turn 的位置。

`MemoryProvider` 的生命周期钩子也值得留意。除了核心的 `prefetch` / `sync_turn` ，它还定义了： `on_turn_start` （每轮开始时传入 turn 编号、剩余 tokens 等运行时信息）、 `on_session_end` （会话结束时做抽取）、 `on_pre_compress` （上下文压缩前抢救即将被丢弃的消息）、 `on_memory_write` （镜像内置 memory 的写入）、 `on_delegation` （父 agent 观察子 agent 完成的任务）。这些钩子说明外部 provider 不只是一个被动的存取接口，它可以参与 Agent Runtime 的多个关键节点。

所以 Honcho、Mem0 并不替代 `MEMORY.md` / `USER.md` 。

它们更像增强层。

以 Honcho 为例，Hermes 官方文档把它描述为 AI-native memory backend，重点是 dialectic reasoning、user modeling、semantic search 和 persistent conclusions。

也就是说，它更擅长从长期对话里抽取用户模式、偏好、目标、沟通风格。

这和本地小型 memory 的关系是叠加，不是替换。

可以这样理解：

- • `MEMORY.md` / `USER.md` ：每次启动都要带上的短卡片。
- • `session_search` ：需要时去翻历史档案。
- • Honcho / Mem0：外置记忆后端，做更深的用户建模或语义召回。
- • skills：可复用的做事方法。

混在一起讨论很容易把差异磨平。拆开看，每一层的存储、召回和更新逻辑都不一样。

---

## 如何和 OpenClaw 结合，关键看放在哪一层

现在回到评论区那个问题。

如果给 OpenClaw 加上一套自我总结、自动沉淀 skills 的机制，它和 Hermes 还有什么区别？更具体一点：这套学习机制该怎么和 OpenClaw 结合？

我现在更倾向于这样回答： **要看它被放到哪一层。**

图 2：OpenClaw 结合自总结机制，关键看运行时位置

![](https://mmbiz.qpic.cn/sz_mmbiz_png/Fnx2G2wYdEJgTQTaX9ibibiadVY7XQjxFm3S5sDB5jgHPlAC9PVHZyuv5Pd36gBpGxoz8PcW87B2DjDkZ1zEyiapEp8jI7TVdFqyXicVt4OWibVIk/640?wx_fmt=png&from=appmsg)

*图 2：边界不在于能不能写总结文件，而在于经验有没有进入运行时主路径。*

如果只是每天跑一个 cron job，把昨天的会话总结成几个 Markdown 文件，这会有帮助，但更接近经验归档。

如果放到 OpenClaw 里，我会先把它想成一个渐进式改造，而不是“把 Hermes 的机制搬过去”。OpenClaw 现有的 Gateway、workspace、memory\_search、Honcho 和 experimental dreaming 已经能承接不少长期信息；可能还需要补的，是把“经验归档”再往前推一步，推到 Agent 运行时能创建、检索、修补和审查 skill 的位置。

Hermes 仓库里有一个细节可以作为旁证：它已经提供了 `openclaw-migration` optional skill，也有 `hermes claw migrate` 这条迁移路径。迁移文档里写得很细，OpenClaw 的 `MEMORY.md` 、 `USER.md` 、 `SOUL.md` 、命令 allowlist、workspace instructions 和多处 skills 来源，都可以映射到 Hermes 对应位置；OpenClaw 的 workspace skills、 `~/.openclaw/skills/` 、 `~/.agents/skills/` 、 `workspace/.agents/skills/` 会被导入到 `~/.hermes/skills/openclaw-imports/` 。

这说明两边在“长期资产”这层确实有相当多可以对齐的地方。

但迁移文档也很坦率：OpenClaw 的一些 memory backend、skills registry、plugins、hooks、multi-agent list、channel bindings，会被归档到 migration archive 里留给人工复核，而不是直接变成 Hermes 里的同构配置。

我们可以拆成两步看。

第一步是资产迁移：已有的 memory、user profile、workspace rules、skills 可以先进入可读、可审查的位置。这里重点不是追求一次性自动转完，而是保留迁移报告、冲突处理和 skipped items，知道哪些东西没有等价物。

第二步才是运行时学习：OpenClaw 如果要补自总结 skills，最好别只做离线归档，而要明确 skill 的所有权、加载路径、修改权限和安全扫描。Hermes 的 skills 文档里有个可借鉴的边界：外部 skills 目录可以被扫描进来，但默认是 read-only；agent 真正创建或编辑 skill 时，写回 `~/.hermes/skills/` 这个主目录。这个设计未必能直接照搬到 OpenClaw，但“共享来源”和“可写主目录”分开，是一个值得保留的边界。

如果进一步做到这些事：

- • 任务结束后自动判断这次经验是否值得沉淀；
- • 区分事实、历史会话和过程，不把所有东西都塞进一个 memory 文件；
- • 给 skill 提供 create、patch、edit、delete 的工具面；
- • 把"事实进 memory，历史靠 search，流程进 skill"写进 Agent guidance；
- • skill 过时或跑错时，允许 Agent 立即 patch；
- • agent-created skills 走安全扫描和权限边界；
- • 下次遇到同类任务时，skill 能被检索、加载、执行并持续修正。

做到这里，OpenClaw 和 Hermes 在 learning loop 这一层就会非常接近。

这反而说明，大家开始往同一个方向收敛：Agent 很难长期停留在每次从零开始的状态。

差异会从"有没有"变成"系统重心在哪里"。

OpenClaw 现在的强项，仍然更偏 gateway / control / memory plane：多入口、多会话、插件、workspace、memory search、Honcho、experimental dreaming。

Hermes 的强项，是把 self-improving runtime 这条线做得更集中：会话检索、curated memory、skill\_manage、后台 review、外部 memory provider，被组织成一条更明确的学习链路。

打个不太严谨的比方：OpenClaw 更像一个记性越来越好的总调度，Hermes 更像一个干完活会自己写复盘文档的执行者。这个比方不够严格，但能说明两者的厚度确实长在不同层上。

---

## 从功能对比，回到长期资产

Hermes 值得借鉴的地方，不只是"用了 SQLite""接了 Honcho""兼容 agentskills.io"这些功能点。功能层面都可以复刻。

我更想留下来的，是它的分层方式，以及它在几个容易被忽略的地方做的选择。

**长期信息要拆开看。** 事实、历史、流程是三种不同资产。事实太多会污染上下文，历史每次都带会浪费 token，流程如果不维护会把错误经验固化成错误 SOP。它们的存储、召回和更新频率都不一样，混在一起管理迟早会出问题。

**过程记忆要有生命周期。** 一个 skill 被创建以后，不能默认永远正确。它需要能被 patch、能被替换、能被删除，也需要携带验证步骤和失败模式。这比"自动总结成 Markdown"更重要，也更难做好。

**学习闭环只靠模型自觉，通常不够稳。** 如果只是提示词里写一句"请总结经验"，效果不会稳定。Hermes 把这件事落到了工具、配置、nudge、后台 review 和文件结构里。至于效果到底怎么样，说实话我目前还没有足够长的使用周期来下判断，只能说从工程设计上看方向对了。

---

## 把几条线索接起来

我更愿意把这次评论区的问题，放回过去一段时间一直在拆的那条线里看。

写《 [2026 AI Memory 最新综述](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650408756&idx=1&sn=03188bfa5d034a1b5ca0347c72b673fd&scene=21#wechat_redirect) 》时，4W Memory Taxonomy 给我的提醒是：memory 不是一个单词，而是一组设计决策。什么时候写、写什么、怎么更新、哪条该召回，这些问题不分开，后面很容易把"记忆"写成一个大口袋。

写 [Prompt Cache](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650408819&idx=1&sn=f0c65045a197c9a3a6ca5b19faeae4da&scene=21#wechat_redirect) 那篇时，关注点又往前走了一步：上下文不是越多越好，稳定前缀、动态上下文、按需检索，都会反过来塑造 Agent 的架构。Hermes 把 `MEMORY.md` / `USER.md` 做成 frozen snapshot，其实也落在这条线上。

再看 [Skills](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650408639&idx=1&sn=ad325d5fa3dd0e112d62b0e34ea3c48a&scene=21#wechat_redirect) 、 [Codex 仓库](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650408870&idx=1&sn=ba53595a44ab55396b36795fbc78791b&scene=21#wechat_redirect) 和 [Claude Code 长任务 Runtime](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650408950&idx=1&sn=8c14e4b7726dd478644e0a8e1acfbad4&scene=21#wechat_redirect) 那几篇，主线也很接近：团队经验不能只停在口头总结里。它可以沉到 Skill，沉到仓库规则，沉到 CI 和发布流程，也可以沉到 Runtime 里的后台 review、session search 和记忆刷新。

所以这次再看 [Hermes](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650408990&idx=1&sn=6d9fc504d19611e05b4fa53b1f6f3368&scene=21#wechat_redirect) ，我不太想把它写成"又一个记忆功能"。更稳妥一点，它把几件之前分开讨论的事放到了一条链路里：

- • 事实放进小而稳定的 memory；
- • 历史留在 transcript 和 FTS5 检索里；
- • 做事方法沉到 skill，并允许后续修补；
- • 外部 memory provider 只作为增强层，不替代内置 memory。

前几天写 [Coding Agent Harness](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650408973&idx=1&sn=e147f34daa2d9e3ea431d985b08486e5&scene=21#wechat_redirect) 时，我更关心的是：模型能力之外，哪些工程层会决定 Agent 能不能稳定协作。上下文、工具、状态、权限、恢复机制，这些看起来不如模型名字显眼，但它们经常才是体感差异的来源。

后来单独整理学习 [Hermes](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650408990&idx=1&sn=6d9fc504d19611e05b4fa53b1f6f3368&scene=21#wechat_redirect) ，我把它理解成一个偏执行与学习的 Agent Runtime。它不只是在前台完成任务，还会在后台 review 里判断这次任务有没有可沉淀的路径。

昨天把 [OpenClaw 和 Hermes 放在一起看](https://mp.weixin.qq.com/s?__biz=MzAwNjQwNzU2NQ==&mid=2650409010&idx=1&sn=04b9836fa07ff877c459e300707ddcff&scene=21#wechat_redirect) ，主线是 Gateway 控制面和学习型 Runtime 的差异。OpenClaw 更厚在入口、会话、设备和治理；Hermes 更厚在执行循环、会话检索、skill 沉淀和外部记忆 provider。

评论区这个问题，正好把这条线又往前推了一步：

**如果 OpenClaw 也有自总结 skills，差异还剩什么？**

图 3：近期几篇文章串起来的 Agent Runtime 主线

![](https://mmbiz.qpic.cn/mmbiz_png/Fnx2G2wYdEKYMgicgwI9q77Wpp0u9EngBaW7sfgqicn8682SUGtdOfnXpkV2OycwzIiajL6t5QP9khEat1Gxgt48BfGyO5kSliaaTLWJOQK64ps/640?wx_fmt=png&from=appmsg)

*图 3：从 Harness 到 Runtime，再到长期资产，讨论对象其实在逐步下沉。*

沿这条线看，我现在会把问题再压小一点：

差异不只在"有没有总结"，也在"总结出来的东西被系统当成什么"。

如果总结只停在文件层，它更像日志和归档。

如果总结能被区分成事实、历史和流程，能进入 memory、session\_search 和 skill\_manage 各自的位置，还能在后续任务中被触发、复用、修补和删除，它就开始接近运行时资产。

Hermes 的源码让我愿意继续拆，原因就在这里。

我不会说它是最完整的 Agent 框架，也不会说只有它在做记忆和学习。但它提供了一个比较清晰的样本： **把 Agent 的长期资产分成事实、历史和流程，再分别给它们设计存储、召回和更新机制。**

这个说法比"AI 有记忆了"更具体，也比"它会越来越懂用户"更接近工程实际。

当然，"分层了"不等于"分好了"。自动生成的 skill 质量如何、过拟合怎么控制、跨项目迁移 skill 会不会出问题，这些我暂时还没有答案。后面如果有更长周期的使用体感，再补一篇。

后续我们应该这样来看：

有价值的 Agent 记忆，不只是记得用户说过什么。它还要能区分哪些该长期带着，哪些该按需检索，哪些做事方法该沉淀成下一次可以复用的流程。怎么把这件事做稳，可能是接下来一段时间 Agent 工程里值得继续观察的方向。

---

## 参考资料

- • Hermes Agent GitHub README：https://github.com/NousResearch/hermes-agent
- • Hermes Memory 文档：https://hermes-agent.nousresearch.com/docs/user-guide/features/memory
- • Hermes Skills 文档：https://hermes-agent.nousresearch.com/docs/user-guide/features/skills
- • Hermes Sessions 文档：https://hermes-agent.nousresearch.com/docs/user-guide/sessions
- • Hermes Memory Providers 文档：https://hermes-agent.nousresearch.com/docs/user-guide/features/memory-providers
- • Hermes Honcho 文档：https://hermes-agent.nousresearch.com/docs/user-guide/features/honcho
- • OpenClaw Honcho Memory 文档：https://docs.openclaw.ai/concepts/memory-honcho
- • OpenClaw Memory Search 文档：https://docs.openclaw.ai/concepts/memory-search
- • OpenClaw Dreaming 文档：https://docs.openclaw.ai/concepts/dreaming
- • OpenClaw Skills 文档：https://docs.openclaw.ai/tools/skills

---

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

继续滑动看下一个

架构师

向上滑动看下一个

微信扫一扫  
使用小程序

： ， ， ， ， ， ， ， ， ， ， ， ， 。 视频 小程序 赞 ，轻点两下取消赞 在看 ，轻点两下取消在看 分享 留言 收藏 听过