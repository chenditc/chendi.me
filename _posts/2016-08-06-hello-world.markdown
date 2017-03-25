---
layout:     post
title:      "Welcome to Di's Blog"
subtitle:   "欢迎来到我的博客"
date:       2016-08-06 20:15:00
author:     "Di Chen"
header-img: "img/hello-world-bg.jpg"
tags:
    - 生活
---

> “Hello world. ”


## 前言

终于把博客架起来了。

[跳过废话，直接看技术实现 ](#build)


在博客出现了十几年之后才开始建自己的博客站，有种考古的感觉。

不过除了博客，也找不到什么合适的地方写东西。

公众号，微博，论坛都充斥着浓浓的商业气息，而且谁知道下一个10年，20年，他们还会不会存在。

大概还是放在自己的域名，自己的版本控制最靠谱了。


<p id = "build"></p>
---

## 正文

接下来说说搭建这个博客的技术细节。  

在选择博客框架的时候犹豫了一下。最有名的博客框架大概是wordpress了，不过维护一个数据库和服务器实在是太麻烦。在建github repo的时候看到过[GitHub Pages](https://pages.github.com/) + [Jekyll](http://jekyllrb.com/) 的方案，感觉非常robust.

 - 一份markdown就是一篇博文，简洁明了。
 - Github自带markdown预览，方便调节格式。
 - 无限储存空间，静态网站，无需服务器支持。
 - 原生的git工具集都可以用。


---

刚开始配置的时候，踩了特别多的坑。

Jekyll在github pages上的配置缺乏文档支持。网上有许多教程都已经过时了，在本地Jekyll生成的网站可以正常使用，但是放到github pages上就编译失败，也找不到对应的文档。

在尝试了不少教程之后，决定从已经可用的Github网站fork一个已经可用的出来，再修改成自己的风格。

在此感谢[黄玄](http://huangxuan.me/)贡献维护了开源模版[huxblog-boilerplate](https://github.com/Huxpro/huxblog-boilerplate).

用了这个模版之后还做了一些小配置：

1. 新建gh-pages branch。
2. 把gh-pages branch设为默认branch。
3. 在Github Repository的setting里面设置Custom domain，这样就可以使用http连接，否则会被强制使用https。
4. 修改了一下_config.yml文件。


---

## 后记

今后会把一些看的书，做的side project记录下来，算是整理一下自己的知识体系。

希望也能因此结识一些有趣的人。
