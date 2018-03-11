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

## Preface

Grpc is an open-sourced rpc framework developed by google。It support both unary remote procedual call and bi-directional streaming. For those who wants to build a client-server bi-directional persistent connection, it's a simple and modern solution.

Grpc itself support multiple language and multiple platform, but Unity is not one of them for now.

Even though we develop most of the Unity project in C#, the Unity runtime is not running C# script directly. On Unity iOS platform specifically, it will use L2CPP (An ahead-of-time compiler) to translate c# script into c++ code, then finally compile and run on iOS devices. For us, if we want to use grpc in Unity project, we have some additional work to do.

---

## Testing grpc C# library 

First of all, we can directly copy the [grpc c# source code](https://github.com/grpc/grpc/tree/master/src/csharp) into Unity project and use [route guide example](https://github.com/grpc/grpc/tree/master/examples/csharp/route_guide) to test the basic feature of grpc.

During compilation, we will find the C# grpc library is depend on [Grpc.Core](https://www.nuget.org/packages/Grpc.Core/) Library. *Grpc.Core* is a C library and official C# grpc library compile *Grpc.Core* into a shared library. Since iOS application can only depend on static library, we have to static compile the *Grpc.Core* library and use it in iOS devices. 

Why don't we just copy the C code into the xcode project and use xcode to pull it in? In the core library, there are bunch of relative include like *#include "src/core/..."*, which is not easy to work around in xcode project.

## Generate static library for arm64 platform

During this blog, we are focusing on iOS arm64 platform as an example, for other platform this might be apply.

Since iOS need an static linked library instead of dynamicly load shared library, we can't simply use the packge from *nuget.org*. If we are simply supporting iOS arm64 architecture, we can just set the build target to arm64 and compile it on a arm64 machine (eg. Mac OS X)

If we want to support all architecture, then we will need to cross-compile a [fat binary](https://en.wikipedia.org/wiki/Fat_binary)

### Change Makefile

We can make some changes to the official Makefile for grpc.core, then the binary will be able to use in iOS build. There are two things we need to change.

 - Add -isysroot config. This decides which version of iOS we can support, using a lower level of OS can make it more compatible.
 - Add -arch arm64 to make sure it build for arm64

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

Then run

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

Now we have the library we need to grpc runtime. We can copy the `libgrpc.a` to Unity project `Assets/Plugins/iOS` directory. Unity will ensure this library is added to the link line of the xcode project.

### build grpc c# extension library

Besides the grpc.core static library, we also need a csharp specific library, we can get the library by running:

```
➜  grpc git:(v1.4.x) ✗ clang -arch arm64  -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS10.3.sdk -I. -I./include -c -o grpc_csharp_ext.o src/csharp/ext/grpc_csharp_ext.c
➜  grpc git:(v1.4.x) ✗ ar -rsc grpc_csharp_ext.a grpc_csharp_ext.o
```

Then we will copy `grpc_csharp_ext.a` into Unity project's `Assets/Plugins/iOS` directory.

**Some thing to note:** If you want to support [App thining](https://docs.unity3d.com/Manual/AppThinning.html) feature, which will require a bitcode support of all dependent library. In order to generate a bitcode enabled library, we need to:

1. Use clang as our compiler.
2. Add option `-fembed-bitcode` to the compilation flags.

## Change Grpc.Core code to use static link

Since we are using static link instead of dynmaic load, we need to change the source code of Grpc.Core. Here are some related code:

```git
    modified:   src/csharp/Grpc.Core/Internal/DefaultSslRootsOverride.cs
    modified:   src/csharp/Grpc.Core/Internal/NativeExtension.cs
    modified:   src/csharp/Grpc.Core/Internal/NativeLogRedirector.cs
    modified:   src/csharp/Grpc.Core/Internal/NativeMethods.cs
```

Now let's take a look at each file

### DefaultSslRootsOverride.cs

First of all, in `DefaultSslRootsOverride.cs`，grpc loaded the local certificate file, I guess it's used for certificate pinning. We can remove this part, if you need it, just change it to the certificate you need.

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

In the function `Load()`, we need need to make two changes:

**On iOS platform, we don't need to load dynamic library, but on Unity Editor, we still need to load dynamic library, let's use a simple Unity Macro to differentiate them:**

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

**On PC or MAC, we need to load dynamic library, but the path should be modified:**

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

When C code in Grpc.Core calls C# code, it was not able to find the correct reference. This is because during IL2CPP compilation, a [name mangling](https://www.ibm.com/support/knowledgecenter/en/ssw_ibm_i_72/rzarg/name_mangling.htm) process happened, the name of the function is wrapped by namespace and class name. We can attonate the function name by `MonoPInvokeCallback`, which will help Untiy IL2CPP to understand which method might get called from C code.

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

We can also change the log function to Unity Debug Log：

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

In this file, grpc invoked the c code in `Grpc.Core` library. In Unity, if we want to call into native code or invoke method in assembly, we need to [define the assembly source](https://docs.unity3d.com/Manual/PluginsForIOS.html). And we also need to define each native call and add `Dllimport()` decorator to each method that need to be called.

Since iOS is using static compiling, so we use "__Internal" for iOS platform.

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

Define each method that needs to be called and add `Dllimport` decorator.


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

Change the way we initialize the method.

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

We simplfied the process of this change. This is mostly copy-pasting work. Almost all the method in this file need to make above three changes we made to`grpcsharp_init`. To simply this blog, I didn't copy the full diff here.

### Compile and test

Finally, I use the [route guide example](https://github.com/grpc/grpc/tree/master/examples/csharp/route_guide) to test the basic feature of grpc, like unary call, bi-directional streaming. They all works fine.

The only thing that seems weird to me is during clean up. After we close the connection to server, we will need to call `channel.Dispose()` to release the resource of grpc connection, otherwise, Unity will hang and seems waiting for the thread to exit. I'm not sure about the root cause of this problem, official demo didn't call `Dispose` explicitly.

### Conclusion

This is a relative tedious work to make grpc work on Unity. I did quite a lot of research, the only project I found is [Magic Onion Project](https://github.com/neuecc/MagicOnion). This project makes a lot of Unity specific change to make grpc work on it. Since Unity was not supporting .Net 4.6 (now they do), even the async mechanism needs a special implementation. Now, Unity provide a beta release of .Net 4.6 support, I believe this will become the mainstream support, so I just focus on making grpc work on .Net 4.6.

Even we make it work on iOS, it will still take tremendous effout to make it work on Android, Windows, Xbox and etc.

---

If you like my blog, please checkout [other posts](http://chendi.me/)。O(∩_∩)O
