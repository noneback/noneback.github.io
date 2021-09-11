---
title: "MySQL索引浅析"
date: 2021-03-21T20:41:33+08:00
lastmod: 2021-03-21T20:41:33+08:00
mathjax: true
keywords: ["DB","MySQL"]
tags: ["DB","MySQL"]
categories: ["DB","MySQL"]
draft: false
author: "NoneBack"
comment: false
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

**数据库索引**，是DBMS中一个排序的数据结构，以协助快速查询、更新数据库中数据。一般来说，用于构建索引的数据结构有B树，B+树，哈希表等。

MySQL中使用的是B+树构建索引。理由是B+树的一个节点可以存储更多的数据，并且B+树中，仅有叶子节点存储数据，非叶子节点仅存储索引，故而能将索引尽量多的保存在内存中，减少了树高，也降低了查询索引时进入磁盘IO的次数，极大提高查询的效率。

## Innodb中的索引

### 聚簇索引与非聚簇索引

索引按照叶子节点保存的数据可分为聚簇索引和非聚簇索引两种

- **聚簇索引**： 叶子节点直接保存了数据行，能够直接查询到用户数据
- **非聚簇索引**：叶子节点保存了主键的值，通过**回表**，查询主键索引查询用户数据

Innodb引擎是利用主键索引组织表中的数据，每个表中一定需要有主键，利用主键构造B+树，得到主键索引，其中**主键索引就是聚簇索引**，其余的**二级索引都是非聚簇索引**

### 联合索引

联合索引是由多个字段组成的索引。

```sql
create index index_name on table_name (col_1,col_2...)
```

相比与单值索引，主要区别在于其遵守**最左前缀匹配原则**

>  最左前缀匹配原则：使用联合索引时，索引按照索引字段从左到右的顺序对索引值进行排序

## 使用索引优化查询性能

由于索引有序，故而能极大的提高查询的效率。使用索引进行查询优化时要遵守一些原则

### 最左前缀匹配原则

使用联合索引时，索引按照索引字段从左到右的顺序对索引值进行排序。查询索引时，我们也需要满足最左前缀匹配，否则数据的排列是无序的，会导致全表的扫描。

> 使用 col1,col2,col3构建索引，按照最左前缀匹配，在设计查询语句时我们需要按照col1 -> col2 -> col3的顺序去设计判断条件。
>
> `select * from table_name where col1 = 1 and col2 = 2;` 走索引
>
> `select * from table_name where col2 = 1 and col3 = 2;` 不走索引
>
> 注：**MySQL查询时，会一直向右匹配直到遇到范围查询(>、<、between、like)就停止匹配**

### 索引覆盖原则

索引覆盖，指通过查询索引可以直接查询到需要的值，而不需要回表等操作。设计合理的索引，可以减少回表的次数。

> 对联合索引(col1,col2,col3)
>
> 查询语句 `select col1,col2,col3 from test where col1=1 and col2=2`可以直接查到col1-col3的值，无需回表，因为他们的值已经被保存在二级索引中了。



