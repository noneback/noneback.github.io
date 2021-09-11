---
title: "MIT6.824-GFS"
date: 2021-09-09T00:44:24+08:00
lastmod: 2021-09-09T00:44:24+08:00
mathjax: true
keywords: ["Distributed System","GFS","DFS"]
tags: ["GFS","MIT6.824","Paper Reading"]
categories: ["MIT6.824","Distributed System","Paper Reading"]
draft: false
author: "NoneBack"
comment: true
toc: true
autoCollapseToc: true
reward: false

flowchartDiagrams:
  enable: true
  options: "mermaid"

sequenceDiagrams: 
  enable: true
  options: "mermaid"
---

之前对GFS的理解并不能支持我写出满意的内容，于是一直搁置。最近刚转岗某司存储部门实习，回想起此文，于是在无所事事之时写下这个笔记。

这是鸽了许久的Distributed System学习笔记的第二章。笔记并没有记录详细的具体操作，仅仅记录了对问题的思考与设计思路。


## 介绍

GFS是Google使用的分布式文件系统。它使用大量机器为数据密集型应用构建了一个可靠的分布式文件服务。

最早出现在在2003年发表的一篇论文。

## 背景

1. 首先,组件失效被认为是**常态事件**，而不是意外事件。

> 使用大量的廉价机器搭建可靠的服务。每台机器一定概率失效，整体失效概率满足二项分布。
>
> 基于此，我们需要为系统组件设计容错保障机制，使得组件能够被监测，能够发现故障，并及时自动fail over，保证系统的可用性（HA)。

2. 文件非常**巨大**。数 GB 的文件非常普遍。

> 相对于传统标准而言。对于一个分布式存储系统，我们应该尽量使用大文件为粒度对文件进行维护。
>
> 过多的小文件，意味需要更多的inode等数据结构记录元数据，有效的磁盘存储空间会减少。
>
> 其次，分布式文件寻址一般需要网络通信，寻址结果需要缓存，更多的文件意味着更多的缓存项，这也会造成空间浪费。

3. 绝大部分文件的修改是采用在文件尾部追加数据,而不是覆盖原有数据的方式，对文件的随机写入操作在实际中几乎不存在。一旦写完之后,对文件的操作就只有读,而且通常是按**顺序读**

> 这是GFS对使用场景的考量和trade_off。
>
> Google内部大部分操作都是 append，因此 GFS 系统优化的中心也放在 record append 操作上，对于**随机写则不保证数据的一致性**。
>
> 同时顺序IO写也会比随机IO的读写性能好很多。

4. 第四，应用程序和文件系统API的协同设计提高了整个系统的灵活性

> 协同设计，提供类似POXIS文件系统API接口。提供客户端Lib帮助业务方屏蔽底层细节。

## 设计预期

### 存储能力

预期会有几百万文件,文件的大小通常在100MB或者以上。数个GB大小的文件也是普遍存在,并且要能够被有效的管理。

系统也必须支持小文件,但是不需要针对小文件做专门的优化。

### 工作负载

#### 读工作负载

主要由**大规模流式读取**和**小规模随机读取**组成。

- 大规模流式读取：大规模的磁盘顺序IO读取数据
- 小规模随机读取：小规模磁盘随机IO（任意偏移量）读取数据

> 对于小规模的随机读有一定的优化，比如对读请求排序，再批量处理，而非来回随机读取。

#### 写工作负载

主要是大规模的顺序写操作。将数据append到文件的末尾。

系统必须高效的、行为定义明确的实现多客户**端并行追加数据到同一个文件**里的语意。这要求系统提供并发写支持。操作的原子性以及同步开销是主要性能衡量指标。

### 带宽与延迟

高**持续**带宽（High sustained bandwidth）比低延迟更重要

> 这是由GFS的使用背景决定的。大多数GFS的业务方更关心高效率的处理数据，而非延迟。

### 容错设计

系统必须持续监控自身的状态,它必须将组件失效作为一种常态,能够迅速地侦测、冗余并恢复失效的组件。

> 参考背景一

### 操作与接口

对外提供了传统的文件系统接口，但是出于效率和使用性的角度，并没有实现标准的文件系统 POSIX API。

目录树、文件增删改查、快照、Atomic Record Append。

> 快照指创建文件和目录树的副本
>
> Atomic Record Append指保证原子性的记录追加操作

## 架构设计

> 核心问题是：接入，寻址，管理，容错，一致。这些问题决定我们怎样去设计一个DFS的整体架构

GFS采用Master-Slave架构。

一个GFS集群包含一个单独的Master Node，多台Chunk Server，以及若干Client。

> 此处Master和Chunk Server实际上都是逻辑上的概念，实际上对应的只是用户态的一个进程，而非指具体物理机器。
>
> 单Master设计简化了GFS的设计，但有一定的单点故障的风险，属于设计上的trade_off

![ image-20210906153847451](https://tva1.sinaimg.cn/large/008i3skNly1gu6y6qm5t0j61i40nojuk02.jpg)

GFS通过lib的形式提供给业务方使用、接入GFS。

文件数据最终以chunk为单位保存在chunk server的磁盘中，并且chunk以replica的形式提供可靠服务。

master管理着GFS上所有的元数据（目录树，mapping，chunk metadata，etc）以及相关系统行为（监控，GC，snapshot，etc）。

用户通过Client，以filename + offset访问Master获取chunk元信息，再根据原信息访问对应chunk server获取具体的数据，执行操作。

<!-- mermaid
sequenceDiagram
Client->>Lib: filename + offset
Lib->>Master: chunk index + offset
Master->>Client:chunk handle
Client ->> ChunkServer:chunk location + chunk id + offset
}}
-->

![](https://tva1.sinaimg.cn/large/008i3skNly1gu9234vb9nj61ej0u0gq702.jpg)

## 组件设计

### Client

Client在GFS中实际上只是使用了GFS SDK/LIB的一个应用进程。GFS提供SDK/LIB让业务方接入GFS，并尽可能的屏蔽底层细节，让业务方对GFS无感知。

因此，Client作为接入层需要提供以下功能：

- **缓存**：缓存从Master处获取的元信息，减少网络通信的次数。

> 缓存也可能会导致元信息不一致的问题，需要设计合理的机制。论文中并未详细说明。

- **封装**：屏蔽底层操作，如文件操作失败重试，命令spilt，数据checksum以及校验等
- **操作优化**：batch，load balance等
- **映射**：将参数filename + offset 映射为chunk index + offset

### Master

Master管理着GFS所有的元数据，在GFS中属于计算层，负责文件以及文件系统的调度与管理。

其中元信息其实是保存在Master的内存中的，并未持久化，通过chunk server的上报来维护更新。

> 此处也是Trade_off, 简化Master和ChunkServer交互设计，但可能有数据丢失的风险，但为Master扩大内存以便为GFS提供其拓展性，代价比较小，设计者认为这也是可以接受的。
>
> 同时，设计者认为chunk的位置实际上是由chunk server决定，故而不对元信息进行持久化。

基于此，Master需要提供以下功能：

- **监控机制**：Master节点管理这Chunk Server，并且元信息只保存在内存中，并且ChunkServer和其保存的文件均可能失效，因此需要监控Chunk Server的状态，并收集其保存的文件信息，并持续监控。

> 一般利用心跳机制，可以双向也可以只从ChunkServer到Master。

- **目录树管理**：文件以分层目录的形式管理，因此需要管理名称空间，也需要考虑到并发安全等问题

> 一般可以将目录树前缀压缩，减少磁盘空间使用。
>
> 加锁，设计合理的加锁策略，提高并发度。比如，写文件时，对文件目录加读锁，只对文件加写锁

- **映射管理**：Master接收Client传入的参数，返回其需要的元信息。需要维护两种映射关系：
  - Table1：filename => list of chunk ID (nv)
  - Table2：chunk ID => chunk handler

> chunk handler是一个数据结构，包含
>
>
> ```cpp
> struct ChunkHandler {
>   list of ChunkLocation(v);// 标识replica所在的机器
>   version(nv);         // 数据的逻辑时钟，标记数据版本
>   primary(v);       // 用于标记primary chunk，用于分配操作顺序
>   lease expire(v);     // 租约过期时间，防止ChunkServer长期持有primary
> }
> 

此处的映射实际上就是Master需要维护的数据结构（元信息），其中有一部分是需要持久化保证重启不丢失，以nv（non-volatile)标记。

> Table1适合使用HashMap作为索引结构去查询，Table2则更适合使用B+Tree等数据结构做索引，因为其应该会设计范围查询。

- **容错**：Master可能会失效，需要容错机制。

> Master使用Raft多副本容错，影子热备，定时CheckPoint备份元信息，以便快速回复内存数据、operation log记录对元信息的修改做持久化记录，WAL保证操作不丢失。
- **系统调度**：集群上chunk replica数量会不满足容错要求，这个时候就要新建副本。

> 如Chunk Server失效，配置变更

数据被删除或者发现孤儿Chunk（不包含数据的Chunk）时，Master需要负责GC。

> 一般删除的流程为：标记删除+ 延迟清理，降低前台处理时延，但会有一段时间窗口，占用磁盘的有效空间，也是trade_off

  快照创建时，也需要Master的参与。

> 会先释放chunk的lease，再以COW的方式生成快照

Chunk数据的分布可能不满足，Master需要调度，使得数据分布满足可靠容错的要求。

分配Lease，选择Primary Chunk，管理Version等

### Chunk Server

ChunkServer属于存储层，负责具体的数据以Linux文件的格式储存。

Client从Master获取元信息之后，再找到对应的ChunkServer，通过Chunk Index + Offset对文件进行寻址，再对文件进行操作。同时它需要及时上报ChunkServer的运行信息，以及它维护的Chunk的信息，以便Master维护系统的元数据。

## 系统内部设计与交互

讲一件上面没有涉及的关键设计思路，并不涉及具体细节

### Chunk 

chunk属于GFS管理数据逻辑最小单元，设计Chunk的关键是Chunk Size。

> Chunk Size过小，在相同有效数据下，会产生大量元信息，加重Master的管理（元数据，cache，调度等）负担；其次，加重了Client和Master之间的网络通信的次数；没有很好的利用局部性原理。
>
> ChunkSize过大，导致对数据的管理粒度过大，空间碎片化，降低磁盘优先使用；其次，被频繁访问的数据可能集中在同一个Chunk上，造成热点问题，并发读写时同步开销大。

基于上述原因，GFS中的ChunkSize最终被定为64MB，用一个64位全局唯一ID标识。

> 目前的DFS对小文件的优化实际上也就是将小文件聚合管理，减少其Master处元信息，转而将其元信息以payload的形式写入更小数据单元的header中，以便后续读写。
>
> 还有一个问题是，为什么大文件要分块管理？分块主要是为了提高大文件处理并发度。

### Lease

Lease机制主要是为了保证多副本间数据变更的一致性。

当有并发顺序写请求时，Master会分配Chunk Lease给Chunk涉及的一个ChunkServer上，作为Primary节点。被选中的Primary节点会对并发写请求进行排序，安排处理数据的顺序，保证并发数据安全。并将顺序返回给Master节点。

只有再有Master节点将处理数据通知其余的Secondaries，它们只能按照此顺序处理数据。

> 这样的设计减少了Master的管理开销，也保证了线程数据安全，将排序交由ChunkServer处理。但ChunkServer可能随时会失效，需要防止Lease被失效的机器长期占有，故而定一个Lease Time，限制单次Lease使用的时间。
>
> Primary节点可以通过申请延长Lease时间，满足数据处理的需求。

### Version

Version主要是用来标记数据的版本，在分配Lease，选择出primary后递增并告知primary，收到ack后再持久化记录后生效。只有最新版的数据才能证有效，失效的数据需要及时处理。

> ChunkServer可能短暂的失效重连，在这之间对数据的操作就可以通过Version来判断数据的新旧。

### 控制流和数据流

GFS中控制流和数据流是解耦的。数据流和控制流分开推送到所有设计的ChunkServer中，最后再按照Primary决定的处理顺序执行控制指令。

> 解耦的好处是数据流可以基于网络拓扑规划，提高机器带宽利用率，避免网路欧瓶颈和高延时。

数据流实际上是以Pipeline的形式推送到所有相关的ChunkServer中的。推送到机器上后，保存在LRU缓存中，再由此机器推送到其他机器，充分利用每一台机器的资源。

![image-20210908124156337](https://tva1.sinaimg.cn/large/008i3skNly1gu94bb7jxjj60v90u0tak02.jpg)

### 数据安全性

#### 数据完整性

GFS把Chunk分割为64KB大小的Block，每个Block对应一个32位的Chucksum，用于校验数据的完整性。

Chuncsum和数据和用户数据分开存储，保存在内存中，并最终通过WAL持久化。

> 机器磁盘损坏，重复的数据append等都会导致数据完整性有问题

#### 冗余存储

Chunk多副本异架异地存储，单副本丢失不会影响系统可用性。

#### 一致性

![image-20210908130412123](https://spongecaptain.cool/images/img_paper/image-20200719211636393.png)

我暂时没法很好的理解GFS的一致性模型，于是选择将原文奉上：

> “ **The state of a file region after a data mutation depends on the type of mutation**, whether it succeeds or fails, and whether there are concurrent mutations.
>
> A file region is consistent if all clients will always see the same data, regardless of which replicas they read from. A region is defined after a file data mutation if it is consistent and clients will see what the mutation writes in its entirety.
>
> When a mutation succeeds without interference from concurrent writers, the affected region is defined (and by implication consistent): all clients will always see what the mutation has written. 
>
> Concurrent successful mutations leave the region undefined but consistent: all clients see the same data, but it may not reflect what any one mutation has written. Typically, it consists of mingled fragments from multiple mutations. 
>
> A failed mutation makes the region inconsistent (hence also undefined): different clients may see different data at different times ”

总之，**GFS无法保证数据强一致**，它的一致性模型非常宽松。

Lease机制虽然能够使得并发顺序写入得到合理的操作顺序，但实际的数据Atomic Record Append采用的事At least Once消息模型，确保写入成功，但可能重复写入。随机写也无法保证数据一致。

## 总结

一切的系统设计都是需求和业务驱动的，设计中必然涉及对场景、业务、需求、实现等多方面的trade_off。

分布式系统的可扩展性的重要性要远远高于单机性能。



以上。

## 参考

[Google File System-GFS 论文阅读](https://spongecaptain.cool/post/paper/googlefilesystem/)

[GFS论文阅读](https://tanxinyu.work/gfs-thesis/)

[GFS论文导读](https://nxwz51a5wp.feishu.cn/docs/doccnNYeo3oXj6cWohseo6yB4id)

[GFS Paper](https://static.googleusercontent.com/media/research.google.com/zh-CN//archive/gfs-sosp2003.pdf)

[MIT6.824](https://pdos.csail.mit.edu/6.824/schedule.html)
