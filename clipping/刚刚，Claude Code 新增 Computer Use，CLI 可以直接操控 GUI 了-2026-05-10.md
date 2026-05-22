---
title: 刚刚，Claude Code 新增 Computer Use，CLI 可以直接操控 GUI 了
author: J0hn
source: https://mp.weixin.qq.com/s/jx05-5VDsmuyWIu-9I5fiw
clipped: 2026-05-10
---

J0hn J0hn

在小说阅读器读本章

去阅读

Claude Code 更新了，这次加了个大招：Computer Use。

![](https://mmbiz.qpic.cn/sz_mmbiz_png/ZKqVLiaIpzFml9TdTBQrpoo8zibNXKicactFbB0WJ176pzWNJcdsicea4OH7wjSRWZNuu6shBP4AE7JVw4bMOTdVfGFkW8BwepDmhRTFylsxsjg/640?wx_fmt=png&from=appmsg)

简单来说，Claude 现在可以在命令行里直接打开你 Mac 上的应用程序，点击按钮、截图、操作 UI，然后把结果反馈回来。

Computer Use

写代码、编译、启动应用、点击测试、发现 bug、修复、验证，一条龙，全在一个终端会话里完成。

01

## 先看效果

官方演示视频里展示了一个完整的场景。

用户在 Claude Code 里打开了一个叫 SPM3000 的像素画编辑器项目，然后输入了这么一段话：

> “ 反馈频道说 Gen 按钮渲染到一半就报 ERR 19 停了。打开 SPM3000，复现一下，修掉，然后给我出个新构建。

![Claude Code CLI 启动项目](https://mmbiz.qpic.cn/mmbiz_gif/ZKqVLiaIpzFltYv81t7SN3AWJ8OwtLF1GHibJ5ict5EQTibdgE7UxubLxZ4CO502umdQhmibaGLYP2FrgXyDkyaHntcWxc0icBWwllZnrRicDO5rcw/640?from=appmsg)

Claude Code CLI 启动项目

Claude 先跑了 `git status` ，列了一下 Xcode 项目结构，然后……直接把 SPM3000 应用给启动了。

02

## 自己动手点

接下来，Claude 干了件让人没想到的事。

Claude 在终端里输出了一句：「我来启用 Computer Use，这样就能帮你点了。」

然后通过 `/mcp` 启用了 Computer Use，获得了点击、输入、截图的能力。

![Claude 打开应用复现 bug](https://mmbiz.qpic.cn/sz_mmbiz_gif/ZKqVLiaIpzFlrEVAQkrrF9ebNw7NWaflCibnsdpX0hX9xjtUSiaTibPiaADdfy0551XpVkhbumEqCrWBicyEPKTWH080PTLUf6uY7qZCfCfNS2RAA/640?from=appmsg)

Claude 打开应用复现 bug

它打开了 SPM3000 应用，点击了 GEN 按钮，坐标 (412, 580)。

屏幕上出现了一个像素画小动物，渲染到一半就停了。底部显示： **ERR 19，ROW 16/32，BUFFER OVERRUN** 。

Claude 截了一张图，存到了 `/tmp/gen-before.png` ，确认了问题：渲染在第 16 行中断了。

![Claude 截图确认 ERR 19](https://mmbiz.qpic.cn/sz_mmbiz_jpg/ZKqVLiaIpzFlmBaSLdOXkCnR0r3EDibUBFs6wyC5xJbHV5SHiciangxcebiaat3ZB9Fx90pFAQgINpxAibLr0DILoglU45odXBziahUdN4R6eWJQNI/640?from=appmsg)

Claude 截图确认 ERR 19

03

## 找到 bug

确认了 bug 之后，Claude 切回了它熟悉的领域：代码。

用 `grep` 搜索了 `ERR 19|rowIndex` ，在 `Sources/GenViewModel.swift` 的第 47 行和第 52 行找到了相关代码。

然后读取了 `renderSprite()` 函数，发现问题出在调色板逻辑上：当 palette 为空时，函数直接返回了 `.err(19)` ，导致渲染中断。

![Claude 搜索代码定位 bug](https://mmbiz.qpic.cn/sz_mmbiz_gif/ZKqVLiaIpzFkstUJvPqBUV8jlLseFv7sEH1Sq6QhYGnfsvRakD0ibIwHUNpBO9KiaulIEdzDuS8jNmWLYpFu28lWqiaCCDJFG51wde8BKicBuKyc/640?from=appmsg)

Claude 搜索代码定位 bug

修复方案也挺直接的：把原来的 `guard let palette else { return .err(19) }` 改成了 fallback 到 `lastGoodPalette` ，让渲染不至于因为一个空调色板就整个中断。

04

## 一次验证

改完代码，Claude 跑了 `xcodebuild -scheme SPM3000 -configuration Debug build` 。

Build Succeeded。

![重新编译并验证修复](https://mmbiz.qpic.cn/sz_mmbiz_gif/ZKqVLiaIpzFmDYticWSvCfK5UiaHSiczZiagZ2dS7F17IicwfxzIYoulaVua2cnGTsKdjeePoBnBoCkHoexKSCbiaIBgffvibImZhibgDxscTZQBpwVk/640?from=appmsg)

重新编译并验证修复

然后它又把 SPM3000 重新打开了，又点了一次 GEN 按钮。

这次，32 行全部渲染完成，像素小动物完整地出现在了屏幕上，还带着墨镜，动画循环播放。

Claude 的回复：

> “ 完整渲染完成，32 行全部通过，墨镜动画循环播放。修复生效了。要我出个构建吗？

用户回了一个字：好。

![修复后完整渲染效果](https://mmbiz.qpic.cn/mmbiz_jpg/ZKqVLiaIpzFnnNyq2u20J3O8rdfAfHc4zLP49cxoRwY8F1n0EoCdO8QkLArnQ7EqgN1Rbo87JdSqOWicWsF0Ow203H6y6RymQS7GqKVYpwhfY/640?from=appmsg)

修复后完整渲染效果

**从收到 bug 报告到修复验证完成，整个过程大概两分钟。**

![闭环开发流程](https://mmbiz.qpic.cn/sz_mmbiz_png/ZKqVLiaIpzFnWzuXx7J1cI1a7xIB5A5QIycp0kWdNLQswRcuLsXBdztuJxoA26TpibwPwHrFvicZia7oaRjm8ibc5PnLx6DrwNNqpxY5MZNEveb8/640?from=appmsg)

闭环开发流程

05

## 使用范围

目前 Computer Use 以 Research Preview 的形式提供，仅限 macOS 平台，需要 Pro 或 Max 订阅。

开启方式：

• 在 Claude Code 会话中输入 `/mcp`

• 找到 `computer-use` ，选择 Enable

• 首次使用时 macOS 会要求授予两个权限： **辅助功能** （让 Claude 点击、输入、滚动）和 **屏幕录制** （让 Claude 看到屏幕内容）

![Computer Use 通过 /mcp 启用](https://mmbiz.qpic.cn/sz_mmbiz_gif/ZKqVLiaIpzFkmFYyQibrbSE0CRibXdjhjY0lGLdLw8WhznXriaqkPR4GPibXgvzU3OqfsTZ1mLVumoibu4xfUD6RJlepLtoLNcWBqLXSXPO00PrPY/640?from=appmsg)

Computer Use 通过 /mcp 启用

授权完成后，直接告诉 Claude 你想让它操作什么就行了。比如：

> “ 编译 MenuBarStats，启动它，打开偏好设置窗口，验证一下 interval 滑块能不能正确更新标签。

Claude 就会自己编译、启动、操作、截图。

06

## 不是什么都用它

Claude 在选择工具时其实有个优先级：

如果你配了 MCP server，优先用 MCP。如果任务能用 shell 命令解决，用 Bash。如果是浏览器操作且装了 Claude in Chrome，用浏览器。

**只有以上都搞不定的时候，才会动用 Computer Use。**

![工具选择优先级](https://mmbiz.qpic.cn/sz_mmbiz_png/ZKqVLiaIpzFkJEzbuygGcjibGaJcz131sW3ic03QuB4nUOF20JYUqm16P4Ad92QpsHWf2307C4PjnjMafWjbJIJibuTanBgmkp7icvP5qA8KwZ30/640?from=appmsg)

工具选择优先级

这个设计也是颇为合理。

毕竟屏幕操控是最慢的方式，能用精确工具解决的事就没必要去「看屏幕点鼠标」。Computer Use 是留给那些没有 CLI、没有 API、只有图形界面的应用的。

07

## 能干什么

从文档和演示看来，目前主要是这几类场景：

**原生应用验证** ：改完 SwiftUI 代码，让 Claude 自己编译、启动、点一遍 UI，截图确认。省去了你手动打开 app 看效果的步骤。

**端到端 UI 测试** ：指着一个本地 Electron 应用说「测一下注册流程」，Claude 会自己打开应用、走完注册、每一步截图。不用写 Playwright，不用配测试框架。

**视觉 bug 调试** ：告诉 Claude「modal 在小窗口下会被裁切」，它会自己调整窗口大小来复现，截图，改 CSS，再验证。

**控制纯 GUI 工具** ：设计工具、硬件控制面板、iOS 模拟器、各种没有命令行接口的专有软件，现在都可以通过 Claude Code 来操作了。

08

## 安全机制

Anthropic 在安全上做了不少限制。

每个 app 都需要你在当前会话中单独批准。Claude 想操作 Finder？弹个提示告诉你「这个 app 可以读写任何文件」，你决定要不要放行。想操作终端？提示「等同于 shell 访问权限」。这些……倒也应该谨慎。

不同类型的应用，Claude 的控制权限也不同：浏览器和交易平台只能看，不能操作。终端和 IDE 只能点击，不能输入。其他应用才有完整的控制权。

Claude 工作时，会把其他窗口都隐藏起来，只和你批准的应用交互。终端窗口始终可见但被排除在截图之外，所以 Claude 看不到自己的输出，也就避免了 prompt injection 的风险。

**随时按 Esc 就能中断 Computer Use，把控制权拿回来。**

09

## 和桌面版的区别

Claude Desktop 其实也有 Computer Use 功能。

CLI 版的主要区别是启用方式不同（ `/mcp` vs 设置面板），暂时没有「拒绝应用列表」的配置，以及自动恢复隐藏窗口是强制开启的。

核心引擎是同一套。

10

## 往远了看

这件事的本质，其实是 **AI 编程助手的「感知边界」又扩大了一圈** 。

以前的 Claude Code 能读代码、写代码、跑命令，但它是「盲」的，看不到代码运行之后的结果长什么样。你改了个 CSS，得自己打开浏览器看效果，然后……用文字描述给 Claude 听。

现在它自己能看了。

**写代码的和验证代码的，变成了同一个人。**

这对于前端开发、移动端开发、桌面应用开发来说，可以说是巨大的变化。以前「改一行代码，手动验证一次」的循环，现在可以交给 Claude 自己完成了。「可验证」这事，对于 AI 意味着什么，如果你没有 get 到，可以去问问 AI……

目前还是 Research Preview，只支持 macOS，需要 Claude Code v2.1.85 以上版本，可以使用 claude install 升级并充钱后使用。

不支持 `-p` 非交互模式，也不支持 Team 和 Enterprise 计划。

我自然也是，已经用上了：

![](https://mmbiz.qpic.cn/sz_mmbiz_png/ZKqVLiaIpzFlpWlpdmlr2TJHx3gRN1ickOrHW5mZgzU3YnwcVbgxRSWstPqmnRZHxydS6EaTvQ74HoKyQmyia7Ztic8tstVcESeGs8273C5VPFk/640?wx_fmt=png&from=appmsg)

◇ ◆ ◇

相关链接：

https://code.claude.com/docs/en/computer-use

https://x.com/claudeai/status/2038663014098899416

继续滑动看下一个

AGI Hunt

向上滑动看下一个

微信扫一扫  
使用小程序

： ， ， ， ， ， ， ， ， ， ， ， ， 。 视频 小程序 赞 ，轻点两下取消赞 在看 ，轻点两下取消在看 分享 留言 收藏 听过