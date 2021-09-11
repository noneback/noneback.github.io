---
title: "Linux Cgroups简介"
date: 2021-06-08T22:26:17+08:00
lastmod: 2021-06-08T22:26:17+08:00
mathjax: true
keywords: ["Cgroups","Linux","Virtualization","Docker","Container"]
tags: ["Linux","Docker","Container"]
categories: ["Linux","Docker","Container","OS"]
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

**Linux Cgroups**(Control Groups)供了对一组进程及将来子讲程的资源限制、控制和统计的能力。这些资源包括CPU、内存、存储、网络等。通过 Cgroups,可以方便地限制某个进程的资源占用,并且可以实时地监控进程的监控和统计信息。


## Cgroups中的三个组件

- **cgroup**

    对进程分组管理的一种机制,一个 cgroup包含一组进程,并可以在这个 cgroup 上增加 Linux subsystem的各种参数配置,将一组进程和一组 subsystem的系统参数关联起来

- **subsystem**

    一组资源控制的模块

   ![image.png](https://i.loli.net/2021/06/08/p4e91XZRFAPBqyW.png)
    每个 subsystem会关联到定义了相应限制的 cgroup上,并对这个cgroup中的进程做相应的限制和控制。

- **hierarchy**

    hierarchy的功能是把一组 cgroup串成一个树状结构,一个这样的树便是一个hierarchy

    通过这种树状结构, Groups可以做到继承。

    > 场景：
    系统对一组定时的任条进程通过 cgroup1限制了CPU的使用率,然后其中有一个定时dump日志的进程还需要限制磁盘IO

    为了避免限制了磁盘IO之后影响到其他进程,就可以创建 cgroup2,但其继承于 cgroup1并制磁盘的1O,这样 cgroup2便继承了 cgroup1中对CPU使用率的限制,并且增加了磁盘IO的限制而不影响到 Cgroup1中的其他进程。

## 三者的相互关系

- 系统在创建了新的 hierarchy之后,系统中所有的进程**都会加入**个 hierarchy的 **Cgroup 根节点**,这个 Cgroup节点是 hierarchy默认创建的
- 一个subsystem只能附加到一个hierarchy上面
- 一个hierarchy可以附加多个subsystem
- 一个进程可以位于多个从属与不同的hierarchy的cgroup中
- fork出的子进程是和父进程在同一个cgroup中的。也可以之后移动到其他cgroup中

## 内核接口

Groups中的hierarchy是一种**树状**的组织结构, Kernel为了使对Cgroups的配置更直观,是通过一个**虚拟的树状文件系统配置 Cgroups**的,通过层级的目录拟出 Cgroups

- 创建挂载hierarchy，新建子cgroup

```bash
mkdir cgroup # 创建挂载点
sudo mount -t cgroup -o none,name=cgroup-test cgroup-test ./cgroup-test # 挂载hierarchy
sudo mkdir cgroup-1
sudo mkdir cgroup-2
tree

.
├── cgroup-1
│   ├── cgroup.clone_children
│   ├── cgroup.procs
│   ├── notify_on_release
│   └── tasks
├── cgroup-2
│   ├── cgroup.clone_children
│   ├── cgroup.procs
│   ├── notify_on_release
│   └── tasks
├── cgroup.clone_children
├── cgroup.procs
├── cgroup.sane_behavior
├── notify_on_release
├── release_agent
└── tasks
```

**不同文件的含义**

![image.png](https://i.loli.net/2021/06/08/LokHKWqXs5SN4cI.png)

- 在cgroup中添加和移动进程（将进程pid移入对应tasks文件中）

```bash
sudo sh -c "echo $$ >> ./cgroup-1/tasks" # 将终端进程移入cgroup-1中
cat /proc/$$/cgroup

>> 
13:name=cgroup-test:/cgroup-1
12:memory:/user.slice/user-1002.slice/session-12331.scope
11:perf_event:/
10:cpuset:/
9:freezer:/
8:blkio:/user.slice
7:rdma:/
6:hugetlb:/
5:pids:/user.slice/user-1002.slice/session-12331.scope
4:cpu,cpuacct:/user.slice
3:net_cls,net_prio:/
2:devices:/user.slice
1:name=systemd:/user.slice/user-1002.slice/session-12331.scope
0::/user.slice/user-1002.slice/session-12331.scope
```

- 通过subsystem限制cgroup中进程的资源

    首先将hierarchy关联到subsystem，系统默认将hierarchy关联到memory hierarchy

    ```bash
    # 首先,在不做限制的情况下,启动一个占用内存的stress进程
    stress --vm-bytes 200m --vm-keep -m 1
    sudo mkdir test-limit-memory && cd test-limit-memory # 创建一个cgroup
    sudo sh -c "echo "100m" > memory.limit" # 设置最大cgroup占用为100m
    sudo sh -c "echo $$ > tasks" # 将当前进程移入cgroup
    stress --vm-bytes 200m --vm-keep -m 1
    ```

    #### 最后可以观测到进程占用的内存被限制了
