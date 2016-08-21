---
layout:     post
title:      "How to create a pokemon map?"
subtitle:   "怎样从头制作一个实时 pokemon go 地图？"
date:       2016-08-20 07:15:00
author:     "Di"
header-img: "img/in-post/mypokemon-io-1/mypokemon-io-bg.jpg"
tags:
    - Tech
    - Hack
    - Pokemon Go
---

> “Go catch em all! ”


## 前言

在一个月前，[Pokemon Go](http://www.pokemongo.com/) 成了新一轮现象级手游。基于 LBS （Location Based Service) 的设计给社交带来了更多可能。

从最早玩游戏的时候，我就不甘于受限于游戏的世界，探索各种 “作弊” 的方式。既然是基于位置的游戏，那么制作一个 “地图” 也成了顺其自然的想法。

这篇文章就记录了我从反向工程探索 Pokemon Go 架构，到建立一个实时 Pokemon 地图的过程。

---

## 探索

对网络安全有一些了解的同学大概都知道，要 hack 某个游戏或者 app ，你需要做的第一件事就是了解它是怎样运作的。对于 Pokemon Go 也是一样的。

### 监听网络流量

> 2016/07/18

首先，我需要架设一个网络流量监听的工具。由于近年来 REST API 的流行，我假设 Pokemon Go 也是用 REST API 来通信的，那么假设一个 http proxy 便能够进行 MITM ([man in the middle attack](https://en.wikipedia.org/wiki/Man-in-the-middle_attack)) 攻击，并截取通信记录了。在这里，我用的工具是 [burp](https://portswigger.net/burp/proxy.html)

由于我的 macbook 和我的手机接入到了同一个 wifi ，我在电脑上设置的 proxy ，在 iphone 上也能连上。在 [burp configure](https://support.portswigger.net/customer/portal/articles/1841108-configuring-an-ios-device-to-work-with-burp) 界面有很详细的设置过程，在设置好电脑跟手机之后，我们就可以在 burp 上看到 Pokemon Go 的网络流量了。

### 解码

在 burp 里，我们可以看到 Pokemon Go 的[通信记录](https://raw.githubusercontent.com/chenditc/pokemon-analyze/master/request_history)，其中大部分都是毫无意义的二进制码。联想一下 Google 的技术栈，不难想到，这是用 protocol buffer 编码过的，那么用 protobuf 反向解码，就可以看到原请求了。

我写了一个[小脚本](https://github.com/chenditc/pokemon-analyze/blob/master/parse_request_history.py)来批量解码，[解码的结果](https://github.com/chenditc/pokemon-analyze/blob/master/parse_output)是可以 json 格式的 enum 集合。由于没有 schema ，下一步我们需要做的就是搞清楚每个 enum 对应的意思。这个过程就比较枯燥繁琐了，在 github 上效率最高的 project 算是 [AeonLucid/POGOProtos](https://github.com/AeonLucid/POGOProtos)，我们就不要重新造轮子了。

同样的，在这步之后，把 protocol buffer 转化成可用的 API 也有开源的项目 [tejado/pgoapi](https://github.com/tejado/pgoapi)，我们就可以跳过这两步，直接开始设计地图了。

## 架构设计

我最终的目标是提供一个 Pokemon Map as a Service，那么所有的数据储存跟采集都必然发生在云端。我决定的架构是这样的:



---

---

## 后记


