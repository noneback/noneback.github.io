---
title: "MIT6.824-Bigtable"
date: 2021-09-16T22:54:59+08:00
lastmod: 2021-09-16T22:54:59+08:00
mathjax: true
keywords: []
tags: []
categories: []
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
之前在网上找到了别人翻译的BigTable论文，就顺手保存了下来，但一直没开始看。最近发现BigTable和目前组内做的项目有很多设计上相似的地方，于是用周末的时间快速的阅读了一遍。

这是Google分布式三大论文的最后一篇，本不属于MIT6.824课程的阅读材料的。但姑且先如此分类。

笔记依旧不深究具体细节，仅仅记录对问题的思考以及设计的思路。

## 介绍

  Bigtable 是一个分布式的**结构化数据**存储系统，构建于GFS之上，用于存储大量的结构化，半结构化数据。它属于NoSql数据存储，优势在于可拓展性和性能，以及基于GFS上的可靠容错。

> Design Goal：Wide Applicability、Scalability、High Performance、High Availability

## 数据模型

Bigtable的数据模型属于No Scheme的设计，仅提供了一个简单的数据模型，它将所有的数据视为字符串，数据的编解码交由上层业务方决定。

实际上，Bigtable 是一个**稀疏的、分布式的、持久化存储的多维度排序 Map**。Map的**索引**是**Row Key，Column Key以及TimeStamp**。Map中的**每一个Value就是一个无结构的Byte数组**。

```go
// 映射抽象
(row:string, column:string,time:int64)->string
// 一个Row Key实际上是 {Row , Column, Timestamp} 组成的多维结构。
```

![image-20210913205832997](https://tva1.sinaimg.cn/large/008i3skNly1gufarm0ykaj615k0d0jts02.jpg)

论文对数据模型原文阐述如下：

> A Bigtable is a sparse, distributed, persistent multidimensional sorted map.

Sparse，实际上是说同个Table中的Column属性是可以置空的，并且置空比较常见。

| Row  | Columns                    |
| ---- | -------------------------- |
| Row1 | {ID，Name，Phone}          |
| Row2 | {ID，Name，Phone，Address} |
| Row3 | {ID，Name，Phone，Email}   |

Distributed，此处分布式关键在于拓展性和容错性，也就是**Replication**和**Sharding**。Bigtable通过GFS的Replica实现副本容错，使用**Tablet**对数据分区，以实现拓展性。

Persistent Multidimentsional Sorted，持久化说明最终需要数据落盘，Bittable相关的设计有WAL，LSM优化前台读写时延，优化落盘速度。

> BigTable的开源实现就是HBase，是一种行列数据库

### Rows

Bigtable通过行关键字的字典序来组织数据，Row Key可以是任意的字符串。对于单行的读写操作是原子的。

> 字典序的好处在于可以将相关的行记录聚合
>
> 可以参考Mysql的实现，利用undo log的方式实现行操作的原子性

### Column Family

Column Keys 组成的集合叫做 Column Family，一个Column Family下的数据往往属于同一种类型。

一个Column Key由 Column Family : Qualifier组， 列族的名字必须是可打印的字符串,而限定词的名字可以是任意的字符串。

> 论文中有提到：
>
> > Access control and both disk and memory accounting are performed at the column-family level.
>
> 原因在于，业务方取得数据实际上更多的是以Column为单位取得相关的数据，比如读取网页content等操作。实践上，往往也将列数据压缩存储。基于此，Column Family显然是一个比Row更合适的Level。
>
> 如我们允许一些应用可以添加新的基本数据、一些应用可以读取基本数据并创建继承的列族、一些应用则只允许浏览数据(甚至可能因为隐私的原因不能浏览所有数据) 。

### Time Stamp

TimeStamp主要是为了维护不同时间的不同数据版本，属于一种逻辑时钟。同时它也作为索引，不同版本的数据可以通过时间戳索引查询。

> 设计上，一般按时间新旧排序，推测在数据版本少的时候可以利用一个指向上一个时间版本的指针来维护数据时间视图，在数据版本多的时候需要进化为索引结构。
>
> 显然基于时间戳必然有范围查询的需求，选择可排序数据结构作为索引比较合
>
> 但TimeStamp需要Table额外维护一个数据版本视图，带来一定的管理负担。一般的解决方法是限制数据版本的数量，将过期的数据进行GC处理。

### Tablet

Bigtable在存储设计上，采用的是**range-based**的**数据分片方式**，而Tablet是Bigtable中data sharding 和 load balance的基本单位。

Tablet其实就是有若干个Row组成的一块数据，并由一个Tablet Server进行管理。行数据在Bigtable系统内最终保存在一个Tablet上，并在适当的时候进行Tablet拆分合并，在Tablet Server之间负载均衡。

> Range Base的分片方式的好处是有利于范围查询，与之相对的是Hash分片的方式。

### SSTable

SSTable 是一个**持久化的、排序的、不可更改**的Map 结构,而 Map 是一个 key-value 映射的数据结构,key 和 value 的值都是任意的 Byte 串。

Tablet实际上是Bigtable系统中对外的存储单位，实际上，内部的存储文件是Google SSTable格式的。

> 从内部看，SSTable 是一系列的数据块(通常每个块的大小是 64KB)，通过索引加速定位数据。读取时先读索引，二分查索引，在读取数据块。

### API

原文中的API如下，主要是为了体现和RDB不同的地方。

```cpp
// Writing to Bigtable
// Open the table Table *T = OpenOrDie("/bigtable/web/webtable"); // Write a new anchor and delete an old anchor 
RowMutation r1(T,   "com.cnn.www"); 
r1.Set("anchor:www.c-span.org", "CNN"); r1.Delete("anchor:www.abc.com"); 
Operation op; Apply(&op, &r1)


 // Reading from Bigtable
Scanner scanner(T); ScanStream *stream; 
stream = scanner.FetchColumnFamily("anchor"); 
stream->SetReturnAllVersions(); 
scanner.Lookup("com.cnn.www"); 
for (; !stream->Done(); stream->Next()) { 
  printf("%s %s %lld %s\n", 
         scanner.RowName(), 
         stream->ColumnName(), 
         stream->MicroTimestamp(), 
         stream->Value());
}
```


## 架构设计

### 外部组件

Bigtable是基于Google内部其他组件之上构建的，这极大的简化了Bigtable的设计。

#### GFS

GFS是Bigtable底层的GFS，可以提供Replication，提供一定的数据容错性。

> 可以参考上一篇笔记内容

#### Chubby

Chubby是一个高可用的分布式锁组件，它提供了一个NameSpace，其中的目录和文件均可作为一个分布式锁来使用。

> 高可用是指维护了多个可提供服务副本，并使用paxos算法保证副本间的一致性。同时使用租约机制，防止失效的Chubby客户端一直持有锁。  

为什么需要Chubby？它的作用是什么？

原文中提到的功能有：

- 存储Bigtable的Column Family信息

- 存储ACL。ACL 是一种机制，用于定义用户访问存储对象的权限

- 存储了 元数据的起始位置，也就是Root Tablet的位置信息

  > Bigtable使用了一个三层的类B+树的存储数据结构，Chubby中保存了Root Tablet的位置信息，Root Tablet保存了其他MetaData的Tablet信息，其他MetaData的Tablet则保存着其他用户的Tablet集合信息。
  >
  > 在Bigtable启动时，会先从Chubby中获取Root tablet，然后再获取其他映射信息。
- Tablet Server的生命周期监控

  > Tablet Server在启动时，会在Chubby**指定目录**下生成一个唯一名称的文件，并获取此文件的排它锁。当Tablet Server失效时，会释放锁。
  >
  > Master通过监控这个目录中的文件以及持有锁的状态，来监控集群中的Tablet的状态以及配置变更

总结一下，Chubby的功能其实主要分为两类。一是利用Chubby作为高可用高可靠的存储节点来存储关键元信息；二是利用其提供的分布式锁服务来管理维护存储节点（Tablet Server）。

在GFS中，这些功能其实是由Master去负责管理维护的。在Bigtable中，由Chubby接管，这样简化了Master的设计，并减轻了Master的负载。

> 抽象意义上，Chubby也能视为Master节点的一部分。

### 内部组件

#### Master

Bigtable也属于Master-Slave的架构，这点个GFS以及MR的设计很像。不同之处在于，Bigtable将元数据交给了Chubby + Tablet Server去存储与管理，Master只负责调度需要的信息，不存储Tablet位置信息。

> Tablet分配，GC；Tablet Server监控，负载均衡；表的元数据修改等
>
> 所以调度需要的信息包含：
>
> 1. 所有Tablet的信息，用于分析分配和分布情况
> 2. Tablet Server的状态信息，判断是否满足分配条件

#### Tablet Server

Tablet Server 管理一系列的Tablet，负责处理Tablet的数据读写，以及Tablet的拆分合并等操作。

> Master不保存元信息，Client读取信息直接与Chubby和Tablet Server交互。
>
> Tablet的拆分由Tablet Server主动发起，并及时通知Master。这一步可能会消息丢失，所以最好使用WAL+重试的方式保证操作不丢失

#### Client SDK

作为Bigtable的接入层，业务方使用ClientSDK接入Bigtable。Client SDK作为Bigtable的入口，优化的关键在于怎么样可以减少获取元数据的次数。一般使用cache以及prefetch的思路去减少网络的交互，充分利用时间和空间局部性。

> 缓存的使用势必会带来不一致问题，需要设计合适的方案解决此问题。如不一致时重新寻址。

## 存储相关

### 映射关系 、寻址

Bigtable的数据实际上是由(Table, Row, Column)三元组唯一确定的，保存在Tablet中，Tablet最终保存在GFS SSTable中。

Tablet逻辑上可以理解为Bigtable的落盘实体，实际上是交由Tablet Server去管理维护，那么这样就需要Bigtable去维护一定的映射关系。

> 基于原文描述，可能需要维护的映射：
>
>
```cpp
 Mapping {
   Table => list of Tablets // 
   Tablet => Tablet handle
     
   struct Tablet handle {
     list of Rows // Tablet contains
     Tablet Server // where Tablet shores
     ...
   list of SSTable // where the tablet stores in GFS
   }
   
   // Indexes
   Row or Column Key => Tablet Location => SSTable 
 }
```

Bigtable通过Root Tablet + METADATA Table进行Tablet寻址。Chubby存储了Root Tablet的位置信息，METADATA Table则由Tablet Server负责维护。

Root Tablet中保存了其他METADATA Tablet的位置信息。而METADATA Table的每一个Tablet包含了一系列的User Tablets的位置信息（可以理解为UserTable handle）,  每个Tablet的位置信息保存在METADATA的Row中。

> METADATA Table 中的Row :
> 
> `(TableID,encoding of last row in Tablet) => Tablet Location`

![image-20210915142508074](https://tva1.sinaimg.cn/large/008i3skNly1guhk1wuu1pj60q80ge75k02.jpg)

> 系统采用了类似B+树的三层结构来维护tablet location信息

### 调度和监控

#### 调度

其实主要就是对Tablet的调度，包括分配和负载均衡。

其实两种归根到底都是分配问题。在任何一个时刻, 一个 Tablet 只能分配给一个 Tablet 服务器。Master保存了Tablet Server 相关的状态信息，当有Tablet需要分配时，就发送请求将Tablet分配出去。

> Master不维护寻址相关的状态信息，但需要维护Tablet Server的状态信息（持有的Tablets数量、状态、剩余资源等），可以通过心跳周期上报到Master。所以说，Master其实是无状态的，负载也比较轻。

#### 监控

监控是由Chubby + Master来完成的。

Tablet Server在启动时，会在Chubby**指定目录**下生成一个**唯一名称的文件**，并获取此文件的排它锁。当Tablet Server断开连接，lease失效后会自动释放文件锁。

> Tablet Server通过唯一文件决定是否对外提供服务。此文件可能被Master删除
>
> Tablet Server可能由于网络因素重新连接，此时只要文件存在，Tablet重连时又会重新尝试去获取这个文件的排他锁。
>
> 如果不存在，当原Tablet Server重连是，应当自动退出集群。

Master首先要在Chubby获取一个唯一文件排他锁保证Master节点的唯一性，并指定一个Tablet Server文件目录。

然后Master通过不断监控这个目录中的文件以及持有锁的状态，来监控集群中的Tablet的状态以及配置变更，并获取正在运行的Tablet Server列表。

一但发现有Tablet Server失效，Master就会把Chubby属于原Tablet Server的唯一文件删除，并把原来这个Tablet Server维护的Tablet集合重新分配给其他Tablet Server。

> Tablet Server失效有两种情况，一种是无法与Chubby连接，二是成为孤岛或者宕机。前者可以通过文件锁状态判断，后者通过Master发送心跳。其余情况，可能是Chubby无法提供服务。

之后在和所有Active的Tablet Server进行通信，获取Tablet Server的状态信息；扫描METADATA表获取未分配的Tablet信息。

> 监控的目的其实就是为了调度。

## Compaction

Bigtable对外提供读写服务，并且使用了LSM的结构对写性能进行优化。对于一个写操作，首先通过Chubby中保存的ACL信息，判断用户的权限；通过之后再以WAL的方式顺序写记录操作再CommitLog和Memtable中，并且最后会被持久化到SSTable中；

![image-20210915195135522](https://tva1.sinaimg.cn/large/008i3skNly1guhk6llq76j60uk0lsq4402.jpg)

由图中可以看出，memtable是保存在内存中的，无法无限的增加。所以Bigtable在memtable增长到一定大小的时候会进行一次Minor Compaction，将memtable的数据写入一个SSTable中，并写入GFS。

> 实际上，memtable在转为SSTable之前会先转换成immutable memtable，并生成新的memtable支持前台写入。这样的中间状态其实是为了Minor Compaction不影响前台写。

![image-20210916172932210](https://tva1.sinaimg.cn/large/008i3skNly1guill1zltrj615g0p8adp02.jpg)

Bigtable在处理写入数据时提出了**Compaction**概念，加速前台写。所有的前台随机写被转换为顺序写。并在后台的Compact进程中再次对数据进行写入。以读写放大为代价，优化前台感知到的写性能。

所谓Compaction，本质上就是对数据的一次再次扫描，在扫描写入过程中，对数据进行合并压缩和GC。

一般Compaction以多个不可变数据作为输入，Compact之后会将数据重新写入另一个新的只读有序结构(如SSTable)或者随机写落盘。

前台写对Compaction的参与数据不影响，这使得Compaction步骤原生支持并行。
> 原文中提到了三种Compaction：
>
> **Minor Compaction**：将memtable转化成SSTable的过程就是Minor Compaction，写入过程中会丢弃被删除的数据，并只保留数据的终态。
> > Minor Compaction的目的在于减少Tablet Server的内存使用，以及CommitLog的大小。
>
> **Merge Compaction**：Memtable和SSTable一起Compact得到一个新的SSTable  
>
> **Major Compaction**：多个SSTable也可能需要Compact成一个SSTable
但对于读请求，我们可能需要聚合Memtable以及一定的SSTable来做读查询，因为查询的数据可能存在于memtable或者SSTable中。

原文中引入了**二级缓存**和**Bloom Filter**来加速读查询。

Tablet Server有两级缓存。第一层是**扫描缓存**，主要缓存从SSTable读取过的的KV pair；第二级是**Block缓存**，缓存读取的SSTable Block。 

对于经常要重复读取相同数据的应用程序来说,扫描缓存非常有效；对于经常要读取刚刚读过的数据附近的数据的应用程序来说，Block 缓存更有用。

**Bloom Filter**简单来说就是可以判断某个Key是否不存在。

可以为全局或者每个Tablet Server，以及SSTable分别维护一个Bloom Filter，用于加速读查询，减少到SSTable的查询；对于可能存在的Key，利用二分法查询

## 优化

除了上文中说的到优化方式，原文还提到了几种优化手段。

### 局部性

通过配置或者自动等方式，把高频使用的列数据组合生成一个SSTable存储，减少分开Fetch的时间。

> 空间换时间，充分利用局部性原理

### 压缩

将SSTable中的分块进行二级压缩处理。本质其实是为了减少网络传输的带宽和时延，但需要额外的压缩和解压计算。

> 分块压缩是为了减少编解码的时间以及提高并行效率

### CommitLog 设计

关键其实是Log的粒度问题。Tablet粒度下，会有大量的Log文件。在并行写入GFS中会有大量的磁盘Seek操作，并且不利于Batch化。集群单独一个CommitLog会带来恢复上的高复杂度。

Bigtable中是每个Tablet Server一个Commit Log。但由于Tablet Server维护了多个Tablet，这就使得Bigtable必须维护LogEntry到TabletID的映射以及顺序，以便在恢复时使用。对一个Tablet的数据恢复可能会导致扫描整个CommitLog，

此处Bigtable的优化是将Log按照(Table, row, log seq num)并行分块排序，使得同一个Tablet的LogEntry聚合。

## 总结

不要过渡设计，Simple is Better Than Complex。

对于分布式服务，集群监控非常重要。Google三篇论文中对集群状态的监控都是不可缺少的一环。监控的意义也在于支持集群的调度。

设计时不要对其他系统做出任何假设，出现的不仅仅是常见的网络问题，现实中可能会遇到各类问题。

利用后台处理加速前台感知。利用简单的机制处理前台请求，再开启后台进程善后。

## 参考

[wikipedia](https://zh.wikipedia.org/wiki/Bigtable)

[Bigtable](https://static.googleusercontent.com/media/research.google.com/zh-CN//archive/bigtable-osdi06.pdf)

[典型分布式系统分析：Bigtable](https://www.cnblogs.com/xybaby/p/9096748.html)

[LSM树详解](https://zhuanlan.zhihu.com/p/181498475)
