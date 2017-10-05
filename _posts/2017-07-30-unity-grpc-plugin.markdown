---
layout:     post
title:      "Support grpc library on Unity"
subtitle:   "在 Unity 开发中使用 grpc 组件"
date:       2017-07-30 00:15:00
author:     "Di Chen"
header-img: "img/in-post/unity-arkit-plugin-opengl/arkit-bg-1.jpg"
tags:
    - Tech
    - Unity 
    - grpc
---

## 前言

grpc 是由 google 推出的开源 rpc 框架。除了支持单向的 rpc 调用之外，同时还支持双向流通信，对于想要快速搭建一个基于长连接的应用是个不错的选择。

由于 Unity 本身的特性，虽然它是使用 C# 进行编程的，但是在打包成 iOS 或者安卓的时候需要进行一次转换，将 C# 代码转译成 C++ 代码，所以我们需要进行一些额外的工作，将 grpc 的 C# 库转为支持 Unity 的版本。

---

## C# 脚本初步测试

首先，我们可以直接将 [grpc 的官方库](https://github.com/grpc/grpc/tree/master/src/csharp) 的代码文件拷贝进工程中，并且用 [route guide example](https://github.com/grpc/grpc/tree/master/examples/csharp/route_guide) 来测试一下在 Unity 中 grpc 是否能用。

在编译时，我们会发现它依赖于 [Grpc.Core](https://www.nuget.org/packages/Grpc.Core/) 库，这个库是一个基于 C 的底层库，并不是由 C# 编写的。 nuget 包生成的 c# 动态库并不能直接使用，因为 iOS 是静态编译的，所以这是我们第一个要为 Unity 处理的部分。

## 生成 arm64 平台上可用的静态库

由于 iOS 是静态编译后生成一个可执行文件的，所以官方提供的 C# 动态库就不可用了，这时候我们需要自己编译一个静态库。 iOS 平台使用的架构是 arm 架构，由于现在基本都是64位的 iphone，所以直接用 arm64 作为目标平台即可。

### 修改 Makefile

在官方提供的 grpc.core 的 Makefile 中，我们稍作修改，可以将编译出的 .a 文件调整为 arm64 架构下可用的。其中 iPhone SDK 的版本可根据自行需求进行修改。

```diff
 VALID_CONFIG_opt = 1
-CC_opt = $(DEFAULT_CC)
-CXX_opt = $(DEFAULT_CXX)
+IOSFLAGS =  -arch arm64  -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS10.3.sdk -fembed-bitcode
+CC_opt = $(DEFAULT_CC) $(IOSFLAGS) 
+CXX_opt = $(DEFAULT_CXX) $(IOSFLAGS)
 LD_opt = $(DEFAULT_CC)
 LDXX_opt = $(DEFAULT_CXX)
 CXXFLAGS_opt = -fno-exceptions
@@ -339,7 +340,7 @@ HOST_LDXX ?= $(LDXX)
 
 CFLAGS += -std=c99 -Wsign-conversion -Wconversion $(W_SHADOW) $(W_EXTRA_SEMI)
 CXXFLAGS += -std=c++11
-CPPFLAGS += -g -Wall -Wextra -Werror -Wno-long-long -Wno-unused-parameter -DOSATOMIC_USE_INLINED=1
+CPPFLAGS += -g -Wall -Wextra -Wno-long-long -Wno-unused-parameter -DOSATOMIC_USE_INLINED=1
 LDFLAGS += -g
```

然后运行

```bash
➜  grpc git:(v1.4.x) ✗ make
...
...
➜  grpc git:(v1.4.x) ✗ ls ./libs/opt/*.a
./libs/opt/libares.a                ./libs/opt/libgrpc_cronet.a
./libs/opt/libboringssl.a           ./libs/opt/libgrpc_plugin_support.a
./libs/opt/libgpr.a                 ./libs/opt/libgrpc_unsecure.a
./libs/opt/libgrpc.a                ./libs/opt/libz.a
```

此时我们就有了 runtime 所需的静态库，我们将 `libgrpc.a` 复制到 `Assets/Plugins/iOS` 文件夹中，这样在导出 xcode 工程时就会自动加入 xcode 项目 link line 中。

### 获取 C# 客户端所需的静态库

除了 grpc.core 的静态库之外，我们还需要一个 csharp 的特制静态库，可以通过以下命令获得：

```
➜  grpc git:(v1.4.x) ✗ gcc -arch arm64  -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS10.3.sdk -I. -I./include -c -o grpc_csharp_ext.o src/csharp/ext/grpc_csharp_ext.c
➜  grpc git:(v1.4.x) ✗ ar -rsc grpc_csharp_ext.a grpc_csharp_ext.o
```

然后再将 grpc_csharp_ext.a 复制到 `Assets/Plugins/iOS` 文件夹中。

## 修改 Grpc.Core 代码中的动态库加载

为了应对 Grpc.Core 实现中使用的动态库加载，与 iOS 静态编译的做法冲突的情况，我们需要修改一下文件：

```git
    modified:   src/csharp/Grpc.Core/Internal/DefaultSslRootsOverride.cs
    modified:   src/csharp/Grpc.Core/Internal/NativeExtension.cs
    modified:   src/csharp/Grpc.Core/Internal/NativeLogRedirector.cs
    modified:   src/csharp/Grpc.Core/Internal/NativeMethods.cs
```

下面我们一个一个来看。

### DefaultSslRootsOverride.cs

首先是 `DefaultSslRootsOverride.cs` 文件中，加载了预存在本地的证书文件，应该是用来做 certificate pinning 的吧。这部分可以暂时去掉，等需要用到这部分功能时再加入。

```diff
--- a/src/csharp/Grpc.Core/Internal/DefaultSslRootsOverride.cs
+++ b/src/csharp/Grpc.Core/Internal/DefaultSslRootsOverride.cs
@@ -56,6 +56,7 @@ namespace Grpc.Core.Internal
         {
             lock (staticLock)
             {
+                               /*
                 var stream = typeof(DefaultSslRootsOverride).GetTypeInfo().Assembly.GetManifestResourceStream(RootsPemResourceName);
                 if (stream == null)
                 {
@@ -66,6 +67,7 @@ namespace Grpc.Core.Internal
                     var pemRootCerts = streamReader.ReadToEnd();
                     native.grpcsharp_override_default_ssl_roots(pemRootCerts);
                 }
+                */
             }
         }
     }
```

### NativeExtension.cs

在这里我们需要修改动态库加载的函数 `Load()`，要做两部分考虑：

**在 iOS 平台上，不需要加载动态库，可以直接跳过这个函数的逻辑，使用 Unity Macro 来实现:**

```diff
--- a/src/csharp/Grpc.Core/Internal/NativeExtension.cs
+++ b/src/csharp/Grpc.Core/Internal/NativeExtension.cs
@@ -93,7 +93,10 @@ namespace Grpc.Core.Internal
         /// Detects which configuration of native extension to load and load it.
         /// </summary>
         private static UnmanagedLibrary Load()
-        {
+               {
+                       #if UNITY_IOS
+                               return null;
+                       #endif
```

**在 PC 或者 MAC 上，仍然要加载动态库并且运行，否则就无法在 PC 或者 Mac 上调试游戏了，所以我们需要修改一下寻找插件的路径：**

```diff
@@ -111,8 +114,10 @@ namespace Grpc.Core.Internal
             var netCorePublishedAppStylePath = Path.Combine(assemblyDirectory, runtimesDirectory, GetNativeLibraryFilename());
             var netCoreAppStylePath = Path.Combine(assemblyDirectory, "../..", runtimesDirectory, GetNativeLibraryFilename());
 
+                       var unityPath = Path.Combine (assemblyDirectory, "../../Assets/Plugins/GrpcLib", runtimesDirectory, GetNativeLibraryFilename ());
+
             // Look for all native library in all possible locations in given order.
-            string[] paths = new[] { classicPath, netCorePublishedAppStylePath, netCoreAppStylePath};
+                       string[] paths = new[] { classicPath, netCorePublishedAppStylePath, netCoreAppStylePath, unityPath};
             return new UnmanagedLibrary(paths);
         }
```

### NativeLogRedirector.cs

在 C 代码回调 C# 代码时，由于 IL2CPP 会对函数名进行 [name mangling](https://www.ibm.com/support/knowledgecenter/en/ssw_ibm_i_72/rzarg/name_mangling.htm)，所以会找不到函数，所以需要用 `MonoPInvokeCallback` 进行修饰，避免因为名称改变而无法调用：

```diff
--- a/src/csharp/Grpc.Core/Internal/NativeLogRedirector.cs
+++ b/src/csharp/Grpc.Core/Internal/NativeLogRedirector.cs
@@ -66,6 +66,7 @@ namespace Grpc.Core.Internal
             }
         }
 
+        [AOT.MonoPInvokeCallback(typeof(GprLogDelegate))]
         private static void HandleWrite(IntPtr fileStringPtr, int line, ulong threadId, IntPtr severityStringPtr, IntPtr msgPtr)
         {

```

另外可以修改一下输出到 Console 时调用的函数：

```diff
@@ -97,7 +98,11 @@ namespace Grpc.Core.Internal
             }
             catch (Exception e)
             {
-                Console.WriteLine("Caught exception in native callback " + e);
+#if UNITY_METRO
+                               UnityEngine.Debug.Log("Caught exception in native callback " + e);
+#else
+                               Console.WriteLine("Caught exception in native callback " + e);
+#endif
```

### NativeMethods.cs

在这里，grpc 调用了 Grpc.Core 中的 C 代码。在 Unity 中，需要使用 [Unity 官方要求的方式](https://docs.unity3d.com/Manual/PluginsForIOS.html)，定义原生函数的原型，并且在初始化时，设置进去。

由于 iOS 上用的是静态编译，所以当平台为 iOS 时，pluginName 设为 "__Internal"

```diff
--- a/src/csharp/Grpc.Core/Internal/NativeMethods.cs
+++ b/src/csharp/Grpc.Core/Internal/NativeMethods.cs
@@ -51,6 +51,14 @@ namespace Grpc.Core.Internal
     /// </summary>
     internal class NativeMethods
     {
+#if UNITY_EDITOR               
+               private const string pluginName = "grpc_csharp_ext";            
+#elif UNITY_IOS || UNITY_TVOS || UNITY_WEBGL           
+               public const string pluginName = "__Internal";          
+#else          
+               public const string pluginName = "grpc_csharp_ext";             
+#endif
+
```

定义 C API

```diff
+               static class NativeCalls
+               {
+                       [DllImport(pluginName)]
+                       internal static extern void grpcsharp_init();
+
+                       [DllImport(pluginName)]
+                       internal static extern void grpcsharp_shutdown();
...
...
```

修改初始化方式

```diff
         public NativeMethods(UnmanagedLibrary library)
         {
+               #if UNITY_IOS
+                       this.grpcsharp_init = NativeCalls.grpcsharp_init;
+                       this.grpcsharp_shutdown = NativeCalls.grpcsharp_shutdown;
+                       this.grpcsharp_version_string = NativeCalls.grpcsharp_version_string;
...
...
```

上面这部分代码 diff 省略了许多函数，基本上所有 Grpc.Core 中的函数都需要和 `grpcsharp_init` 一样的处理，由于篇幅限制，就不把所有函数都的 diff 都放上来了。

### 调试打包

在最后，我们在真机和 Unity Editor 中测试了一下，所有类型的 grpc 请求都可以正常进行。唯一有些意外的就是，在资源释放时，记得要调用 `channel.Dispose()`，如果不调用的话，进程就会卡死。这个原因目前没有去仔细研究过，官方 demo 中似乎也没有。

### 经验总结

这个问题其实相对也是比较棘手的，查了许多资料，也参考了一下日本游戏界前辈的做法 [Magic Onion Project](https://github.com/neuecc/MagicOnion)。不过在解决的时候没有马上把博客写出来，所以现在总结起来也没有太多感想了。

以后就算是忙，也还是要及时总结才行。

---

如果你看到这里，一定是真爱！欢迎看看我的其他 [blog](http://chendi.me/)。O(∩_∩)O
