---
layout:     post
title:      "Docker Container on Windows"
subtitle:   "Windows 上 docker 容器的实现"
date:       2022-10-09 10:15:00
author:     "Di Chen"
catalog:    true
header-img: "img/in-post/cover/docker.jpg"
tags:
    - tech
---

## 前言

最近接触了一些 Windows 容器相关的项目，也借此机会深入学习了一下容器实现的底层原理，比如 cgroups，namespace 和 union filesystem。同时由于 Windows 和 Linux 有所区别，对比两个操作系统的实现，也可以更直观地对容器的优缺点有更深入的理解。

这篇博客会介绍对比 Linux 容器和 Windows 容器在实现上的区别，以及在使用时需要注意的地方。为了方便起见，下文中均以 docker 作为容器实现的例子。

## 容器的底层机制

容器的本质，其实是利用操作系统的一系列功能，让一个进程在运行的时候像在一个独立的 VM 里一样。那么为了实现这个效果，就需要：
1. Namespace: 让这个进程以及其相关的子进程只能看到 “容器内” 的其他进程和资源，使得容器之间相互无感知。
2. cgroup: 让这个进程以及其相关的子进程只使用限制范围内的资源，例如 CPU、内存等，而不超过所规定的上限。
3. Union FS: 让这个进程可以有一个独立的可读写的文件系统。
4. Layered FS: 让这个进程的文件系统可以被储存、打包、分发。

接下来我们一起看看这几个工具在 Linux 上和 Windows 上的实现都有什么区别。

[![docker-on-linux.png](/img/in-post/windows-container/docker-on-linux.png)](/img/in-post/windows-container/docker-on-linux.png)

图片来源：[https://learn.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/containerd](https://learn.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/containerd)

### Cgroup

Cgroup 是这几个概念中最容易理解的。从很早的时期开始，系统管理员就希望能将一组进程一起管理，对其增加 CPU、内存、网络等资源的使用限制，从而避免多租户服务器上的 noisy neighbor 问题。

所以 Linux 内核早在 2007 年便有了 control group 的概念，也就是 cgroup，它可以对一组进程进行资源的监控和限制。而 Windows 也在 2008 年增加了 Job Object 的概念，和 cgroup 是同样的作用。

用 Windows 的 [Process Explorer](https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer) 可以查看到每个进程对应的 Job Object ID：

[![windows-job-object-2.jpeg](/img/in-post/windows-container/windows-job-object-2.jpeg)](/img/in-post/windows-container/windows-job-object-2.jpeg)

 以及这个 Job 内的其他进程：

[![windows-job-object-1.png](/img/in-post/windows-container/windows-job-object-1.png)](/img/in-post/windows-container/windows-job-object-1.png)


### Namespace

有了 cgroup 之后，我们便可以限制一组进程以及其子进程的资源使用了。但是这只能起到保护进程的作用，并不能使他们之间无感知，而后 Linux 还增加了 Namespace 的概念。Linux 中的 Namespace 可以使一组进程只能看到 Namespace 中的系统资源，例如 process id，network device，user，cgroup 之类的。

Linux 通过一系列 flag 可以控制限制所有资源或者只控制一小部分资源的可见性，例如：
 - CLONE_NEWNET：隔离网络设备
 - CLONE_NEWUTS：隔离主机名和域名 UTS = UNIX Timesharing System
 - CLONE_NEWIPC：隔离跨进程通信的对象 IPC = Interprocess Communication，包括 shared memory 等。 
 - CLONE_NEWPID：隔离进程 ID
 - ...

然而 Windows 在实现容器之前，并没有这样的需求：在同一个内核上运行的进程，相互之间无感知。所以 Windows 为了实现容器而新加了一个叫 “Silo” 的内核对象。

在解释 Silo 之前，先要从 Windows 的根对象开始讲起。Windows 是和 Linux 一样有一个根对象`\`的。Windows 上的各类资源都是挂载在一个根对象上的。如果我们可以像 Linux 上的 chroot 一样修改 Windows 的根对象，那么就可以比较容易地隔离 Windows 上资源的可见性了。

我们可以下载[winobj 工具](https://learn.microsoft.com/en-us/sysinternals/downloads/winobj) ，从而查看电脑上的对象目录：

[![windows_root_obj.jpeg](/img/in-post/windows-container/windows_root_obj.jpeg)](/img/in-post/windows-container/windows_root_obj.jpeg)

可以看到一些我们常见的系统资源，比如：

 - 盘符 D:\ `\Global??\D:`
 - 注册表 `\Registry`
 - 设备信息 `\Device\`
 - TCP `\Device\TCP`

当我们创建一个新的 Windows Docker 容器后，我们会发现在 `\Silos` 对象下多了一个子对象 `380`，而子对象的内容和根对象非常相似。而这个子对象`\Silos\380`代表的就是容器中的根对象。

[![silos.jpeg](/img/in-post/windows-container/silos.jpeg)](/img/in-post/windows-container/silos.jpeg)

当一个 Windows 容器中的进程需要调用系统 API 时，例如调用一个 NTFS 的创建文件 API `NtCreateFile` 时，内核会调用 `PsGetCurrentSilo` 去获取调用进程是否是挂载到某个 Silo 里的，从而判断要不要使用 Silo 中的对象作为根对象。同时，部分内核的 API 也可以根据这个判断是否要拒绝某些危险的 API 调用，例如加载内核驱动之类的，从而防止容器逃逸等安全问题。

但是 Windows 的 Silo 并不能使得所有容器共享 Windows 的 System Service，例如 Identity Service，COM System Application 等。Windows 的一些操作系统能力是通过动态加载 dll，然后发送 RPC 请求给 System Service 来实现的。比如 DHCP 网络配置就需要 DHCP service 的运行来配合。在 Windows 容器中，如果需要使用这些 Service，就需要它们运行在容器内，如果运行在容器外，容器内就用不了这些 Service。至于为什么要这样设计，我认为主要是隔离 RPC 请求太难了，因为 RPC 请求的参数是容器内的应用可以修改的，如果容器内的应用模仿其他容器的 Silo ID，从 RPC 的层面不好分辨。

[![process-isolation.png](/img/in-post/windows-container/process-isolation.png)](/img/in-post/windows-container/process-isolation.png)

于是 Windows 容器中除了要运行的应用进程，还会有 System Service 的进程。这就导致了 Windows 容器的启动比较慢，因为它需要先启动系统的一些 Serivce。同时为了把这些 System Service 打包进镜像，镜像也会比较大。我们可以运行一个 Windows 容器，然后用 powershell 的 `Get-Service` 命令查看有哪些 Service:

```Powershell
PS C:\> get-service

Status   Name               DisplayName
------   ----               -----------
Stopped  AppIDSvc           Application Identity
Stopped  AppMgmt            Application Management
Stopped  AppReadiness       App Readiness
Stopped  AppXSvc            AppX Deployment Service (AppXSVC)
Stopped  BFE                Base Filtering Engine
Stopped  BITS               Background Intelligent Transfer Ser...
Stopped  CertPropSvc        Certificate Propagation
Running  cexecsvc           Container Execution Agent
Stopped  ClipSVC            Client License Service (ClipSVC)
Stopped  COMSysApp          COM+ System Application
Running  CoreMessagingRe... CoreMessaging
Running  CryptSvc           Cryptographic Services
Running  DcomLaunch         DCOM Server Process Launcher
...
...
```

### UnionFS

Union File System 提供了可以将多个文件目录合并的能力，在使用者看来是一个完整的文件系统。它最早是在名为 Knoppix 的 Linux 发行版中被引入的，Knoppix 提供了 LiveCD 的演示功能，可以使用 CD + USB 作为文件系统，CD 作为只读的文件层，USB 作为可读写的文件层。在 Linux 上也迭代多年并又了多个不同的实现，例如 aufs, overlayfs, btrfs 等。

[![unionfs.png](/img/in-post/windows-container/unionfs.png)](/img/in-post/windows-container/unionfs.png)

容器便是利用 Union FS 的可分层和可合并的特性，实现了容器的快速启动、整体打包分发等功能。当一个容器镜像被创建出来时，往往会分成操作系统的文件层、镜像创建时添加的应用层，以及最终在容器执行时添加的可读写层。利用 Union FS 将这 3 层合并在一起，如果需要访问底层的文件，则可以像原生文件系统一样直接读取，没有太多额外开销，如果需要写入新文件，也可以写入到最上层的可读写层，额外开销也很小。

[![containerfs.jpeg](/img/in-post/windows-container/containerfs.jpeg)](/img/in-post/windows-container/containerfs.jpeg)

而在 Windows 上，大多数应用使用的是 NTFS 的文件系统 API，NTFS 没有类似 Union FS 的功能。如果要在 NTFS 上实现 Union FS 的功能，就需要对许多 NTFS 的功能进行重构重写，例如 Transactions, file ID, USN jounals 等等。所以最终 Windows 采用了一个混合模式：
1. 每个容器创建一个可读写的虚拟磁盘 .vhd
2. 将只读的容器层用 Symlink 的方式添加到虚拟磁盘中
3. 用 NTFS 文件系统的 file system filter driver 对文件的访问进行过滤，实现上层文件遮盖下层文件的效果。

所以当我们在 windows 上创建新容器时，也会在磁盘管理器中发现有新的虚拟磁盘被创建出来：

[![dockervhd.png](/img/in-post/windows-container/dockervhd.png)](/img/in-post/windows-container/dockervhd.png)

Windows 还有一个比较特别的，就是注册表。注册表在几乎所有应用中都会用到，访问频次很高，并且 API 比较简单。所以 Windows 容器中针对注册表实现了一个完整的 Union FS 功能。、

有了 UnionFS 之后，也就有了 Layer 的能力，可以根据每个 Layer 做的操作，将那一层的文件系统打包起来，成为可分发的容器的一部分。

### 容器运行时

[![hcs.png](/img/in-post/windows-container/hcs.png)](/img/in-post/windows-container/hcs.png)

当我们了解了容器的三大底层机制在 Windows 上的实现后，我们还会在官网的架构图中发现一点不同，就是内核中多了一个 HCS (Host Compute Service)。这个服务存在的原因是 Windows 是一个闭源的操作系统，很多底层的 API 并不希望暴露给公众使用，同时也没有文档。为了能让开发者更容易地使用新开发的容器相关的功能，Windows 团队决定用一个新的服务来管理并提供底层的 API，这就是 HCS (Host Compute Service)。

[![docker-arch-compare.jpeg](/img/in-post/windows-container/docker-arch-compare.jpeg)](/img/in-post/windows-container/docker-arch-compare.jpeg)

我们结合两个操作系统的实现一起来看，除了底层的操作系统的修改之外，还需要更改的还有 Docker 引擎中容器运行时的工具 containerd 和 runc，也就是对应 dockerd 的部分。容器的运行时分为两个部分：
 - 一个是处理镜像拉取、打包、推送、启动、停止之类功能的 daemon process，也就是 containerd。
 - 另外一部分是专门从一个特定标准的文件夹中，读取容器的配置、文件层信息、索引信息，然后做配置容器、运行容器、停止容器等操作的库，也就是 runc。

对于 docker 这个容器运行时来讲，当我们执行 `docker run` 时，其实本质上是往 dockerd 发送了一个 REST 请求，dockerd 会调用 containerd 和 runc 来运行一个 container，然后返回 REST 响应。也有其他的容器运行时并不依赖 REST 请求，而是直接在子进程中启动容器进程的。

在 Windows 上，由于操作系统的不同，有很多底层的功能的 API 是不能一一映射的，比如 `fork()` 在 Linux 中是很常见的一个进程操作，但是在 Windows 中就没有完全对应的语义。所以最终 Windows Team 并没有在原本的 runc 上做修改，而是几乎重写了一份 Windows 上的 runhcs，用于读取 Windows 上的容器格式并启停容器。

### Windows Hyper-V 容器

Hyper-V 是 2008 年发布的虚拟机管理程序，在实现容器时，Windows 容器团队为了实现更好的隔离性，尝试用 hyper-v 作为隔离模式，实现了一个 Hyper-V 版的容器。

[![hyper-v-isolation.png](/img/in-post/windows-container/hyper-v-isolation.png)](/img/in-post/windows-container/hyper-v-isolation.png)

Hyper-V 版的容器其实本质上是一个轻量虚拟机，每个容器内部有一个完整的 Windows 内核。Hyper-V 容器和 Hyper-V 虚拟机主要区别在于，为了加快容器的启动速度，Windows 提前启动了一个 `Utulity Hyper-V VM`，同时把这个 VM 的内核状态和内存状态给持久化了下来，这样下一次启动 Hyper-V 容器时，就可以跳过 VM 的初始化阶段，直接进入容器的初始化阶段。

Hyper-V 容器提供的好处主要有两个：
1. 不要求宿主主机的 OS 版本和容器的一致，即使不兼容也可以运行，因为中间还有 Hyper-V 的虚拟化层。
2. 完整的虚拟化提供强隔离，安全性更好。

坏处也很明显：
1. 跟 Hyper-V 虚拟机相比，容器不能使用 UI。
2. 跟纯容器相比，资源浪费更多。

## 使用场景总结

Windows 容器的实现在很多地方和 Linux 容器很相似，但是最主要的区别在于，Windows 容器并不能做到完全共享系统服务，导致每个容器中还是需要启动一些系统服务来实现隔离性。这也导致了几个 Windows 容器的弊病：
1. 由于要启动系统服务，就需要把系统服务打包进容器，容器的镜像就会比较大。
2. 由于要启动系统服务，启动时间就比较长，需要若干秒。
3. 由于系统服务需要调用内核 API，所以系统服务的版本和宿主主机的版本需要兼容，不能像 POSIX 系统那样兼容和通用。

目前市场验证下来，最主要的使用场景还是 Lift and shift:
1. 希望更新迭代基础架构的管理方式，把应用都装进容器里，可以统一使用 DevOps 工具。所以启动时间、镜像大小并不是主要考量。
2. 希望可以上云，利用便宜的公有云平台，比如 AKS。即使算上启动时间、镜像大小，也还是比原有架构有优势。

## 参考资料

公开文档：

 - [https://docs.microsoft.com/en-us/virtualization/windowscontainers/​](https://docs.microsoft.com/en-us/virtualization/windowscontainers/​)
 - [https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/resource-controls​](https://docs.microsoft.com/en-us/virtualization/windowscontainers/manage-containers/resource-controls​)
 - [https://unit42.paloaltonetworks.com/what-i-learned-from-reverse-engineering-windows-containers/​](https://unit42.paloaltonetworks.com/what-i-learned-from-reverse-engineering-windows-containers/​)
 - [https://docs.microsoft.com/en-us/virtualization/community/team-blog/2017/20170127-introducing-the-host-compute-service-hcs​](https://docs.microsoft.com/en-us/virtualization/community/team-blog/2017/20170127-introducing-the-host-compute-service-hcs​)
 - [https://docs.microsoft.com/en-us/windows-server/networking/technologies/hcn/hcn-top](https://docs.microsoft.com/en-us/windows-server/networking/technologies/hcn/hcn-top)

DockerCon 演讲视频：
 - [https://www.youtube.com/watch?v=85nCF5S8Qok](https://www.youtube.com/watch?v=85nCF5S8Qok)

工具包：
 - WinObj: [https://learn.microsoft.com/en-us/sysinternals/downloads/winobj](https://learn.microsoft.com/en-us/sysinternals/downloads/winobj)
 - Process Explorer: [https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer](https://learn.microsoft.com/en-us/sysinternals/downloads/process-explorer)

---




















