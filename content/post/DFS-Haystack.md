---
title: "DFS-Haystack"
date: 2021-10-06T22:44:01+08:00
lastmod: 2021-10-06T22:44:01+08:00
mathjax: true
keywords: ["DFS","Distributed System","Paper Reading"]
tags: ["DFS","Paper Reading", "Distributed System"]
categories: ["Distributed System","DFS","Paper Reading"]
draft: false
author: "NoneBack"
comment: true
toc: true
autoCollapseToc: true
reward: false

flowchartDiagrams:
  enable: true
  options: ""

sequenceDiagrams: 
  enable: true
  options: ""
---

组内的主要项目便是一种提供POXIS文件系统语义的DFS，其中解决losf(lots of small files)的思路就是对小文件单独处理。里面的思想来源应该就是Haystack。
于是大致阅读了一下这篇论文，写下学习笔记。
笔记依旧不深究具体细节，仅仅记录对问题的思考以及设计的思路。
## 介绍
HayStack是Facebook为了小文件设计的一种存储系统。之前的DFS，对于文件的寻址路径一般是都会使用Cache来缓存元数据，以便减少磁盘交互提高寻址效率。一个文件就需要一个维护一类元数据，文件数决定了元数据量。在高并发场景下，我们要减少磁盘IO，一般会选择将寻址需要的元数据缓存在内存中。

在大量小文件场景下，会有大量的元数据。考虑到在内存元数据维护带来的开销，这种方案变得不可用。于是便有了为小文件特别优化的HayStack。它核心思想是将多个小文件聚合成一个大文件，以减少元数据。

## 背景

论文中的小文件其实是特指图片数据。

Facebook是以社交起家的公司。在社交场景中，图片的上传和读取是常见需求。当业务发展到一定的程度，就需要有专门的服务支撑图片的大量高并发读写请求。

在社交场景下，这类数据的特点是`written once, read often, never modified, and rarely deleted.`基于此，Facebook开发了HayStack来支持图片分享服务。

## 设计

### 传统的设计

论文中给出了两种历史设计：基于CDN和基于NAS的方案

#### 基于CDN的方案

这个方案的核心其实就是利用CDN对热点图片数据进行缓存，减少网络传输。

常用的设计，对于热点图片的优化很显著。但问题也很明显，一是CDN价格昂贵容量有限；二是图片分享场景，也会有很多`less popular`的图片数据，这就会导致长尾效应，拖慢速度。

![image-20210926200920113](https://tva1.sinaimg.cn/large/008i3skNly1guuaefh22gj610g0s4gnh02.jpg)

> CDN其实一般服务于静态数据的，并且一般都是在活动之前进行预热，并不适合作为一种图片缓存服务使用。很多的`less popular`的数据其实并未进入CDN，故而导致长尾效应。

#### 基于NAS的方案

这是facebook最初的设计方案，本质和基于CDN的方案区别不大，属于它的一种实现。

引入NAS横向拓展存储，引入文件系统语义，同时也会有磁盘IO存在。和本地文件类似，对于未读取过的数据，至少需要三次磁盘IO：

- Read directory metadata into memory
- Load the inode into memory
- Read the content of the file

PhotoStore作为一层缓存使用，缓存一些元数据如file handle等，以加速寻址过程。



![image-20210926201012724](https://tva1.sinaimg.cn/large/008i3skNly1guuafar1rpj60u80scmyx02.jpg)

基于NAS的设计并没有解决**元数据过多导致不适合全量缓存**这个关键问题，一但文件数量到达临界值，不可避免的需要进行磁盘IO。

> 更本质的问题其实是**文件与寻址元数据一一对应的关系**，使得元数据量随着文件数的变化而变化。

所以，优化的关键是，改变**文件与寻址元数据一一对应的关系**，降低寻址过程中磁盘IO出现的频率。

### 基于HayStack的方案

此方案最核心的思路是**将多个小文件聚合成大文件**，并只维护一份元数据。本质上是改变了元数据与文件数的映射关系，使将所有元数据保存在内存的方案成为可能。

> 只维护聚合后的大文件的元数据，小文件在大文件中的位置需要另外维护映射

![image-20210927142131959](https://tva1.sinaimg.cn/large/008i3skNgy1guv5ytgsmtj60k20jqjsk02.jpg)

## 实现

Haystack主要有三个组件，Haystack Directory、Haystack Cache、Haystack Store

### 文件映射与数据落盘

文件数据最终保存在logic volume上，一个logic volume对应多机器上的多个physical volume。

用户首先访问Directory来获取访问路径，之后再通过Directory生成的URL访问其他组件，获取需要的数据。

### 组件

#### Haystack Directory

属于Haystack的接入层，主要负责**文件寻址**以及**访问控制**。

读写请求首先访问Directory。对于读请求，Directory会生成一个访问URL，URL包含了访问的路径：`http://{cdn}/{cache}/{machine id}/{logicalvolume,Photo}`。对于写请求，它会指定一个可以写入的volume提供用户写入。

详细点来说，最主要有四个功能：

1. 负载均衡，平衡读写请求，

2. 决定请求的访问路径，比如是否通过CDN访问，生产访问URL

3. 元数据与映射管理， 如`logic attr and logic volume => list of phycial volume mapping`

4. logic volume读写管理，logic volume可能是Readonly或者WriteEnabled

   >  这部分设计和数据特点有关，write once and read more。可以提高并发度。

基于此，Directory就必须记录一些必须的元数据，file to volume，logical to phycial mapping、logical volume attr（size，owner、etc）。

依赖分布式KV落盘元数据和缓存服务加速访问，以此保证容错可用以及低延迟。

> **Proxy，Metadata Mapping，Access Control**

#### Haystack Cache

Cache作为缓存用于优化寻址以及图像获取。核心的设计是**Cache Rule**，判断什么样的数据需要被缓存以及**Cache Miss**的处理。

Haystack中，被缓存的图片数据需要满足这两个特点：

1. The request comes directly from a user and not the CDN
2. The photo is fetched from a write-enabled Store machine

当出现Cache Miss时，它会从Store上获取图片数据并同步推送至浏览器以及CDN中。

> 这样的策略是基于图片请求的场景与特点决定的。
>
> 首先，在CDN中Miss的请求，很大概率上也会在Cache中miss，所以重CDN重定向的请求的数据不会被Cache。其次，图片往往在刚刚写入后不久时间内会被频繁的访问，所以这样的数据理应被Cache。
>
> CDN可以被视为一个External Cache。

#### Haystack Store

Store属于Haystack的存储层，负责数据存储相关操作。

首先是它的寻址抽象：`filename + offset =>  logical volume id + offset => data`。

多个Physical Volume组成Logical Volume，并作为实际落盘单位进行维护。在Store中，小文件被抽象成**Needle**，交由Physical Volume进行管理和维护。

![image-20211006164409801](https://tva1.sinaimg.cn/large/008i3skNly1gv5oo0mltfj60zs0u0q5j02.jpg)

> Needle实际上是对小文件的一种**封装**，以及对Volume的**分块**管理。
>
> ![image-20211006164428466](https://tva1.sinaimg.cn/large/008i3skNly1gv5ooyhloxj61150u043702.jpg)

Store的数据访问一般是以Needle维度进行的。为了加速文件寻址，一般会在内存中维护一个用于寻址元信息的Map：`key/alternate key => needle's flag/offset/other attribute`

这些Map最后会被持久化到磁盘中的**Index File**中，做为In-Memory Mapping的一种Checkpoint存在，用于Crash后寻址元数据的快速恢复。

![image-20211006172431986](https://tva1.sinaimg.cn/large/008i3skNly1gv5put6m7qj60u40jc0u102.jpg)

![image-20211006172515258](https://tva1.sinaimg.cn/large/008i3skNly1gv5puqgvgcj60te0dk0ua02.jpg)

> 每个Volume会维护一个自己的In-Memory Mapping和Index File

在我们更新In-Memory Mapping的时候（比如修改文件、新增文件），会异步更新Index File。但在文件删除时，我们只异步标记文件删除，而不会修改Index File。

> Index只是作为加速查找的手段，无Index的Needles依旧是可以被寻址的，故而上述策略是有效的。但是由于异步更新和不删除对应文件的Index的设计，引入了Orphan Index和Deleted Index的问题。
>
> Orphan Index是指无索引记录的Needle，一般Store会检查出这些Needle并为其添加Index。
>
> Deleted Index一般就直接在查询是检测出文件是Deleted的，并且是Mark Deleted的状态，此时会告知上层为查询到文件，同时及时更新In-Memory Mapping。这样的设计加速了文件NotFound的情况下的查询时间。

### 工作负载

#### 读

`(Logical Volume ID, key, alternate key, cookies) => photo`

当接收到从Cache收到读请求时，Store会去查询In-Memory Mapping查询对应的Needle。如果查询到，则根据volume + offset获取文件数据，并校验文件的cookie和完整性；否则返回错误。

>  Cookie是在Directory生成URL的时候随机生成的字符串，在寻址的时候带上并校验可以有效防止恶意攻击。

#### 写

`(Logical Volume ID, key, alternate key, cookies， data) => result`

Haystack不支持文件的覆盖写入，只支持追加写。当收到写请求时，Store会异步Append文件数据到Needle中并更新In-Memory Mapping。如果这是一个老文件，那么Directory会更新它保存的元数据，以便后续的访问不会访问老版本的文件。

> 除了Directory的元信息之外，怎么去判断数据版本的新旧？
>
> 答案是根据volume以及offset。老的volume会被冻结为ReadOnly，新的volume的写入是追加的，所以offset大的必然更新。

#### 删除

采取**Mark Delete + Compact GC**的方式处理删除请求。

### 容错设计

对于Store使用**监控 + 热备**的方式，Directory和Cache可以使用Raft等一致性算法保证数据副本一致与容错。

## 优化

优化手段主要有三点：Compaction、Batch Load、In Memory。

## 总结

- 优化的抽象：异步、批处理、缓存
- 要发现主要问题，比如大量小文件最主要的问题是元数据带来的管理负担。

## 参考

[Finding a needle in Haystack: Facebook’s photo storage](https://www.usenix.org/legacy/event/osdi10/tech/full_papers/Beaver.pdf)
