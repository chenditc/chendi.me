---
layout:     post
title:      "Unity Asset Management"
subtitle:   "Unity 中资源管理的学习总结"
date:       2017-12-20 00:15:00
author:     "Di Chen"
header-img: "img/in-post/unity-asset-management/unity-bg.jpg"
tags:
    - Tech
    - Unity 
---

## 需求

在团队进行 Unity 开发的时候，就资源管理的方式出现过许多吐槽，比如 “为什么不直接放进 Resource 里，多方便”，“要是当初放进 Resource 里就不会出这么多 bug 了 ”。当吐槽的次数越来越多，就意味着这个问题是阻碍开发效率的因素，急需解决。

同时，游戏安装包的大小与资源管理的方式直接挂钩，想要缩小安装包，就必须理解资源管理的原理并进行优化。

### 背景常识

对于大部分 Unity 开发来说，资源管理是个必修课，但是对于我这个主修后端开发的来说，还是有一些常识需要补补的。

**[资源](https://unity3d.com/learn/tutorials/temas/best-practices/assets-objects-and-serialization)** 在这篇博客中特别指的是 Unity 中的资源，例如图片，纹理，材质，模型，音频文件等。在游戏进行中，绚丽的特效和精美的场景都需要将资源从手机储存中读取出来并播放。由于摩尔定律，手机的 CPU 和 GPU 都有了大幅提高 ，但是手机储存介质的存取速度却没有太多提升，这就导致了在游戏的过程中资源的管理很容易成为瓶颈。(磁盘I储存以及 IO成为瓶颈)

---

### 目标细化
在资源管理这个话题下，我们可以将其分为一下几个需要进行权衡的问题：

1. **资源在什么时候，存在哪？** 存在游戏安装包中？还是存在服务器上？还是存在内存中？还是存在手机磁盘上？
2. **资源是否需要压缩？** 用如果要压缩，什么算法压缩？什么时候进行解压缩？
3. **资源是否需要缓存？缓存在什么地方？**
4. **资源是否需要热更新？如何支持热更新？**
5. **游戏安装包的大小由哪几部分组成？如何在不影响游戏安装体验的情况下，如何减小安装包**

## 官方文档总结

Unity 官方的文档对于资源管理有丰富的文档。在阅读之后受益良多，故在此总结，望与大家交流促进。

### Resources

对于大部分 Unity 开发者来说，最熟悉的资源储存位置便是 Resources 文件夹了，对于储存在 Resources 文件夹中的文件来说，读取只需要一句简单的 `Resources.Load` 即可，如下：

```
    rend.material.mainTexture = Resources.Load("glass") as Texture;
```

放在 Resources 中的好处就是方便，需要用的就放进去，用的时候直接取出来。但是在 [官方的最佳实践文档中](https://unity3d.com/learn/tutorials/temas/best-practices/resources-folder)，官方明确说明 `Don't use it`。不推荐的原因包括：

1. 将资源放于 Resources 中，在程序运行时，资源在内存的管理就不由程序员掌控。一个资源，例如图片，在使用过后是否要销毁，节省内存，还是要在内存中保留，方便后续其他界面使用？这个信息是 Unity 不能直接计算出的。
2. 在 Resources 文件夹中放置过多资源，会增加游戏的启动时间。游戏启动的时候，Splash Screen 播放的时候，会读取并索引 Resources 文件夹中的资源，索引的本质是一个[树结构](https://unity3d.com/learn/tutorials/temas/best-practices/resources-folder#footnote-1)。索引的建立所花的时间复杂度是 O(N log(N))，当 Resources 文件夹中有超过 10,000 个文件时，低端机上可能需要花费好几秒钟才能完成索引建立。
3. 如果将资源放在 Resources 文件夹中，资源会在编译时生成一个 Resources 资源包，这个资源包在编译之后是不能被修改的，也就减少了资源热更新方案中的灵活性。

综上所述，Resources 是一个短期使用方便，但是不利于长期项目发展的方案。对于快速做一个 demo 来说，是最佳选择。在正式项目中，对于部分常用，少量，不需要经常更新的资源，也可以放于 Resources 文件夹中。

特别是对于图片资源来说，有个奇怪的现象。如果图片放于 Asset Bundle 中，在储存时占用的空间是 Unity 资源序列化的大小，一个 100Kb 的 jpg 图片可能会序列化成 5M 的文件。但是在 Resources 文件夹中，只会占用 100Kb 的空间，并且在加载使用时没有太多区别。

### Asset Bundle

Asset Bundle 是 Unity [官方推荐的资源管理方案](https://unity3d.com/learn/tutorials/topics/best-practices/assetbundle-fundamentals)。建议大家都完整地阅读以下官方的文档，非常细致详细。

在使用 Asset Bundle 的时候有3个方面是首先要了解的：
1. Asset Bundle 是否压缩？使用哪种压缩方案？
2. Asset Bundle 如何读取使用？
3. 如何从 Asset Bundle 中读取出对应的 Unity Object?

#### Asset Bundle 的压缩方式以及分发

Asset Bundle 在项目中往往包含了模型，动作，贴图等游戏必须的资源。在 Unity 中，对于压缩方式，我们有 3 种选择：

| 压缩方式        | 提取 Object | 压缩后大小| 解压速度 |
| ------------- |:-------------:| :----:| :----: |
| 不压缩      | 提取时可以单独提取某个 Object。 | 无变化 | 不需解压 |
| 使用 `LZ4` 算法压缩 | 压缩时可以独立压缩每一个 Asset Bundle 中的 Object，并且提取时可以单独提取某个 Object。     | 压缩率与 `zip` 相似 | 解压快，大部分情况下无感知 |
| 使用 `LZMA` 算法压缩 | 提取时只能一次加载出整个 Asset Bundle 中的内容，不能单独提取某个 Object| 多数情况下压缩率比 `LZ4` 略佳 | 解压慢 |

在[压缩方式的官方文档](https://unity3d.com/learn/tutorials/topics/best-practices/assetbundle-usage-patterns)中，根据不同的使用场景给出了对应的建议。对于我的项目来说，由于是 iOS 平台上的项目，包体大小是希望尽量小的，这样可以避免玩家下载的等待时间。同时，我们选择不在游戏开始时下载资源包，从而避免玩家在游戏开始时由于资源包下载导致的流逝。所以，我们最后决定使用 LZ4 压缩 Asset Bundle，并在分发时[绑定在安装包中发放](https://unity3d.com/learn/tutorials/temas/best-practices/assetbundle-usage-patterns?playlist=30089#Distribution_Streaming_Assets)。

#### Asset Bundle 如何读取使用

在[官方关于AB包读取的部分](https://unity3d.com/learn/tutorials/topics/best-practices/assetbundle-fundamentals#Loading_AssetBundles)也提供了5种不同的 API 进行 AB 包的读取。

1. `AssetBundle.LoadFromMemory` 官方推荐不使用该 API。原因是在使用时会使用相当于资源3倍的内存占用。这个 API 底层运行是会先将资源从可执行文件的代码区读取出来，复制到一块新开辟的内存空间，所以最终会占用3块内存：

    1. 可执行文件的代码区内存占用。
    2. 新开辟的内存空间，用以储存从代码区拷贝出来的 AB 包。
    3. 最终从 AB 中读取出来的 Unity Object

2. `AssetBundle.LoadFromFile` 高度优化过的用以读取未压缩或者 LZ4 压缩的 AB 包。在调用该 API 时，Unity 只会加载 AB 包的头文件，而不会读取真正的内容。主要的资源内容会在实例化 Unity Object，也就是调用 `AssetBundle.Load` 时进行读取。使用时要注意这个懒读取的机制，避免在性能需求高的时候进行第一次 Load 操作。同时，在 Unity Editor 中，这个 API 会直接读取加载整个 AB 包的内容，和手机上不同，所以在 Unity Editor 进行性能分析时会发现资源加载所占用的性能特别多。

3. `AssetBundle.LoadFromStream` 这个 API 没有过多介绍，应该是与 `AssetBundle.LoadFromFile` 类似，但是形式上传入参数为一个数据流。

4. `UnityWebRequest` 中的 [DownloadHandlerAssetBundle](http://docs.unity3d.com/ScriptReference/Networking.DownloadHandlerAssetBundle.html?_ga=2.267324747.47480907.1518831956-488113989.1504339953) API。

     - 这个 API 是官方推荐的，用法也比较多样，最简单的例子可以在 [Downloading an AssetBundle from HTTP server](https://docs.unity3d.com/Manual/UnityWebRequest-DownloadingAssetBundle.html) 中找到。
     - 其中有一个功能是很有用的，就是它的缓存功能。当使用带版本号的 API `public static Networking.UnityWebRequest GetAssetBundle(string uri, uint version, uint crc);` 来下载时，会先检查本地是否有该版本的 AssetBundle，如果有就直接使用本地的 AB 包，如果没有就从服务器下载后放入缓存中。 
     - **注意**，在Unity的 AssetBundle 缓存系统里，（文件名，版本号）就标注了一个 AssetBundle，和 AB 包下载的 url 无关。所以 AB 包可以一开始放在安装包中，从安装包文件夹下载出来到缓存中，而需要更新时，从 CDN 服务器检查下载新版本即可，二者可以无缝兼容。关于缓存部分原理可以看 [UnityWebRequest 的介绍](https://docs.unity3d.com/ScriptReference/Networking.UnityWebRequest.GetAssetBundle.html)。

5. `WWW.LoadFromCacheOrDownload`。根据官方文档，从 2017.1 开始，这个 API 只是 `UnityWebRequest` 的一个封装，并且将在未来 deprecated。 推荐大家尽量不使用这个 API。

#### 如何从 AssetBundle 中读取 Unity Object

从 AssetBundle 中读取 Unity Object 主要有 3 个 API：

 - [LoadAsset](https://docs.unity3d.com/ScriptReference/AssetBundle.LoadAsset.html)
 - [LoadAllAsset](https://docs.unity3d.com/ScriptReference/AssetBundle.LoadAllAssets.html)
 - [LoadAssetWithSubAssets](https://docs.unity3d.com/ScriptReference/AssetBundle.LoadAssetWithSubAssets.html)

这三个 API 的使用选择上相对比较容易判断。

 - 当一个 AB 包中大部分(66%或者以上）的 Unity Object 都需要被加载时，使用 `LoadAllAsset`。
 - 如果要加载多个 Unity Object，尽量多使用 `LoadAllAsset` API，如果需要可以将其分为多个 AB 包。
 - 如果要加载的 Unity Object 引用了很多其他 Unity Object，例如一个角色形象，引用了 FBX 文件，动作，贴图等。此时使用 `LoadAssetWithSubAssets`。
 - 其余的情况都使用 LoadAsset。

## 最终解决方案

在比较权衡了便捷性，用户体验，性能，资源占用等方面因素，我们最后使用了如下的一套方案。

### 资源储存

绝大部分的资源使用 Asset Bundle 来进行序列化，主要包括模型，特效，界面 UI。少部分特殊资源储存于 Resources 文件夹中，这部分主要是加载界面，字体，小图标等资源。这样的分配可以让关键部件例如加载，文字提示等功能更加健壮，不会出现由于 AssetBundle 管理不善而出现的致命 Bug，同时也可以让后期更新模型特效资源更灵活。

### 资源压缩和分发

最初，我们在 Asset Bundle 分发方面使用了热加载的方案，就是在游戏开始时检测资源包更新，下载最新资源包后，再解压资源包，进入游戏。这个流程的好处在于初始的包体非常小，可以减小至 100 MB 以内。但是这个流程的弊病也很严重，就是玩家需要一个 “下载资源包” 的过程，并且这个过程需要占用玩家的手机使用时间，不能在后台进行。对于成熟的游戏例如 “王者荣耀” 来说，玩家的认可度足够高，是可以接受这个时间付出的。但是对于一个新生的游戏，这个过程导致的用户流失却是我们不能承受的，所以我们选择了第二套方案。

第二套方案是在安装包中附带了对应版本的 Asset Bundle 并进行了压缩，在游戏开启时，只需要进行一次十几秒的解压过程即可开始游戏。这是一个端游常用的方案，在游戏发行的初期可以帮助我们避免由于 “下载资源包” 导致的用户流失。

在今后的迭代中，我们还准备做进一步的改进，融合第一套和第二套方案。第二套方案在游戏启动时，同样可以检测资源包的更新，通过资源包的哈希值以及更新时间，判断是否需要下载更新。这样对于第一次下载游戏的用户，可以避免由 “下载资源包” 导致的用户流失，而对于第二次更新游戏的用户，可以一定程度上避免全量更新。

### 资源的使用

在资源使用上，主要流程还是 预加载资源包 -- 使用克隆资源 -- 释放资源包，但是由于不同模块间可能会需要使用相同的资源，所以模块间仍然需要进行协作来优化资源的使用。这里主要有一个优化点。

引用计数。在加载使用资源包的流程，其实和内存管理中 开辟内存空间 -- 使用内存空间 -- 释放内存空间 的流程很相似。所以我们也可以将内存管理中常用的手段拿来使用。内存管理中除了我们都熟悉的 Garbage Collection 之外，还有 iOS 中使用的 ARC (Automatic Reference Counting)，自动引用计数。当一个资源被引用使用时，我们将其的计数加一，当其被释放时，将其的计数减一，如果计数为 0，则将其释放。这样一来，我们既可以准确及时地释放资源，又可以最大程度地避免资源管理上的混乱。

### 经验总结

Unity 在目前的 3D 开发引擎里，算是社区很健全，同时文档也很丰富的一个引擎。我们遇到的绝大部分问题都是其他开发者踩过的坑，如果在一个方面停滞不前，没有好的解决方案时，不妨系统地静下心来通读一下文档。欲速则不达，静下心思考之后，往往能找到更优雅地捷径。

---

如果你看到这里，一定是真爱！欢迎看看我的其他 [blog](http://chendi.me/)。O(∩_∩)O
