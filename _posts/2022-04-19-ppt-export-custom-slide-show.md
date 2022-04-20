---
layout:     post
title:      "PPT - Export custom slide shows as another ppt"
subtitle:   "将 PPT 根据受众不同导出不同版本"
date:       2022-04-19 10:15:00
author:     "Di Chen"
catalog:    true
header-img: "img/in-post/cover/ppt.jpg"
tags:
    - tech
---

## 问题

当我们需要给几组不同的受众做演讲时，为了达到更好的效果，我们往往需要对演讲内容进行一些微调，例如对于同一个产品来说：
 - 对客户进行汇报时，要着重强调功能、用户案例，但是需要隐藏内部开发流程、成本等机密信息。
 - 对管理层进行汇报时，需要隐藏实现细节，从而节约管理层的时间。
 - 对技术团队进行演讲时，需要隐藏营销方案等技术团队不关心的信心。

那么难道对同样的产品，我们还要维护多个 ppt 吗？如果有一个产品图发生了变化，难道我们在每一个 ppt 上都进行更新？有没有办法节约一些时间呢？

我最近也遇到了类似的问题，探索后发现可以通过2步来解决。

### Custom Slide Show

Powerpoint 中有一个 [Custom Slide Show 功能: ](https://support.microsoft.com/en-us/office/create-and-present-a-custom-show-09d4d340-3c47-4125-b177-0de3be462c5d)

[![custom_slide_show2.png](/img/in-post/ppt/custom_slide_show2.png)](/img/in-post/ppt/custom_slide_show2.png)

这个功能本质上是创建了一个独立的播放顺序，当使用 Custom Slide Show 进行播放时，就会按照这个设置的播放顺序进行播放。例如原本有5张ppt，当你创建一个 custom slide show 1: [3, 4, 2]，这时候播放它就只会播放 第3、4、2张ppt。

[![custom_slide_show1.png](/img/in-post/ppt/custom_slide_show1.png)](/img/in-post/ppt/custom_slide_show1.png)

这个功能解决了第一个问题：**如何在一个 ppt 上播放给多个不同的受众看。**



### Macro

但是许多团队会将 ppt 分发出去，例如作为客户路演的一部分，或者作为演讲的存档保存。这时候为了保持演讲和ppt的一致性，最好可以把不相关的 ppt 删掉，这时候可以用 powerpoint 自带的宏编程实现。首先将你的主 ppt 复制一份出来，在备份上进行操作。

1. 按照这个说明打开 Powerpoint 的宏功能：[https://support.microsoft.com/en-us/topic/show-the-developer-tab-e1192344-5e56-4d45-931b-e5fd9bea2d45](https://support.microsoft.com/en-us/topic/show-the-developer-tab-e1192344-5e56-4d45-931b-e5fd9bea2d45)

2. 然后按照这个说明新建一个宏：[https://support.microsoft.com/en-us/office/run-a-macro-in-powerpoint-fa2ecee4-9985-490a-9d99-74b3c726bc5a?ui=en-us&rs=en-us&ad=us](https://support.microsoft.com/en-us/office/run-a-macro-in-powerpoint-fa2ecee4-9985-490a-9d99-74b3c726bc5a?ui=en-us&rs=en-us&ad=us)

3. 将下方代码中的 `DeleteMe` 换成你希望保留的 Custom Slide Show 名字，然后运行 Macro，就可以将不需要的 ppt 页面删除了

```VisualBasic
Sub IsolateCustomShow()
' Deletes all slides but those in the named custom show

    Dim sShowName As String
    Dim x As Long
    Dim oSl As Slide

    ' edit this as needed or add an input box or other
    ' UI to get name of show from user
    sShowName = "DeleteMe"

    ' tag each slide in the show
    With ActivePresentation.SlideShowSettings.NamedSlideShows(sShowName)
        For x = 1 To .Count
            'Debug.Print TypeName(.SlideIDs(x))
            Set oSl = ActivePresentation.Slides.FindBySlideID(.SlideIDs(x))
            'Call ActivePresentation.Slides(.SlideIDs(x)).Tags.Add("KEEP", "YES")
            Call oSl.Tags.Add("KEEP", "YES")
        Next
    End With

    ' Delete any slides we haven't tagged as "keepers"
    For x = ActivePresentation.Slides.Count To 1 Step -1
        Set oSl = ActivePresentation.Slides(x)
        If oSl.Tags("KEEP") <> "YES" Then
            oSl.Delete
        Else
            ' blank the tag in case we run this again on a subset of this presentation
            oSl.Tags.Delete ("KEEP")
        End If
    Next

End Sub
```

参考自 [https://www.rdpslides.com/pptfaq/FAQ00893_Delete_all_slides_but_those_in_a_custom_show.htm](https://www.rdpslides.com/pptfaq/FAQ00893_Delete_all_slides_but_those_in_a_custom_show.htm)

---




















