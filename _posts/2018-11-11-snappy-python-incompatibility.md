---
layout:     post
title:      "Snappy-python is not fully compatible with hadoop-snappy"
subtitle:   "Snappy 的 python SDK 与 hadoop snappy 不兼容的问题"
date:       2018-11-11 21:15:00
author:     "Di Chen"
header-img: "img/in-post/snappy-python-incompatibility/snappy-bg.png"
tags:
    - Tech
---

## 起因

在我当前项目中，有一部分技术架构涉及到数据在 python 脚本中用 json + [snappy](https://github.com/google/snappy) 的格式压缩之后储存起来，json 是作为数据序列化的格式，而 snappy 则是作为数据压缩的格式。在下游处理中，spark 任务会读取这部分数据进行处理。这套方案理论上是没有问题的，在我们的调研中，也确认了 python 中上传的数据，在 spark 中可以被正确解读。但是在实际广泛使用时，我们发现有某些数据在 python 端能正常地被压缩以及解压，但是在 spark 端就报了下面的错误：

```
java.lang.InternalError: Could not decompress data. Input is invalid.
at org.apache.hadoop.io.compress.snappy.SnappyDecompressor.decompressBytesDirect(Native Method) 
at org.apache.hadoop.io.compress.snappy.SnappyDecompressor.decompress(SnappyDecompressor.java:239)
at org.apache.hadoop.io.compress.BlockDecompressorStream.decompress(BlockDecompressorStream.java:88)
at org.apache.hadoop.io.compress.DecompressorStream.read(DecompressorStream.java:85)
...
```

这里记录的是解决这个问题的过程和结果。

## 分析错误原因

1. **首先缩小一下问题出现的范围**。

    这个错误大概在1万个文件中才会出现一次，并且我们将出错的文件重新用 python 库解压之后，spark 仍然无法解析。所以基本可以认定这个文件指出了 spark 和 python 中 snappy SDK 的一些不兼容之处。

2. **缩小测试用例，找出最小可以复现问题的测试用例**。

    原始的错误文件大概有2.6MB，压缩之后是2.5MB，压缩比例很差。好在文件并不大，决定用二分法找出有问题的数据内容。在将数据分为两份之后，发现只有其中一份用 python sdk 压缩之后 spark 无法解析，另一份则没有问题。在不断缩小范围之后，定位到了一段 base64 encode 的数据上。这部分 base64 encode 的数据大概有1.5MB。

3. **构建最小可以复现问题的测试用例**。

    在比较正常压缩文件和该错误压缩文件之后，发现 base64 encode 的数据几乎没有被压缩，原文和压缩后的文件几乎是相同的。此时我们大胆猜测，当压缩后的文件与原文相同时，snappy 解压时会因为找不到所需的元数据而报错。在编写了一个随机字符生成器后，我们基本验证了我们的猜测：

    ```
import random
import string
N=1000000
print(''.join(random.choices(string.ascii_uppercase + string.digits, k=N)))
    ```

    并且在 N 在大于 100 万的情况下必然复现。

## 寻找解决问题的方法

### 对比测试结果
在找到复现的 test case 之后，下一步我们要找问题的根源。对于一个序列化和反序列化的算法，不同语言的实现应该遵从同一套标准，那么同一段数据压缩后的二进制文件应该也是相同的。

将 snappy-python 压缩后的文件命名为 python_result.snappy
```
python3 -m snappy -t hadoop_snappy -c test.txt > test_python.txt.snappy
```

此时我们还需要 hadoop-snappy 编译出来的二进制文件

### 编译 hadoop-snappy 测试用例
hadoop-snappy 的源码在 [Hadoop snappy google code](https://code.google.com/archive/p/hadoop-snappy/)。可以从[这里](https://storage.googleapis.com/google-code-archive-source/v2/code.google.com/hadoop-snappy/source-archive.zip)下载源码。

源码编译时需要先安装 snappy 库，同时配置 snappy 库的到 java 的 VM Options 中。例如我在 Mac OS 上用 brew 安装的 snappy。
```
$ brew install snappy
$ ls /usr/local/Cellar/snappy/1.1.7_1
AUTHORS              INSTALL_RECEIPT.json README.md            lib
COPYING              NEWS                 include
```
snappy 库的路径是 /usr/local/Cellar/snappy/1.1.7_1，那么就配置 -Dsnappy.prefix=/usr/local/Cellar/snappy/1.1.7_1

同时要注意，老版本的 hadoop-snappy 有一个提示错误，当 snappy 格式错误时，提示的是找不到 snappy 库，可以用以下方式修改 `src/main/native/src/org/apache/hadoop/io/compress/snappy/SnappyDecompressor.c`，然后重新编译来解决。

```
   if (ret == SNAPPY_BUFFER_TOO_SMALL){
-    THROW(env, "Ljava/lang/InternalError", "Could not decompress data. Buffer length is too small.");
+    THROW(env, "java/lang/InternalError", "Could not decompress data. Buffer length is too small.");
   } else if (ret == SNAPPY_INVALID_INPUT){
-    THROW(env, "Ljava/lang/InternalError", "Could not decompress data. Input is invalid.");
+    THROW(env, "java/lang/InternalError", "Could not decompress data. Input is invalid.");
   } else if (ret != SNAPPY_OK){
-    THROW(env, "Ljava/lang/InternalError", "Could not decompress data.");
+    THROW(env, "java/lang/InternalError", "Could not decompress data.");
   }
```

编译之后可以使用测试用例来触发 snappy 的压缩，测试用例在 `src/test/java/org/apache/hadoop/io/compress/snappy/TestSnappyCodec.java`。压缩之后我们得到了 test_java.txt.snappy

我们比较一下 test_java.txt.snappy 和 test_python.txt.snappy，发现 test_python.txt.snappy 整个文件中，如果用 utf-8 编码格式打开，只有最开头有一段乱码的二进制头信息。但是 test_java.txt.snappy 则每隔 256K 就会有一段二进制头信息。

在这时，我们可以初步断定是两个语言的头信息写入不一致导致的文件格式不兼容。

### 查看源码
snappy 的压缩和代码在 java 中其实并不复杂，主要都集中在 `src/main/java/org/apache/hadoop/io/compress/snappy/`，本质上是在 java 中将 byte 流读入后，将数据分块，再对每一块进行压缩。而我们看到的文件里的的二进制头信息其实就是每一块数据的元数据，例如每一块数据的长度等。那么是什么决定了数据块的默认大小呢？有两个变量可能会造成影响。

一个是 DEFAULT_DIRECT_BUFFER_SIZE:
```
$ grep DEFAULT_DIRECT_BUFFER_SIZE src/main/java/org/apache/hadoop/io/compress/snappy/SnappyCompressor.java
$   private static final int DEFAULT_DIRECT_BUFFER_SIZE = 64 * 1024;
```
这里是代码定义的默认大小，64K。但是在测试用例中我们发现，调整这个数值并不会改变最后生成的数据块大小。

另一个是 IO_COMPRESSION_CODEC_SNAPPY_BUFFERSIZE_DEFAULT：
```
$ grep -b2 IO_COMPRESSION_CODEC_SNAPPY_BUFFERSIZE_DEFAULT src/main/java/org/apache/hadoop/io/compress/SnappyCodec.java
1527-
1528-  /** Default value for IO_COMPRESSION_CODEC_SNAPPY_BUFFERSIZE_KEY */
1598:  public static final int IO_COMPRESSION_CODEC_SNAPPY_BUFFERSIZE_DEFAULT =
1673-      256 * 1024;
```
这个配置文件控制了在作为 Hadoop Codec 组件实例化时，使用的数据块大小。如果我们将这个值调为 256，我们会发现测试用例中数据块的分块确实变化了。

这时候，我们可以大致明白，之所以 python-snappy 压缩的文件在 hadoop-snappy 中无法解析，其实本质上是因为 python-snappy 在一整个 256K 数据块中的任何一块地方生成元数据头，导致 hadoop-snappy 一次性读取进来的 256K 全是数据，没有数据块头，也就无法解析出对应的数据块长度，最终报了 " Input is invalid." 错误。

那么为什么其他数据没问题， base64 的数据就会出问题呢？

首先，并不是一定 256K 的位置才会生成一个数据块头信息，而是每一个可以被截断并压缩的数据块就会生成一个头信息。但是对于 base64 的文字，基本是原文读入，原文写出的，所以连续的 256K base64 编码数据中，如果没有强行截断的话，就不会生成数据头。这个应该是 python-snappy sdk 的一个bug，不过由于时间原因，没办法细看 python-snappy sdk 并修复这个问题。

### 最终解决方法
首先我们尝试调大 hadoop-snappy 的解压区块大小，当 hadoop-snappy 的 IO_COMPRESSION_CODEC_SNAPPY_BUFFERSIZE_DEFAULT 设置为 512K 时，我们发现 python-snappy 压缩的 base64 encode 文件可以被正常解压。但是在 hadoop 集群上，这样有可能导致这样保存下来的 snappy.json 文件无法被其他未修改配置的 hadoop 组件读取。

还有一个思路就是调小 python-snappy 的区块大小。虽然文档中没有提到修改的方式，但是从 API 的签名中我们发现，在 [hadoop-snappy.py](https://github.com/andrix/python-snappy/blob/master/snappy/hadoop_snappy.py) 文件中也定义了 `SNAPPY_BUFFER_SIZE_DEFAULT` 变量，控制默认的区块大小。而在 stream_compress 函数的签名中也有 blocksize 变量，默认值就是 SNAPPY_BUFFER_SIZE_DEFAULT。所以只要在调用 stream_compress 的时候将 blocksize 调为 128K 即可。

最后联调后发现，这个方法生成的 python-snappy 文件是可以被 hadoop-snappy 成功解析的。最后我们的解决方法就是在 stream_compress 设置 blocksize 为 128K。

# 经验总结

首先这个问题其实本质上还是一个算法，多个语言实现导致的问题。虽然底层的压缩算法使用的是同一套库，但是上层数据块的切分实现可能有细微差别，导致这个问题的发生。这个问题的解决其实关键是有一个可以复现的测试用例，有了这个测试用例之后就能帮我们不断缩小问题的范围，最后找到一个相对实现起来比较容易的解决方案。

## 题外话

在看 Google snappy 的代码时，发现一个 [commit](https://github.com/google/snappy/commit/824e6718b5b5a50d32a89124853da0a11828b25c)。Google 的工程师在做 regression 性能测试的时候发现，LLVM 的一个内存对齐的相关改动，导致 snappy 的性能下降了 3%，这个改动影响到了多个 intel 架构。最后虽然没能理解出现的原因，但是强行在 x86 架构上增加一个补位元素，抵消了 LLVM 上游的副作用，使得 snappy 的性能恢复到 LLVM 修改之前。

这看起来是个小优化，但是也看到了 Google 背后完整的基础架构，能支持工程师定期进行性能测试，并且将性能测试在不同架构上进行复现。确实厉害。

---

如果你看到这里，一定是真爱！欢迎看看我的其他 [blog](http://chendi.me/)。O(∩_∩)O
