---
layout:     post
title:      "Support OpenGL ES 2 on Unity ARKit Plugin"
subtitle:   "给 Unity ARKit Plugin 添加 OpenGL ES 2 的支持"
date:       2017-07-21 00:15:00
author:     "Di Chen"
header-img: "img/in-post/unity-arkit-plugin-opengl/arkit-bg-1.jpg"
tags:
    - Tech
    - Unity 
---

> “Visualization is daydreaming with a purpose.”
>
> -- Bo Bennett

## 前言

在 2017 年的 WWDC 苹果开发者大会上，苹果发布了自己的 AR 解决方案 -- ARKit。它结合了 iOS 设备自身传感器以及单目 SLAM 算法，在空间定位的能力上几乎可以与 Hololens 这样的外设相媲美了。

在第一时间，Unity 也发布了 ARKit 的插件：

 - [论坛讨论区](https://forum.unity3d.com/threads/arkit-support-for-ios-via-unity-arkit-plugin.474385/)
 - [官方 Bitbucket 代码库](https://bitbucket.org/Unity-Technologies/unity-arkit-plugin/)
 - [Unity商店（相对代码库更新较慢）](https://www.assetstore.unity3d.com/en/#!/content/92515)

---

## Unity 脚本初步测试

### 强大的空间定位能力

在测试使用了 Vuforia 和 Kudan 的 AR SDK 之后，苹果的 ARKit 确确实实是把 AR 体验提升了一个等级。Vuforia 的绝大部分定位能力来源于图像的特征点识别，而并没有过多的空间定位 处理能力。而 Kudan 的 AR SDK 并不依赖于图像的预处理，更多的是依赖于实时图像分析，追踪。这两个 SDK 是在 ARKit 发布之前我们能找到效果最好的 AR SDK，但是都不理想。

而苹果的 ARKit 则是结合了 iOS 设备自身传感器以及单目 SLAM 算法，在不依赖于提前环境建模的基础上，有着非常优秀的空间定位能力。除了在非常光滑平整的平面上，定位能力稍显不足，绝大部分室内室外场景的定位都是非常精确的。

### Unity 插件原理

在使用 Unity 插件之前，先学习了一下 ARKit 和 Unity 结合的方案。大概总结如下。

#### ARKit 提供自定义渲染机制

在 ARKit 追踪开始之后，摄像头的图像并不是可以自动显示到屏幕上的，特别是与第三方游戏引擎 Unity 结合的情况下。Unity 自身的渲染机制决定了：所有渲染到屏幕上的东西，都需要经过 Unity 引擎的处理。摄像头捕捉到的图像也是一样。

如果不使用 ARKit 的话，Unity 显示摄像头的图像可以用 [WebCamTexture API](https://docs.unity3d.com/ScriptReference/WebCamTexture.html) 来实现，Unity 已经封装好了获取摄像头并显示的逻辑。但是在使用 ARKit 之后，这个方案就不适用了。因为在开启 ARKit 之后，ARKit 需要访问摄像头获取图片，给 SLAM 算法提供分析用的数据。此时如果尝试获取摄像头的图片便会失败。

于是在官方的 ARKit 文档中，它提供了自定义渲染摄像头图片的方法: [ARKit 文档](https://developer.apple.com/documentation/arkit/displaying_an_ar_experience_with_metal)

[![官方示意图](/img/in-post/unity-arkit-plugin-opengl/arkit-custom-rendering.png)](/img/in-post/unity-arkit-plugin-opengl/arkit-custom-rendering.png)

在 ARKit 的 ARSession 中，用户可以获取到 ARFrame，在这个 ARFrame 中，我们可以通过 `capturedImage` 属性获取到像素点的缓存区。这个缓存区中以 YUV 的格式保存了图片的信息。官方的教程使用了 Metal 作为 GPU 渲染 API 来分别提取 Y 纹理和 UV 纹理：

```swift
func updateCapturedImageTextures(frame: ARFrame) {
    // Create two textures (Y and CbCr) from the provided frame's captured image
    let pixelBuffer = frame.capturedImage
    if (CVPixelBufferGetPlaneCount(pixelBuffer) < 2) {
        return
    }
    capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.r8Unorm, planeIndex:0)!
    capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.rg8Unorm, planeIndex:1)!
}

func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> MTLTexture? {
    var mtlTexture: MTLTexture? = nil
    let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
    let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
    
    var texture: CVMetalTexture? = nil
    let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat, width, height, planeIndex, &texture)
    if status == kCVReturnSuccess {
        mtlTexture = CVMetalTextureGetTexture(texture!)
    }
    
    return mtlTexture
}
```

这部分的代码也被 Unity 的 ARKit 插件用来获取 YUV 纹理了。

在获取到 YUV 纹理之后，官方建议使用 shader 将 YUV 纹理转换成 RGB 图片进行渲染，这样只需要获取 YUV 纹理的指针，而不需要在内存中进行保存，或者使用 CPU 进行计算。

#### Unity 原生纹理 API

在 Unity 的 ARKit 插件中，它用到了 [Texture2D.CreateExternalTexture](https://docs.unity3d.com/ScriptReference/Texture2D.CreateExternalTexture.html) 将 iOS 原生的纹理转换成 Unity C# 代码中的纹理。这样一来，我们就可以将这个纹理使用到 Unity 的 shader 或者其他 3D 运算中。

从官方的 API 定义上来看：

```
Native texture object on Direct3D-like devices is a pointer to the base type, 
from which a texture can be created (IDirect3DBaseTexture9 on D3D9, 
ID3D11ShaderResourceView on D3D11). On OpenGL/OpenGL ES it is GLuint. On Metal 
it is id<MTLTexture>.
```

id<MTLTexture> 是 Objective-C 中指向 MTLTexture object 的指针，而 GLuint 是 OpenGL 的对象句柄，所以说这个 API 本身仅仅是复制了对应渲染引擎的指针，在性能上也并没有多少开销。

#### Unity 渲染 shader

在利用 [Texture2D.CreateExternalTexture](https://docs.unity3d.com/ScriptReference/Texture2D.CreateExternalTexture.html) 获取到了原生纹理的指针之后，Unity 写了一个 YUV 转 RGB 的 shader，这个 shader 包括 3 个部分：

##### 顶点比例放大/缩小

```glsl
      TexCoordInOut vert (Vertex vertex)
      {
        TexCoordInOut o;
        o.position = UnityObjectToClipPos(vertex.position); 
        if (_isPortrait == 1)
        {
          o.texcoord = float2(vertex.texcoord.x, -(vertex.texcoord.y - 0.5f) * _texCoordScale + 0.5f);
        }
        else
        {
          o.texcoord = float2((vertex.texcoord.x - 0.5f) * _texCoordScale + 0.5f, -vertex.texcoord.y);
        }
        o.texcoord = mul(_TextureRotation, float4(o.texcoord,0,1)).xy;
              
        return o;
      }
```

在转换 texcoord 的时候，由于 Metal 渲染 API 获取到的纹理中心点是在 (0,0)，也就是说纹理是在如下图的坐标系中：

<img src="/img/in-post/unity-arkit-plugin-opengl/metal-coordinates-1.png" width="300">

所以缩放时，需要先将坐标系平移 0.5f 然后乘以缩放值，再移回 (0,0) 点。这个部分我没有找到相应的文档，如果有大神对 Metal 的坐标系体系比较了解的，烦请指教。

##### 定点旋转

在上面的代码中

```glsl
        o.texcoord = mul(_TextureRotation, float4(o.texcoord,0,1)).xy;
```

这句代码使用 `_TextureRotation` 进行了一次图片的旋转，这是因为 ARKit 的相机角度和真实视角并不相匹配。旋转后的图片在如下图的坐标系中：

<img src="/img/in-post/unity-arkit-plugin-opengl/metal-coordinates-2.png" width="300">

##### YUV 纹理转 RGB 纹理

这是最后一步，将 Y 纹理和 UV 纹理转换为 RGB 编码格式。这个步骤苹果官方给出了转换矩阵，Unity 自身就套用这个矩阵进行了一次转换。

```glsl
        float2 texcoord = i.texcoord;
        float y = tex2D(_textureY, texcoord).r;
        float4 ycbcr = float4(y, tex2D(_textureCbCr, texcoord).rg, 1.0);

        const float4x4 ycbcrToRGBTransform = float4x4(
            float4(1.0, +0.0000, +1.4020, -0.7010),
            float4(1.0, -0.3441, -0.7141, +0.5291),
            float4(1.0, +1.7720, +0.0000, -0.8860),
            float4(0.0, +0.0000, +0.0000, +1.0000)
          );

        return mul(ycbcrToRGBTransform, ycbcr);
```

### OpenGL 支持

在大概理解 Unity ARKit 插件的渲染原理之后，我们来看一下在 OpenGL Graphic API 上运行会有什么效果。

在 Unity ARKit Plugin 项目的 `Build Settings -> Player Settings` 中将 Graphic API 设置为 OpenGL ES 2，然后导出 xcode 项目并且运行之后，我们看到屏幕上可以显示出特征点云，并且可以进行空间定位，但是摄像头的图像无法显示。这是为什么呢？

<img src="/img/in-post/unity-arkit-plugin-opengl/fix-1.png" width="300">


#### 原因猜测

1. ARKit 的空间定位功能仍然可用。

    这表示 ARKit 的计算并不依赖于渲染方式，很可能只是利用了 GPU 的矩阵计算能力，但是不依赖于某些特定的 API。这个也和机器学习的利用 GPU 的方式类似，在运行基于 cuda 的代码时，与 OpenGL 绘制屏幕上其他部分的 GPU 使用并不冲突。

2. 屏幕渲染是绿色的。

    这个原因肯定和 OpenGL 与 Metal 的区别有关。理解这个现象出现的原因，也就能定位显示的问题，从而解决它。

#### 问题排查以及解决

首先，检查一遍代码，将所有与渲染 API 有关的代码都找出来。这里接触到的代码非常少，但是有一个地方很容易被忽略的，就是 [Texture2D.CreateExternalTexture](https://docs.unity3d.com/ScriptReference/Texture2D.CreateExternalTexture.html) 这个 API 的调用。

如文档中所说的，这个函数只是储存一个纹理的指针，而不是将纹理复制出来。这样一来，在后面的 shader 计算中，便将 `MTLTexture` 的指针传给了 OpenGL 的 API，难怪渲染会出错。我们就从这里开始解决。

##### 使用 OpenGL API 提取 YUV 纹理

在参考了 [@handyTOOL](http://www.jianshu.com/u/e6367cf15710) 大神的 [ARKit & OpenGL ES - OpenGL实现篇](http://www.jianshu.com/p/380df8ae273f) 之后，用他博客中的代码替换掉了官方提供的获取 Metal Texture 的代码，具体解释见注释：

```objective_c
        if (glYTexture == 0) {
            // 检查 glYTexture 是否已经在 OpenGL 中初始化，如果尚未初始化则获取 handle.
            glGenTextures(1, &glYTexture);  
        }
        if (glUVTexture == 0) {
            // 检查 glUVTexture 是否已经在 OpenGL 中初始化，如果尚未初始化则获取 handle.
            glGenTextures(1, &glUVTexture);
        }
        
        // 获取 Y panel 的宽高和内存地址
        GLsizei textureWidth = (GLsizei)CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        GLsizei textureHeight = (GLsizei)CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        void * baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        
        // glBindTexture 将当前 OpenGL 处理的对象设为 glYTexture
        glBindTexture(GL_TEXTURE_2D, glYTexture);
        // 用 GL_LUMINANCE 格式读出 baseAddress 指向的单通道 8 byte 的图片纹理
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, textureWidth, textureHeight, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, baseAddress);
        // glBindTexture 将当前 OpenGL 处理的对象设为 空
        glBindTexture(GL_TEXTURE_2D, 0);
        
        textureWidth = (GLsizei)CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        textureHeight = (GLsizei)CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        void *laAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        glBindTexture(GL_TEXTURE_2D, glUVTexture);
        // 用 GL_LUMINANCE_ALPHA 格式读出 laAddress 指向的双通道 8 byte 的图片纹理
        // 其中 U panel 的信息存在第一个通道中，对应 rgba 的 r 通道
        // V panel 的信息存在第四个通道中，对应 rgba 的 a 通道
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE_ALPHA, textureWidth, textureHeight, 0, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, laAddress);
        glBindTexture(GL_TEXTURE_2D, 0);
```

##### 将 OpenGL 纹理指针传回 Unity 

同时，修改一下将指针传回 Unity 的代码：

```diff
 extern "C" UnityARTextureHandles GetVideoTextureHandles()
 {
     UnityARTextureHandles handles;
-    handles.textureY = (__bridge_retained void*)s_CapturedImageTextureY;
-    handles.textureCbCr = (__bridge_retained void*)s_CapturedImageTextureCbCr;
-
+    if (UnitySelectedRenderingAPI() == apiOpenGLES2 ) {
+        handles.textureY = (void*) glYTexture;
+        handles.textureCbCr = (void*) glUVTexture;
+    }
+    else {
+        handles.textureY = (__bridge_retained void*)s_CapturedImageTextureY;
+        handles.textureCbCr = (__bridge_retained void*)s_CapturedImageTextureCbCr;
+    }
     return handles;
 }
```

需要注意的是，如果是使用 Metal API，是将 `id<MTLTexture>` 类型转换为 `void *` 类型，两者都是指针。当使用 OpenGL API 时，是将 `GLuint` 转换为 `void *` 类型。`GLuint` 在头文件定义中是 `unsigned int`，所以是将一个整数型存到指针类型中，不要将 `GLuint` 的指针传回 Unity 了。

##### OpenGL 相关的坐标变换

如果仅仅进行上述修改，我们发现屏幕上仍然无法正确显示出摄像头拍摄到的图像。我们将会看到如下画面。

<img src="/img/in-post/unity-arkit-plugin-opengl/fix-2.png" width="300">

此时这些图像会随着摄像头的移动而改变，说明摄像头的纹理已经提取出来了，只是渲染的时候出了问题。在尝试使用 Unity 的 `Unlit/Texture` shader 进行渲染之后，发现 Y panel 和 UV panel 的纹理是正确的，图像显示出来是左旋90度的，所以应该是 shader 的计算过程中出了问题。

<img src="/img/in-post/unity-arkit-plugin-opengl/opengl-coordinates-1.png" width="300">

在 debug shader 的过程中，我先将所有 shader 代码都简化为与 `Unlit/Texture` shader 一样，然后再一点点加回。此时发现，在加入旋转之后，图像就变成了如上图所示的条纹状。

为了修复这个问题，我们需要调整一下 shader：

先将纹理往 x 轴平移 1.0f：

<img src="/img/in-post/unity-arkit-plugin-opengl/opengl-coordinates-2.png" width="300">

再进行围绕(0,0) 旋转 90 度：

<img src="/img/in-post/unity-arkit-plugin-opengl/opengl-coordinates-3.png" width="300">

虽然这样操作可以正确地纠正图像，但是我并不太理解为什么不平移直接旋转 90 的话，会出现条纹状的图像。

### 解决方法

在这边博客写下的时候，对于 OpenGL ES 2 的支持已经提交 Pull Request 给 Unity 的官方代码库了，暂未合并进 master 分支：

[Pull Request: Support OpenGL ES 2 as the rendering API](https://bitbucket.org/Unity-Technologies/unity-arkit-plugin/pull-requests/6/support-opengl-es-2-as-the-rendering-api/diff)

### 经验总结

在这个事件中，学到了：

1. **理解问题的原因是解决问题的第一步**

    在刚开始 debug shader 渲染的时候，由于之前没有前端开发的经验，我是以一种试试看的心态，调整各个参数试图找到合适的组合以求解决问题。但是这个试错的过程不仅繁杂，而且往往没有目的性，会浪费很多时间。最后还是花了时间学习了一些基本的 shader 知识后，理解了 shader 代码再进行修改的。

---

如果你看到这里，一定是真爱！欢迎看看我的其他 [blog](http://chendi.me/)。O(∩_∩)O
