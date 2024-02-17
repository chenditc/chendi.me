---
layout:     post
title:      "Sora 技术文档拆解"
subtitle:   "Tech Detail of Video Generation Model by OpenAI"
date:       2024-02-15 10:00:00
author:     "Di Chen"
catalog:    true
header-img: "img/in-post/cover/openaidevday.jpeg"
tags:
    - AI
    - OpenAI
    - Technology
---

## 从技术文档看 Sora 的突破在哪

昨天 OpenAI 的 Sora 又一次屠了 AI 圈的新闻头条，甚至央视也报道了 Sora 的新闻。那 Sora 到底凭什么能有这么优秀的表现呢？

Sora 与 Demo 一同发布了一篇技术文档：https://openai.com/research/video-generation-models-as-world-simulators. 主要讲了2方面的内容：

1. OpenAI 是怎样归一化不同类型的视频表达，从而实现大规模大数据量的模型训练的。
2. 定性地分析 Sora 的能力边界。

这篇技术文档也展示了这一年来 **AI 研究自我加速**的趋势。

## 大力出奇迹

> Our results suggest that scaling video generation models is a promising path ...

在文档一开头，OpenAI 就表明了，Sora 的突破其实就是 scaling laws 的又一次表现。从语言大模型的成功里得到的灵感，只要有获取更多的高质量数据，并有效地利用起来，同时增大模型的参数，就能得到更好地效果。但其中难点有很多，例如怎样获取更多的高质量数据（1080p以上的视频数据以及对应的标注），以及怎样有效地利用起来 （像语言模型一样切分为 token 并进行训练）。OpenAI 这里主要讲了他们是怎样利用这些高质量的视频数据的。

OpenAI 也展示了在不同算力支持下，1 倍基准算力训练出来的模型基本只有个大致的色块，4 倍算力训练出来的模型与 Pika，Runway 等公司的模型效果相比更接近，有了比较清晰的轮廓，但是细节仍然模糊。但 32 倍算力训练出来的模型在细节、光影、一致性上就达到了接近实拍的效果。这里的算力 OpenAI 用的是 “training compute”，没有提数据量的变化，指的应该是同样数据量下，训练的 epoch 数量和 GPU 时长的变化。

<video width="100%" poster="/img/in-post/sora/sora1.png" controls="" preload="none" type="video/mp4">  
<source src="http://video.chendi.me/videos/Sora%20-%20%E7%AE%97%E5%8A%9B.mp4">  
</video>

## 有效利用高质量视频数据

Scaling Law 也提到，要训练更长时间，就需要有更大的模型容量（更大的模型参数），同时也要有对应量级的数据支持。那么如何利用更多视频数据就是其中的关键。

### 视频patch

语言大模型之所以可以利用起全互联网的数据，很关键的一点就是在建模时，把文本拆成了以 “token” 为最小单位，不管什么语言，在什么场景，都可以把一篇文章拆成一个由 token 组成的序列。而对于视频来讲，这里也有一个类似的概念叫 patch，这个概念不是 OpenAI 这次提出的，之前何恺明等大神也用这个方法训练了图像的 transformer，达到了图像领域的 SOTA。Patch 的概念主要是让训练的过程可以更好的并行化。

[![figure-patches](/img/in-post/sora/figure-patches.png)](/img/in-post/sora/figure-patches.png)

在视频领域的 patch 和在图像领域的可能略有不同，但 OpenAI 并没有细写。从架构图上看，有一个 video encoder 模型先把视频转为一个低维矩阵作为 latent representation，然后再由一个线性映射模型，把它拆解成一个时间序列。这里可能有两个模型：
1. 把视频进行压缩的 encoder 模型。
2. 把 latent space 的矩阵拆解成时间序列。

**这两个用来生产 patch 的模型虽然篇幅不多，但我感觉是 OpenAI 能有效使用大量视频数据的关键。**Patch一定不是是每一帧对应一个 patch，因为文中也提到 Sora 在训练时，也把图片作为只有一帧的视频进行训练，说明一张图片也能生成 N 个 patch。从 OpenAI 数据驱动的风格来看，很可能这个 patch 与以往的定义不同，并不能直接映射到某一段数据上，只是一个人为定义的概念，其具体表示完全是由上面的两个模型生成的。

由于视频 patch 的优雅设计，使得 OpenAI 可以使用不同分辨率、比率、时长的视频和图片进行训练，也一定程度上避免出现生成被裁切主体的情况。玩过 Stable Diffusion 之类的生图软件的同学应该知道，由于模型训练时把素材裁切成统一大小后进行了输入，所以当生成的图片大小与输入图片不一致时，很容易出现主体只出现一般的情况。OpenAI 的 patch 设计似乎也解决了这一点。

<video width="100%" poster="/img/in-post/sora/sora2.png" controls="" preload="none" type="video/mp4">  
<source src="http://video.chendi.me/videos/Sora%20-%20%E6%88%AA%E6%96%AD.mp4">  
</video>

### 复合数据

在训练 Sora 时，数据集除了视频本身，还需要有**描述视频的文本**。对视频的描述越详细，模型就越容易捕捉到视频内的细节，但对视频进行细致的标注是很困难，也很昂贵的。

Sora 使用了和 Dall-E 3 类似的 Recaption 流程。Dall-E 3 的 Paper 里提到 OpenAI 基于 CLIP 训练了一个专门用来写图片内容的模型：https://cdn.openai.com/papers/dall-e-3.pdf。这个模型不仅仅会写出图片内有什么，还会写出并不是主体的内容，例如角落摆放的饰品、图片里的文字内容、物品上的细小标志。用这个模型给大量图片生成细致的描述 （300字以上）后，大大提升了生成图片的可控性和细节的准确性。所以在 Dall-E 3 的成功背后，由大量的这样的复合数据在进行支撑，这个思路也被用于 Sora 的训练里。

[![dall-e-data](/img/in-post/sora/dall-e-data.png)](/img/in-post/sora/dall-e-data.png)

Caption生成模型也被用在了 Sora 训练集的标注上，但具体流程文中没有写出。是给每个 patch 对应的采样图片进行 caption 生成？还是给整个视频进行1分钟大小的内容进行 caption 生成？文中也没有写是如何把文本描述和视频 patch 对应起来的。这个部分可能也是让 Sora 能如此成功的一个 trick。

同时，Sora 在生成图片前，会先用 GPT 对用户输入的提示语进行优化，相当于是一个 “自动提示词工程”，从而让画面内容更丰富，更具有表现力。

## AI 研究的自我加速

前面复合数据的部分也揭示了一个现象，就是 AI 研究的领域已经出现了由复合数据带来的自我加速的过程。

过去 AI 模型的开发除了模型结构的优化，往往还需要大量的标注数据。而现在由于 GPT 的能力边界渐渐靠近人类，“标注”的工作也变成了由 GPT 进行粗标 + 人类筛选的过程。这样可以用更短的时间、更低的成本获得更大量的数据，从而训练出更强的模型。

[![loop](/img/in-post/sora/loop.png)](/img/in-post/sora/loop.png)

而一旦模型的能力变得更强，获取同质量数据的成本就更低了，又可以迭代出下一代更好的模型。Sora 的出现就依赖了开发 Dall-E 时用的 Caption 生成模型，以及 GPT。我们之前觉得 AI 会先加速赋能艺术领域或商业领域，但可能最先受益的是 AI 研究领域。技术发展的奇点已经到了。

## 定性的能力边界测试

技术文档里还对 Sora 的能力边界进行了不同的测试，[在昨天的文章中可以直观的感受到。](https://mp.weixin.qq.com/s/Ufs7__JmBAIKDGVErA5pcg)

OpenAI 也暴露出其目前的一些不足，例如在生成杯子破碎的时候，破碎的过程并不准确，模型不理解碎片是由杯子上出来的。就像盗梦空间一般，我们已经无法从画质上区分 Sora 生产的视频和实拍视频了，要区分是不是 AI 生产的视频，只能从很细小的细节里去找违反物理规律的动作。

<video width="100%" poster="/img/in-post/sora/sora3.png" controls="" preload="none" type="video/mp4">  
<source src="http://video.chendi.me/videos/Sora%20-%20%E6%9D%AF%E5%AD%90%E7%A0%B4%E7%A2%8E.mp4">  
</video>


## 启发

Sora 的出现把原本的很多“猜想”变成了可以尝试的事情。例如：
- Sora 使用的 Video encoder 和 patch，会不会是视频压缩效率更高的一种方案？
- Sora 生成的视频是不是能用来做为 NERF 的输入，做 3D 建模？
- Sora 是不是可以作为模拟器，给机器人做强化学习的 playground？
- Sora 生成的 caption 是不是可以用来做视频索引，让视频剪辑工作者更容易找自己需要的素材？

以及 Sora 这类文生视频未来在商业化的方向上：
- 什么样的视频创作者会被替代？
- 生成视频的成本是不是会比实拍更高？
- 如果一次生产的视频不满意，是重新生成还是用后期软件编辑？

这些问题就留给下一篇博客我们再聊吧。