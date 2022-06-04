---
layout:     post
title:      "Weird bugs - 6"
subtitle:   "奇怪的 bug 系列 6 - Powershell 调用 C# dll 中遇到的问题"
date:       2022-06-01 10:15:00
author:     "Di Chen"
catalog:    true
header-img: "img/in-post/cover/ppt.jpg"
tags:
    - tech
---



## 背景

在 Windows 下开发时，如果需要依赖某些 C# .Net Framework 开发的库来做一些运维操作，比如 AD、证书的加载读取，或者是 Windows 弹窗的操作，往往需要加载 dll 动态库。这时候有两种办法可以来做：
1. 写一个 C# 的项目，在编译时静态或动态地将 dll 依赖 link 进项目，最后生成一个二进制文件运行。
2. 写一个 Powershell 的脚本，在脚本中动态加载 dll 文件并调用方法，就不需要编译的过程了。

如果我们使用传统的方法 1，那么我们需要配置新的 C# 项目、编译代码、拷贝分发二进制文件，如果只是为了实现一些简单的运维操作，这个流程就显得太繁琐了。

最近尝试用第 2 种方法做了几个项目，也总结一下方案2中遇到的问题、解决方法以及优缺点：

  - [依赖冲突](#依赖冲突)
    - [依赖冲突的原因](#依赖冲突的原因)
    - [根本上解决依赖冲突的方法](#根本上解决依赖冲突的方法)
  - [错误排查](#错误排查)
  - [强弱类型混合](#强弱类型混合)


### 依赖冲突

使用 Powershell 加载 dll 进行开发的方式，最容易遇到的就是依赖冲突的问题。

例如我们尝试加载 `abc.dll`，并使用其中的 `Xyz` 类：

```powershell
PS> Add-Type -Path 'C:\Program Files\abc.dll'
PS> $temp = [Namespace]::Xyz()
```

我们常常会见到类似这样的报错：

```powershell
Could not load file or assembly 'SomeLibraryName, Version=x.x.x ...'. 
Could not find or load a specific file...
```
[![error1.png](/img/in-post/powershell/error1.png)](/img/in-post/powershell/error1.png)

出现这类报错的一种原因就是遇到了依赖冲突，要解决它我们要先来了解一下为什么会有依赖冲突。

#### 依赖冲突的原因

[![conflict1.jpeg](/img/in-post/powershell/conflict1.jpeg)](/img/in-post/powershell/conflict1.jpeg)

在我们的 powershell 脚本中，假如我们需要同时使用两个不同的库 A 和 B，而这两个库分别依赖于不同版本的 C 库，例如一个依赖于 Newtonsoft.json 11，另一个依赖于 Newtonsoft.json 12。那么根据加载执行的顺序不同，可能会出现依赖冲突：
 - A -> Newtonsoft.json 11
 - B -> Newtonsoft.json 12

Powershell 和 .Net 在加载依赖时，并不会把依赖库在启动时直接加载到内存中，而是会等到第一次执行到相关代码时，才从磁盘上加载，这样避免了无效的内存使用 （也叫 Lazy Loading）。但这也意味着，根据代码执行的顺序不同，加载的依赖库版本也可能不同，有可能会加载高版本的依赖库，也可能会先加载低版本的依赖库。

例如：
```powershell
[libA]::init() # Load Newtonsoft.json 11
[libB]::init() # Load Newtonsoft.json 12
Could not load file or assembly 'Newtonsoft.json, Version=12.0 ...'. 
```
库 A 的代码先被执行，导致 Newtonsoft.json 11 先被加载到内存中。如果后来我们需要执行库 B 的代码，需要一个 Newtonsoft.json 12 的依赖库，就会报无法找到 Newtonsoft.json 12 的错误。

```powershell
[libB]::init() # Load Newtonsoft.json 12
[libA]::init() # Load Newtonsoft.json 11
# All works well, no error
```
反之，如果我们先执行了库 B 的代码，加载了 Newtonsoft.json 12 的依赖库，再执行库 A 的代码，由于 Newtonsoft.json 12 反向兼容 Newtonsoft.json 11 的功能，就没有报错了。

**所以在 Powershell 中遇到依赖冲突的问题时，可能会出现修改库的调用顺序就解决了冲突的诡异情况。** 这虽然可以暂时解决问题，但是代码不再健壮，因为代码的执行逻辑中隐含了依赖冲突的管理，而不仅仅是业务逻辑本身。如果未来有人不小心修改了代码，就会重新出现这个问题。

#### 根本上解决依赖冲突的方法

由于 Powershell 加载 .Net 库时，本质还是使用 .Net 的依赖管理方法。所以要根本上解决依赖冲突，还是需要先了解依赖的加载机制，然后再正确地管理依赖。在微软的开发者博客中给出了几种解决方案，[原文地址见文末](https://devblogs.microsoft.com/powershell/resolving-powershell-module-assembly-dependency-conflicts/)：
1. 修改依赖库使其依赖的版本相同。但是只有 Powershell 中直接引用的库才有可能修改，这是个很正确的废话，不太实用。
2. 实现 AssemblyResolve event handler 的回调，从而手动指定某个库的版本。这个方法看起来很通用，但是 powershell 中并不是所有线程的回调都能处理的，而且这个方法实现起来也并不直观，比较麻烦。
3. 在加载 dll 时，指定不同的 Load Context，使得有冲突的库可以在不同的 Load Context 中加载，也就不会出现版本冲突的问题。但这个方法也有弊端，例如在两个 Load Context 中加载了同样的一个类，在 `A` Load Context 中加载的类，是不能 Cast 转换到另一个 `B` Load Context 的，也就意味着明明是相同类型的实例，却不能互相转换。同时这个方法在 powershell 中实现起来也很麻烦。[例如这个代码例子](https://github.com/PowerShell/PowerShellEditorServices/blob/master/src/PowerShellEditorServices.Hosting/Internal/PsesLoadContext.cs)
4. 将某个会导致冲突的依赖库放到子进程中调用，由于进程之间的隔离，依赖库也会被独立加载。例如 `pwsh -c 'Invoke-ConflictingCommand'`。
   - 这个方案也引申出了一个优化的用法：使用 Powershell 的 Job 来进行子进程的调用和结果获取：`$result = Start-Job { Invoke-ConflictingCommand } | Receive-Job -Wait`

其中**第4种方案**是我主要使用的，原因是：
1. 我的脚本对性能没有要求，1分钟跑完也可以，5分钟跑完也可以，所以启动新进程带来的性能开销是可接受的。
2. 代码模块化强，可维护性强。我把不同 C# dll 里库的调用封装进了不同的 Powershell 脚本并使用 Job 系统来调用，一来可以利用 Job 的异步特性，并行执行脚本，同时也避免了依赖冲突。

但这个方案也有一定的局限性：
1. 由于 C# dll 的调用是在 Job 中进行的，当有错误出现时，排查错误的过程并不是很直观，StackTrace 只局限在单一进程中。
2. 如果返回的结果是一个 C# dll 中定义的类，调用类获得的是一个 PSObject 而不是 C# 中定义的类。

总而言之，通过 `Start-Job` 封装冲突库的调用，可以比较容易的解决大部分 Powershell 中的依赖冲突。

### 错误排查

对于不够熟悉 Powershell 开发的人来说，错误排查也是个难点。

对于 Powershell 中的异常，除了 try catch 之外，还有一些简单的方法来获取它的信息，例如 `$Error` 变量中储存了过去这个进程中的错误信息，同时我们可以用 `$Error[0].Exception` 获取异常的细节，例如：
 - 报错信息：`$Error[0].Exception.Message`
 - 更深层的异常：`$Error[0].Exception.InnerException`
 - 异常的类型：`$Error[0].Exception.GetType()` 
 - 异常的调用点：`$Error[0].Exception.InvocationInfo` 
 - 异常的调用栈：`$Error[0].Exception.StackTrace` 

更完整的文档可以在这里找到：https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions?view=powershell-7.2

有了这些信息，Powershell 中的错误排查也不是那么难了。然而对于 C# dll 中的异常，是更为棘手的。如果 dll 文件没有对应的 pdb 文件，则没有办法对编译后的符号进行解释，也就只能看到异常的文字信息，看不到导致异常的行数和变量信息。

对于 C# dll 中的异常，我也没找到很好的办法 debug，更多是像一个黑盒一样，通过不停尝试找到正确的 API 用法。

### 强弱类型混合

在 Powershell 脚本开发的过程中，当我们混合使用 C# 声明的类和 Powershell 中的字典、数组时，常常会出现他们可以相互替换的情况。例如：

```powershell
PS> $tempDict = [ordered]@{}  # Powershell dictionary
PS> $result1 = $tempDict[$key]  # result1 is null
PS> $key
abcd
PS> $result2 = $tempDict["abcd"]  # result2 is not null
PS> ($key -eq "abcd")   # Try to compare $key, return True
True
```

在这个场景中，`$tempDict` 是一个 Powershell 中的字典，而 result1 是尝试用变量 key 获取字典中的值，此时获取出来的是 null。但是当我手动输入字符串 "abcd" 时，却可以获取到字典中的值。更诡异的是当我尝试对比 key 与手动输入的字符串 “abcd" 时，返回的结果是相同。那**为什么相同的输入，一个使用变量，一个使用临时字符串，结果就不同呢？**

最终我还是把问题关注在 key 变量上，**最后发现 key 变量是一个 Enum 值为 "abcd" 的 Enum 实例**。这也就解释了之前诡异的现象：由于 Enum 类型与字符串类型不同，所以字典索引时返回的结果不同，而由于 Enum 在输出成 string 时，会将 Enum 对应的值输出，导致输出的结果也是和字符串 "abcd" 相同的。

在这类问题的排查时，由于 Powershell 的弱类型特性，可能会让我们多花一些时间。

## Powershell方案的优缺点

使用 Powershell 而不使用 C# 项目来实现某些功能，有很显著的优势：
1. **可以快速进行原型的开发。**例如需要将某些第三方库的功能组合起来，自动地完成 A 之后再做 B。与使用 C# 项目相比，省了不少配置项目、打包部署的时间。
2. **方便在生产环境中调试，但在生产环境调试并不提倡**。在生产环境出 bug 时，如果测试环境无法复现、开发环境的日志打印又不到位，要调试一个 C# 项目就需要不断地加日志、编译、复制二进制文件、重跑某个任务才行，这个流程和周期是很繁琐的。而基于 Powershell 就可以很容易地直接修改部分脚本并重试。
3. 和其他脚本语言一样，容易作为胶水代码连接不同语言的工具使用。

使用 Powershell 调用 C# 代码的问题也并不少：
1. 容易出现依赖冲突，而为了解决依赖冲突，会需要对 C# dll 调用的代码进行额外封装和调试。
2. 不容易写单元测试。虽然有 PSUnit 之类的单元测试框架，但易用性和可调式性还是差了一些。
3. 强弱类型混用可能导致难以排查的 bug。
4. C# dll 中的报错不容易进行排查。

优缺点主要还是围绕**易用性**和**可维护性**展开的，如果是为了临时使用或者功能比较局限，那么用 Powershell 来替代正式的 C# 项目也不失为一个好的选择。

## 引用
 - Resolving PowerShell Module Assembly Dependency Conflicts: 
   - [https://devblogs.microsoft.com/powershell/resolving-powershell-module-assembly-dependency-conflicts/](https://devblogs.microsoft.com/powershell/resolving-powershell-module-assembly-dependency-conflicts/)
 - Best Practices for Assembly Loading:
   - [https://docs.microsoft.com/en-us/dotnet/framework/deployment/best-practices-for-assembly-loading](https://docs.microsoft.com/en-us/dotnet/framework/deployment/best-practices-for-assembly-loading)
 - Everything you wanted to know about exceptions：
   - [https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions?view=powershell-7.2](https://docs.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-exceptions?view=powershell-7.2)



---




















