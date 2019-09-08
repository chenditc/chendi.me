---
layout:     post
title:      "Sync Outlook Calendar And Conference Room"
subtitle:   "将 Outlook 中的日程信息以及会议室信息同步至第三方系统"
date:       2019-09-08 00:15:00
author:     "Di Chen"
header-img: "img/in-post/outlook-calendar/outlook-bg.jpg"
tags:
    - Tech
---

## 起因

由于系统A实现上的需求，我们需要将 outlook 中的会议室的使用信息，以及对应每个用户的日程信息同步至内部开发的系统A中。主要需求包括：

1. outlook上的会议室使用情况涉及到不使用系统A的用户，所以outlook上的会议室预约信息会比系统A中的多，我们需要把这些额外的预约信息同步至系统A中，这样系统A中的用户在预约会议室时，可以考虑到其他用户的冲突。
2. 用户已经习惯使用 outlook 将日程和会议室信息同步至手机端，所以系统A中增加的日程需要同步至 outlook 中，包括会议室订阅也需要增加。
3. 当系统A中日程的属性变化时，outlook中需要对应发生变化。
4. 当outlook中日程的属性发生变化时，系统A中也需要对应发生变化

## 探索调研

### 搭建测试环境

为了便于测试，我们需要搭建一套基于 outlook 的邮件以及会议室系统，这里需要以下资源：

1. Windows Server 2012r2.
 - 2 核心
 - 16G 内存
 - 300G 磁盘
 - 云服务商上对外 25 端口默认是禁止使用的，需要单独申请开放，例如 [阿里云25端口解封](https://help.aliyun.com/knowledge_detail/56130.html)

2. 在 1 中的 windows 服务器上配置 AD 以及 Exchange Server 2016

3. 需要配置一个域名以及 DNS 记录
 - 需要给 exchange 服务器挂一个域名，例如 mail.abc.com，这个会作为邮件发送的服务器地址。
 - 需要配置 autodiscover 域名，例如 autodiscover.abc.com，这个域名会用来给客户端自动发现邮箱配置。
 - 需要配置一条 MX 记录，主机名 @，记录指向 mail.abc.com
 - 域名最好能申请 CA 签发的正规 https 证书，否则用自签名证书可能会遇到诸多不便。

### 配置用户以及模拟权限

我们需要为系统A建立一个服务账号，这个账号的会使用代码进行登录。同时，我们希望这个账号可以代所有其他用户账号管理会议日程信息，所以我们需要赋予这个账号 Impersonation 权限，也叫模拟权限。

我们可以通过后台管理 ecp 界面上的权限管理配置服务账号的权限：
[![pic1](/img/in-post/outlook-calendar/pic1.png)](/img/in-post/outlook-calendar/pic1.png)

其中配置的 ApplicationImpersonation 会赋予其模拟他人账号登录的权限
[![pic2](/img/in-post/outlook-calendar/pic2.png)](/img/in-post/outlook-calendar/pic2.png)

同时，我们也需要建立几个会议室邮箱，这样我们才能有公共的 “会议室” 以供预定。

### exchangelib的使用

[exchangelib](https://github.com/ecederstrand/exchangelib) 提供了一个可以使用 python 代码访问 exchange 服务的库，并且在使用上去 Django 的 ORM 极其类似。

安装：
`pip3 install exchangelib`

#### 登陆 exchange 账号

如果 exchange 服务器使用的是自签名的 https 证书，则需要跳过 https 证书验证环节：

```python
# 自签名服务器需要跳过 HTTPS 的证书检查
from exchangelib.protocol import BaseProtocol, NoVerifyHTTPAdapter
BaseProtocol.HTTP_ADAPTER_CLS = NoVerifyHTTPAdapter

import urllib3
urllib3.disable_warnings()
```

声明登陆服务器所使用的版本号、账号、密码、服务器连接地址：

```python
version = Version(build=Build(15, 0, 12, 34))
credentials = Credentials('administrator', 'xxxxxxx')
config = Configuration(
            server='mail.abc.com', credentials=credentials, version=version, auth_type=NTLM
            )
```

以用户 abc 的身份登陆，IMPERSONATION 字段表示以用之前配置的账号密码，模拟用户 zhangsan@abc.com 登陆：

```python
account = Account('zhangsan@abc.com', credentials=credentials, config=config, access_type=IMPERSONATION)
```

#### 创建新的日程

```python
# 新建一个日程对象
new_meeting = CalendarItem(account=account, # 需要绑定一个发起人账号
        folder=account.calendar, # 默认加入该账号的日历文件夹
        start=account.default_timezone.localize(EWSDateTime(2019, 9, 9, 21, 3)), #带时区的开始和结束时间
        end=account.default_timezone.localize(EWSDateTime(2019, 9, 9, 21, 20)), #带时区的开始和结束时间
        subject="final test 6", # 会议名称
        body='Hello from Python', # 会议内容
        location='2楼广寒宫', # 会议室地点，只需要文字描述，与实际会议室账号无关
        required_attendees=['abc@abc.com', "guanghan@abc.com"])
new_meeting.save(send_meeting_invitations=SEND_TO_ALL_AND_SAVE_COPY)

# 切换至会议室账号并接受邀请
room_account = Account('guanghan@abc.com', credentials=credentials, config=config, access_type=IMPERSONATION)
for item in room_account.calendar.all().order_by('-datetime_received')[:5]:
    print(item)
    item.accept()
```

注意：
1. 如果需要对这个日程绑定一个会议室，需要将这个会议室对应的邮箱加到参与者列表里，然后再更换登录账号，接受所有的会议邀请。
2. 保存时需要增加参数 `send_meeting_invitations=SEND_TO_ALL_AND_SAVE_COPY`，否则参与者不会收到邀请信息。

#### 查询日程并以某条件过滤

```python
start = account.default_timezone.localize(EWSDateTime(2019, 9, 9, 21, 3))
end = account.default_timezone.localize(EWSDateTime(2019, 9, 9, 21, 20))
items = account.calendar.filter(last_modified_time__range=(start, end))
for item in items:
	print(item.id) # 每个会议都有一个 ID
	print(item.subject) # 会议标题
```

#### 查询会议室的使用情况

会议室和用户没有本质上的区别。可以通过 Impersonation 登录会议室的邮箱账号，查看其日历上的内容来获取使用情况。

```python
start = account.default_timezone.localize(EWSDateTime(2019, 9, 9, 21, 3))
end = account.default_timezone.localize(EWSDateTime(2019, 9, 9, 21, 20))
items = account.calendar.filter(last_modified_time__range=(start, end))
for item in items:
	print(item.id) # 每个会议都有一个 ID
	print(item.start) # 会议开始时间
	print(item.end) # 会议结束时间
```

获取到该会议室的使用情况后，就可以检查该时间段内是否有人使用了。

### 系统设计

#### outlook 中会议室使用情况同步至系统内

为了保证会议室使用情况的实时以及查询的稳定性，我们定期将会议室的使用情况同步至系统内

同步任务需要实现：
  - 系统A中的会议室使用记录内增加 outlook id，字符串类型，用于记录 outlook 中的会议ID
  - 每次查询获取所有会议室最近一段时间内的日程列表，使用 last_modifed_time 字段进行过滤，只取上次同步任务之后变更的日程，与系统内的记录对比并更新
  - 如果有系统A中不存在的日程，标记为外部创建日程即可

如果有同步需求，也可以通过代码手动调用同步任务触发。
正常情况下设置定时任务，每10分钟同步一次即可。

#### 系统中增加日程

 - 检查对应会议室在 xx 时间段内是否有被预定
 - 绑定会议室后，系统A内创建会议室日程。
 - 日程保存时，检测是否有 outlook 日程绑定，同时检测 outlook 日程是否仍然存在，如果不存在，则创建outlook日程并绑定会议室，outlook中创建日程的用户与系统登录用户一致。
 - 绑定 outlook 会议室的操作即发送会议邀请给对应的会议室账号，再登陆会议室账号接受邀请即可。

#### 系统中修改日程
 - 系统中修改日程属性，如开始时间、结束时间、会议室等。
 - 修改后在保存时通过会议 ID 查询 outlook 中会议的对象，修改对应字段后保存 outlook 对象即可。

#### 系统中删除日程
 - 系统内标记日程位删除，同时 soft delete 删除 outlook 中的日程。

## 总结

outlook 对于会议室的设计感觉像是有历史遗留问题，每个会议室都必须分配一个邮箱，同时用邮箱来管理。但是目前来看，这个设计也有可取之处，就是对于会议室的操作可以复用用户的操作，学习成本更低一些。

---

如果你看到这里，一定是真爱！欢迎看看我的其他 [blog](http://chendi.me/)。O(∩_∩)O
