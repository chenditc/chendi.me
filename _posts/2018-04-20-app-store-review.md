---
layout:     post
title:      "App Store Review Tips"
subtitle:   "App Store 审核经验总结"
date:       2018-04-20 10:15:00
author:     "Di Chen"
header-img: "img/in-post/app-store-review/04-appstore.jpeg"
tags:
    - Tech
    - AppStore
---

## 初衷

这篇博客主要想记录一下 App Store 中审核遇到的一些问题，以及最终解决的方案，希望对后来者有一定帮助，也是对自己的经验总结。

对于苹果开发者来说，App Store 的审核是一个对整体迭代效率影响极大的一个环节，但是绝大部分情况下，App Store 的审核还是比较客观效率的，所以不必将其视为洪水猛兽。

这里主要讨论下面几个问题：

1. [第三方登录](#第三方登录)
2. [第三方支付与内购](#第三方支付与内购)
3. [网络以及服务不连通](#网络以及服务不连通)
4. [初版兼容性](#初版兼容性)
5. [区分审核服务器](#区分审核服务器)
6. [Missing Info.plist key](#missing-infoplist-key)

## 第三方登录

现在基本上每个游戏或者 app 都会开放第三方登录，并且可能第三方登录是 95% 用户使用的登录方式。我们也希望尽可能优化用户登录的体验，所以也希望用户使用第三方登录，而不是手机号验证码或者邮箱验证。所以我们的登录界面是这样的：

[![01-app](/img/in-post/app-store-review/01-app.jpeg)](/img/in-post/app-store-review/01-app.jpeg)

但是对于 App Store 审核员来说，有两个问题：
1. 审核员大概率是外国人，看不懂中文，也就看不懂右上角的手机登录入口。所以有可能会打回 App，理由是未提供自有账号登录系统。
2. 审核员点击第三方登录按钮后，会跳转至第三方登录界面，对于审核员来说，变相要求其安装 QQ 或者微信这样的第三方程序，会以 “不得要求用户安装其他程序才能使用该程序” 理由打回。

对于这个情况，我们想了两种解决方法：
1. 只提供账号密码登录的方式，弱化第三方登录的 UI 显著性。
2. 在审核期间使 App 作出与线上服务器不同的表现，只展示账号密码登录的界面，等到审核通过后，再显示完整界面。

最后我们权衡了一下采用了方法2，这样对于 UI 和用户体验，我们有更完整的掌控性。至于如何在审核期间使 App 作出与线上服务器不同的表现，见 [第五节 - 区分审核服务器](#区分审核服务器)

## 第三方支付与内购

在我们提交审核时，我们曾被以下理由打回过 2 次：

> Guideline 3.1.1 - In-App Purchase

> We noticed that your app contains a payment mechanism other than in-app purchase for digital content or to unlock features or functionality within your app, which is not appropriate for the App Store. In-app purchase is the only valid in-app payment mechanism for digital content.

> Note: Continuing to hide functionality within your app or other dishonest acts may result in the removal of your apps from the App Store and termination of your Apple Developer Program membership and all associated memberships.

> Next Steps

> To resolve this issue, please remove all external or third-party payment mechanisms and implement in-app purchase to facilitate digital good transactions, including unlocking features or functionality within your app.

> If you believe your use of an alternative payment mechanism is a permissible use case, please respond directly to this message in Resolution Center with detailed information.

这个理由其实理解起来很简单 “我们检测到你在 app 里用了第三方登录，你别管我们怎么检测的，但是你得把它给去了"。

我们第一次遇到这个问题时，我们刚接入了集成各种第三方登录的 SDK - ShareSDK，在 ShareSDK 中包含了微信的 SDK，而微信的 SDK 中包含了微信支付的代码，苹果正是监测到这部分代码后，拒绝了对应的编译包。解决方法其实相对简单，只要将微信的 SDK 更换为不带微信支付的即可。

我们第二次遇到这个问题是，就比较奇怪了，在前一次正常过审核的编译和此次编译之间，我们没有引入额外的第三方支付或者更改过 SDK 包。我们在 Resolution Center 回复质询了详细信息，但是苹果并没有给出更详细的反馈。当时我们有两个方案：
1. 提交 Appeal 审核申诉，声明我们没有使用第三方支付，并要求重新审核。
2. 拆开 ipa 包，扫描可疑的 API，并将其剔除。

方案1操作起来简单，但是很可能会拖很久，而且据说一旦提起 Appeal，审核将变得非常严格，很可能得不偿失。

方案2操作的主动权掌握在我们手中，可以第一时间执行，也许当天就能找到问题所在，但是相对繁琐。淘宝上有类似的服务，价格大概为3000元。

我们最终选择了方案2，方案2的执行过程如下：

#### 找到 ipa 包对应的符号表

为了找到与支付相关的代码，我们选择从符号表入手，xcode 打包 ipa 之后，在 archive 文件中可以找到二进制文件并提取出符号表。

例如 archive 文件是： myapp.xcarchive

那么对应的二进制文件路径在：
`myapp.xcarchive/dSYMs/myapp.app.dSYM/Contents/Resources/DWARF/myapp`

我们可以使用 Unix 的 nm 工具获取到该二进制文件的对应符号表。

`nm myapp.xcarchive/dSYMs/myapp.app.dSYM/Contents/Resources/DWARF/myapp > symbols`

#### 在符号表中找到函数名

我们关心的函数一般带有关键字 "pay", "payment"，我们接着过滤出带有该关键字的函数

`grep -i "pay" symbols > pay_api`
`grep -i "payment" symbols > payment_api`

在 pay_api 以及 payment_api 中，我们会看到类似：

```
000000010275a484 t +[WXApi handleNontaxPayReq:]
0000000102757bd4 t +[WXApi handleOpenTypeWebViewWithNontaxpay:delegate:]
0000000102757d48 t +[WXApi handleOpenTypeWebViewWithPayInsurance:delegate:]
000000010275a594 t +[WXApi handlePayInsuranceReq:]
0000000102a8d780 t -[FBSDKPaymentObserver handleTransaction:]
0000000102a8d4c8 t -[FBSDKPaymentObserver init]
0000000102a8d63c t -[FBSDKPaymentObserver paymentQueue:updatedTransactions:]
0000000102a8d510 t -[FBSDKPaymentObserver startObservingTransactions]
0000000102a8d5a8 t -[FBSDKPaymentObserver stopObservingTransactions]
```
这样的符号表，三个栏位分别表示：
 - 符号对应的虚拟地址
 - 符号的类型
 - 符号本身，可能是函数签名，也可能是变量名

#### 在函数名中找到可疑的函数并移除

App Store 审核时显然不可能打回所有带有 `pay` 或者 `payment` 关键字函数的安装包，肯定是在有把握的情况下才会将 app 打回。所以下一步就是确认哪些 API 是让审核不过的。

我们检查的方式主要有两个：
1. 该 API 所属的 SDK 是否有第三方支付的能力。
2. 该 API 是否是直接支持第三方支付功能的。

所以我们排除了一些无关的 API，例如：
1. TalkingData 数据采集 API，TalkingData 只是数据采集方，API 被苹果监控的可能性较小。
2. Facebook 的 API，FB 本身不提供支付功能，API 被苹果监控的可能性较小。
3. 支付宝的朋友圈 API，虽然符号中有 "Alipay"，但是朋友圈 API 必然也被集成进了许多不需要支付的 App，被 ban 的可能性也比较小。
4. 我们自己代码中内购相关的 API，虽然符号中有 "pay" 字样，但是相信大部分内购 App 都会有，被 ban 的可能性较小。

最终我们定位到了两个可疑的 API：
1. QQ 支付的 API
```
0000000102c8d48c t -[QQApiPayObject AppInfo]
0000000102c8d460 t -[QQApiPayObject OrderNo]
0000000102c8d3b0 t -[QQApiPayObject dealloc]
0000000102c8d330 t -[QQApiPayObject initWithOrderNo:AppInfo:]
0000000102c8d49c t -[QQApiPayObject setAppInfo:]
0000000102c8d470 t -[QQApiPayObject setOrderNo:]
```
对于 QQ 支付的 API 来讲，无疑是苹果针对禁止的功能，我们的做法是从 QQ 的 SDK 下载处下了一个不带支付功能的。
2. 微信支付 API
```
000000010275a484 t +[WXApi handleNontaxPayReq:]
0000000102757bd4 t +[WXApi handleOpenTypeWebViewWithNontaxpay:delegate:]
0000000102757d48 t +[WXApi handleOpenTypeWebViewWithPayInsurance:delegate:]
000000010275a594 t +[WXApi handlePayInsuranceReq:]
```
对于微信的这几个 API 来说，从字面上看不出其主要功能是什么，所以我们下载了微信的两个 SDK 版本，一个带支付的，一个不带支付的。对比了一下发现两个版本中都有这几个符号，所以初步确认这个符号和支付功能无关，就没有对应修改。

在更换了 QQ SDK 之后，我们的 App 就过审核了。

## 网络以及服务不连通

在第一次提交审核的时候，我们被打回的理由是 "游戏打开之后就卡在了 Unity logo 画面"，但是本地各种机型都无法复现。在加载阶段，我们做的事情很简单：

1. 从 HTTPDNS 获取 DNS 解析结果。
2. 连接服务器更新最新版本信息。

在请美国的同学帮忙测试之后发现，错误发生在从 HTTPDNS 获取 DNS 解析结果这一步，这一步我们使用的是阿里云的 HTTPDNS 服务，但是不知为何，在国外区域请求一直发生错误。无奈之下，我们自己搭建了一个简易的 HTTPDNS 服务，解决了这个问题。

如果读者遇到本地无法复现的审核问题，不妨搭个 VPN，连接到加州的网络试试看。

## 初版兼容性

有一个我们吃了大亏的地方，就是第一个发布版本中，Info.plist 的 UIRequiredDeviceCapabilities 没有设置，导致后期收到了不少 App Store 的差评。

UIRequiredDeviceCapabilities 的[官方文档](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/iPhoneOSKeys.html#//apple_ref/doc/uid/TP40009252-SW3)给出了一系列可以使用的 key 值，如果在 xcode 的 Info.plist 中包含对应的 key 值，则在 App Store 上，只有满足对应兼容性要求的手机才能下载。并且，**在今后更新的版本中，都要支持曾经支持过的所有机型**。这就意味着，兼容性只能放宽，不能收紧。

这会导致什么问题呢？对我们来说，第一次发布的版本中，我们只限制了 iOS 11 以上的手机可以下载，但是没有限制支持 arkit 的才能下载。所以有一些机型不支持 arkit 的下载之后，发现 AR 功能无法使用而留下了差评。后期我们发现之后也不能收紧兼容性，给维护造成了很大困扰。

[![05-devicecompatibility](/img/in-post/app-store-review/05-devicecompatibility.jpeg)](/img/in-post/app-store-review/05-devicecompatibility.jpeg)


## 区分审核服务器

在我们的团队中，App 环境分成 3 个，dev -> alpha -> release

dev 是开发团队平时用于开发，测试的服务器。
alpha 是发版本前，用于固定版本的测试环境，以及审核用的环境。
release 是线上的正式服务器。

[![02-env](/img/in-post/app-store-review/02-env.jpeg)](/img/in-post/app-store-review/02-env.jpeg)

每一个环境中，有其对应的安装包和服务器包。
 - 安装包即 iOS 的 ipa 包。
   - 其中包括了版本号，编译时间戳，还有打包时的美术资源
   - **每一个版本号对应一个环境，由版本号控制安装包对应的环境**。
   - 版本号对应的环境信息储存在高可用的服务器上，这里选择的是阿里云的 OSS 服务，既保证了高可用性，也在最大限度上减少了服务器开销。如下图：[![03-env](/img/in-post/app-store-review/03-env.jpeg)](/img/in-post/app-store-review/03-env.jpeg) 
   - 客户端在**第一次打开时**，向阿里云请求该版本号对应的环境名，**并缓存在本地**，下次打开时直接从本地读取。
   - 在得到环境名后，从本地的环境 - ip 表中，获取对应的服务器 ip ，并连接对应的服务器进行交互。


 - 服务器则是用 docker 打包部署。
   - 其中包括了服务器代码以及打 docker 时的配置表信息。
   - 每个环境使用对应 docker tag 的 docker，例如 dev 版使用的 docker 镜像是 `test_docker:dev`，而 alpha 版使用的 docker 镜像是 `test_docker:alpha`，这样一来变更服务器版本就只需用一行代码来切换 tag 指向即可，保证了部署的代码和测试的代码是一致的。
   - `$ docker tag test_docker:dev test_docker:alpha`

这样一来，每个环境之间就不会互相影响了，开发时：
1. 客户端程序可以连接 dev 版本的服务器进行开发，服务器的更新，数据变化不会影响到审核或者线上正式玩家。
2. 当需要发版时，更改阿里云 OSS 上的文件，将客户端包里版本号对应的环境更改至 alpha，并将dev 标签的 docker 打上 alpha 标签，我们就完成了将 dev 环境复制到 alpha 环境的操作。
3. 此时，我们可以将对应的客户端安装包提交审核，在审核期间，开发和线上活动均不会影响到审核员的数据。
4. 等到审核通过后，我们可以再将审核服和对应安装包部署到 release 环境中。

由于我们在客户端有了对应的环境名，我们也可以对应作出一些审核中特有的操作，例如：

```python
if env == "alpha":
  do_something()
else:
  do_something_else()
```

## Missing Info.plist key

我们在搭建了自动打包系统之后，每天都会打包上传最新的安装包，在某次 git commit 之后，收到了苹果发来的邮件：

```
Missing Info.plist key- This app attempts to access privacy-sensitive data without a usage description. The app's Info.plist must contain an NSContactsUsageDescription key with a string value explaining to the user how the app uses this data.
```

我们在 App 的使用过程中从未获取过用户的联系人信息，所以我们希望找到导致这个警告的原因，而不是添加一个不必要的 NSContactsUsageDescription。

苹果会弹出这个警告，而我们没有调用联系人的 API，那么应该是间接引入了获取联系人的 API，导致 API 被苹果扫描到了。我们在 Linked Library 中找到了 Contacts.Framework 并将其删除后，重新编译。发现讯飞科技的 SDK 报错了。原来是我们使用了游密的 SDK 实现聊天功能，游密又使用了讯飞的 SDK 实现语音转文字功能，讯飞的 SDK 又引入了联系人的 API 来获取联系人名字，帮助语音识别更准确地识别人名。

最后由于我们不需要讯飞的 SDK，就和游密要了不含讯飞的SDK。如果不使用这个方式，也可以自己新建一个 .m 文件，实现几个 dummy function 来规避编译错误，又不影响已有功能。

# 经验总结

Unity 在目前的 3D 开发引擎里，算是社区很健全，同时文档也很丰富的一个引擎。我们遇到的绝大部分问题都是其他开发者踩过的坑，如果在一个方面停滞不前，没有好的解决方案时，不妨系统地静下心来通读一下文档。欲速则不达，静下心思考之后，往往能找到更优雅地捷径。

---

如果你看到这里，一定是真爱！欢迎看看我的其他 [blog](http://chendi.me/)。O(∩_∩)O
