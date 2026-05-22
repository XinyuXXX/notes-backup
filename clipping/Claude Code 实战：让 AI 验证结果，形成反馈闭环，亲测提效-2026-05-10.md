---
title: Claude Code 实战：让 AI 验证结果，形成反馈闭环，亲测提效
author: 彭少
source: https://mp.weixin.qq.com/s/EgpEGGU2-hxPq6xkUVJGFA
clipped: 2026-05-10
---

彭少 彭少

在小说阅读器读本章

去阅读

**点击上方卡片关注我**

**设置星标 学习更多AI出海知识**

Claude 代码能力毋庸置疑还处于大哥级别，那如果再给 Claude 一个验证工作的方式，让它有一个反馈闭环，最终结果的质量可以提升 2-3 倍。

算是一个提效的小技巧。

比如用 Chrome 扩展测试每一个改动，打开浏览器、测试 UI、发现问题就迭代修复，直到代码正常工作。

如果之前只是把 Claude 当作一个写代码的工具，写完代码自己测试。现在可以换个思路，想办法让 Claude 自己验证，形成闭环。

## 为什么验证这么重要

平常经常AI编程的朋友应该有体会，它会很自信地给你一段代码，但这段代码可能有 bug、可能跑不通、可能和项目的其他部分不兼容。

如果没有验证，这些问题要等你手动测试的时候才能发现。发现问题再让 Claude 修，修完再测试，来回这几轮测试的时间也挺浪费的。

如果Claude 写完代码自己跑一下测试或者检查一下效果，发现问题自己修，修到对了再告诉你。你拿到的是已经验证过的结果，会比较省心，体验感也会更好。

![](https://mmbiz.qpic.cn/mmbiz_png/tT0WLTsUt8yrJDayh7R8iaNGwExme2oC4HAqMQJF4qMuUPNZeKkibadluqVlkKjVaQoz17ia3OvzmEtA45fzuIpeQ/640?wx_fmt=png&from=appmsg)

## 验证方式分享

不一定适合每一种情况，大家常用什么方式来检验AI编程的结果，欢迎留言分享哈。

比如

**运行测试** ：最直接的验证方式。如果项目有单元测试，跑一遍测试就知道代码对不对。适合后端逻辑、工具函数这类有明确输入输出的代码。

**构建检查** ：运行 build 命令检查是否能成功编译。可以发现类型错误、语法错误、依赖问题。适合几乎所有代码改动。这种是比较基础的。

**Lint 检查** ：运行 eslint/prettier 检查代码规范。可以发现风格问题、潜在的代码质量问题。

**浏览器测试** ：用 Playwright 或 Claude in Chrome 打开浏览器，实际操作页面验证功能。适合前端 UI 改动。

**手动确认** ：有些东西没法自动验证，比如 UI 的视觉效果、用户体验。这些就必须要自己使用感受一下了。

关键是根据任务类型选择合适的验证方式，而不是一刀切。

## 方式一：直接下达指令

最简单的方式是在给 Claude 的指令里直接说明验证要求。

比如：

```
帮我实现用户注册功能。

完成后请验证：
1. 运行 npm run test 确保测试通过
2. 运行 npm run build 确保构建成功
3. 如果测试失败，分析原因并修复

最后告诉我验证结果。
```

这种方式灵活，可以根据具体任务定制验证内容。缺点是每次都要写，容易忘。

## 方式二：用 Subagent 验证

把验证逻辑封装成 Subagent，需要的时候调用。 [Claude Code 进阶玩法之 Subagent，给自己配一个专属 AI 助手团队](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247489598&idx=1&sn=a256b7856c1c3b48b478ae93a8ea5e4b&scene=21#wechat_redirect)

前面介绍过 verify-work 和 verify-ui 两个代理。verify-work 是通用的验证代理，能根据文件类型自动选择验证方式；verify-ui 专门做前端 UI 测试，可以用 Playwright 打开浏览器验证。

使用的时候可以说：

```
帮我实现这个功能，完成后用 verify-work 验证一下
```
![](https://mmbiz.qpic.cn/mmbiz_png/tT0WLTsUt8yrJDayh7R8iaNGwExme2oC4Fg6GjGfXpt7oGUtDnCnPUsZa0mCmyTR7uAcmTnCzFFDy9qzzp7jeQQ/640?wx_fmt=png&from=appmsg)

或者功能实现完了之后单独调用：

```
用 verify-ui 测试一下刚才改的页面
```

Subagent 的好处是验证逻辑固化了，不用每次写。而且验证在独立的上下文里执行，不会把主对话搞得很长。

## 方式三：Stop Hook 自动验证

如果想让每次 Claude 完成都自动验证，可以用 Stop Hook。 [玩转 Claude Code Hooks：让自动化渗透到每个环节](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247489503&idx=1&sn=b81277c62e501d497b7f621e3a726b34&scene=21#wechat_redirect)

```
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cd /你的项目 && npm run test 2>&1 | head -50"
          }
        ]
      }
    ]
  }
}
```

每次 Claude 完成响应，自动跑测试。如果测试失败，Claude 能看到失败信息，可以继续修复。

**这种方式最自动化，但有个问题：不是每次响应都需要验证。** 你可能只是问个问题，没必要跑测试。所以我个人更倾向于用 Subagent，可以控制什么时候验证。

如果你的工作流是每次改动都要验证，Stop Hook 会很方便。如果验证需求不固定，Subagent 更灵活。

## 方式四：浏览器自动化测试

前端 UI 的验证需要实际看页面效果。

Claude Code 支持的浏览器自动化方式：

**Playwright MCP** ：通过 MCP 协议连接 Playwright，可以打开浏览器、导航页面、点击元素、填写表单、获取页面截图。适合 API 用户，不需要 Claude 账号，就像我和我们团队现在一直都在用的 **aigocode.com** 中转。

![](https://mmbiz.qpic.cn/mmbiz_png/tT0WLTsUt8yrJDayh7R8iaNGwExme2oC4642WxbCpcNr7Z1zSUphA0V7v8x1TD7diaugZ5VnbE7cYeaZ65Xu6XUw/640?wx_fmt=png&from=appmsg)

**Claude in Chrome** ：Anthropic 官方的 Chrome 扩展，Claude Code 可以直接控制你的 Chrome 浏览器。好处是可以使用你登录的账号状态，测试需要登录的页面很方便。需要开通会员。

我用 Playwright 比较多。

![](https://mmbiz.qpic.cn/mmbiz_png/tT0WLTsUt8yrJDayh7R8iaNGwExme2oC4Z99EuE2QttwMxml4MnXZzFicI8E43z116McvIcGXDS3cLhC68mVrGJQ/640?wx_fmt=png&from=appmsg)

日常开发主要用 verify-work 代理。它能根据文件类型自动判断用什么验证方式，大部分情况够用。

前端 UI 改动单独调用 verify-ui，让 Playwright 打开浏览器实际看一下效果。

特别重要的改动，在指令里明确验证要求。

Stop Hook 我目前只用来发通知，没有用来自动跑测试。主要是觉得不是每次响应都需要验证，手动控制更灵活。

整个逻辑就是这样的：

```
写代码 → 验证 → 失败 → 分析原因 → 修复 → 再验证 → 成功
```
![](https://mmbiz.qpic.cn/mmbiz_png/tT0WLTsUt8yrJDayh7R8iaNGwExme2oC4mJEh0BjDT6rbssXY7DEvR5sKaIHGN7bhMfqvNeXyENhDW8jRvbx53g/640?wx_fmt=png&from=appmsg)

关键是把"失败 → 修复 → 再验证"这个循环自动化。

## 小结

没有验证的时候，Claude 像个只管写不管对的"写手"。有了验证，Claude 越来越有工程师的意思了。

具体用哪种验证方式不重要，重要的是形成闭环：写完 → 验证 → 发现问题 → 修复 → 再验证。这个循环跑起来，产出的代码质量会明显提升。

如果你现在用 Claude Code 还没有验证这个环节，建议从最简单的开始，就加一句指令 完成后跑一下测试。再考虑用 Subagent 或者 Hook 把它自动化。

欢迎关注，这个账号还会持续分享更多出海工具、实战经验、踩坑记录。

关于编程工具使用，推荐第三方共享平台 aigocode.com，支持 Codex / Claude Code / Gemini 3 三大顶尖模型。https://aigocode.com/invite/K68YB6K7 通过这个链接注册可以获得 5% 首单充值福利！！

---

扫码或微信搜索 257735 添加微信，回复【出海资料】即可免费领取《AI 编程出海蓝皮书》，一次读懂普通人也能启动的出海路径。

如果你想进一步系统学习、实操出海项目，👉 点击了解详情： [推荐我的AI编程出海训练营！](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247489358&idx=1&sn=a9b44717101426cd166521ef1cfef2ec&scene=21#wechat_redirect)

![](https://mmbiz.qpic.cn/mmbiz_png/tT0WLTsUt8w7pvic9YI1QDL3x9GQKwrkJKuF4hF1ka4rib8nJfuy0uhZIFD6kFxlQhVRZsnwvPs39BhG4EAKUqzA/640?wx_fmt=png&from=appmsg)

**[从海外公司注册到 Stripe 收款，跑通了出海收付款全流程（实操分享）](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247489551&idx=1&sn=08058b274add835f37b3374fa43b6757&scene=21#wechat_redirect)**

**[出海效率提升：一个 Skill 让 Claude Code 接入你的 NotebookLM 知识库](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247489410&idx=1&sn=25390213ebfb7f8e8ee741ba78bf0937&scene=21#wechat_redirect)**

**[出海建站必备：告别AI味，这两个页面设计 Skills 太牛了！](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247489451&idx=1&sn=0447e337cef1e12f577b2fed72048cad&scene=21#wechat_redirect)**

**[玩转 Claude Code Hooks：让自动化渗透到每个环节](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247489503&idx=1&sn=b81277c62e501d497b7f621e3a726b34&scene=21#wechat_redirect)**

**[出海需求挖掘：如何用 GitHub 找到可做的 AI 产品方向？](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247487737&idx=1&sn=48dd745fd45254d0eda9f7ca8838a5a9&scene=21#wechat_redirect)**

**[出海工具全集：覆盖 9 大类别，收藏这一篇就够了](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247488151&idx=1&sn=b94bea4e18d162a0c6e8d542a6941555&scene=21#wechat_redirect)**

**[出海网站实战：Stripe 支付接入，从 0 到收款全流程](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247488496&idx=1&sn=ea69777b985c23576fe59777ab1f0da9&scene=21#wechat_redirect)**

**[出海必备：一天搞定5张港卡，我的香港卡办理全攻略](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247488697&idx=1&sn=1d04e1a522668308397a823579a68303&scene=21#wechat_redirect)**

**[彭涛：从百万自媒体到 AI 编程出海，我的 2025 破局与重生](https://mp.weixin.qq.com/s?__biz=Mzg3NzU2NjY3OQ==&mid=2247489360&idx=1&sn=ef5a265b751b537df43b60d4e32130aa&scene=21#wechat_redirect)**

阅读原文

继续滑动看下一个

彭少

向上滑动看下一个

微信扫一扫  
使用小程序

： ， ， ， ， ， ， ， ， ， ， ， ， 。 视频 小程序 赞 ，轻点两下取消赞 在看 ，轻点两下取消在看 分享 留言 收藏 听过