---
title: Kubernetes GPU 虚拟化方案
date: 2025-01-09 14:43:21
categories: Kubernetes
tags:
  - 云原生
  - Kubernetes
  - GPU
  - AI
keywords: Kubernetes GPU 虚拟化方案
---
### 主流架构
Device Plugin：K8s制定设备插件接口规范，定义异构资源的上报和分配，设备厂商只需要实现相应的API接口，无需修改kubelet源码即可实现对其他硬件设备的支持。
Extended Resource：Scheduler可以根据Pod的创建删除计算资源可用量，而不再局限于CPU和内存的资源统计，进而将有特殊资源需求的Pod调度到相应的节点上。

通过Device Plugin 异构资源调度流程如下：
1. Device plugin 向kubelet上报当前节点资源情况
2. 用户通过yaml文件创建负载，定义Resource Request
3. kube-scheduler根据从kubelet同步到的资源信息和Pod的资源请求，为Pod绑定合适的节点
4. kubelet监听到绑定到当前节点的Pod，调用Device plugin的allocate接口为Pod分配设备
5. kubelet启动Pod内的容器，将设备映射给容器
<!--more-->

![架构图](Kubernetes-GPU-虚拟化方案/img.png)

GPU虚拟化方案大致分为用户态隔离和内核态隔离：
1. 用户态主要是通过vcuda的方式，劫持cuda调用，比如下面介绍的两种开源
2. 内核态主要是用过虚拟gpu驱动的方式，比如腾讯云的qgpu和阿里云的cgpu，不过这两个都是闭源的

### Nvidia-GPU

NVIDIA 提供的 Time-Slicing GPUs in Kubernetes 是一种通过 oversubscription(超额订阅) 来实现 GPU 共享的策略，有两种策略，单卡调度模式和超卖模式。
单卡的意思就是一个Pod调度一张GPU，当这个GPU有Pod使用了，就不可被其他Pod使用。

超卖模式这种策略能让多个任务在同一个 GPU 上进行，而不是每个任务都独占一个 GPU。Time Slicing(时间片)指的是 GPU 本身的时间片调度。
也就是说假如有两个进程同时使用同一个GPU，两个进程同时把 CUDA 任务发射到 GPU 上去，GPU 并不会同时执行，而是采用时间片轮转调度的方式。
进程和进程间的显存和算力没有任何限制，谁抢到就是谁的。

### 腾讯GPU-manager

基于Nvidia的k8s Device Plugin 实现
[GPUManager](https://github.com/tkestack/gpu-manager)是腾讯自研的容器层GPU虚拟化方案，除兼容Nvidia 官方插件的GPU资源管理功能外，还增加碎片资源调度、GPU调度拓扑优化、GPU资源Quota等功能，在容器层面实现了GPU资源的化整为零，而在原理上仅使用了wrap library和linux动态库链接技术，就实现了GPU 算力和显存的上限隔离。

在工程设计上，GPUManager方案包括三个部分，cuda封装库vcuda、k8s device plugin 插件gpu-manager-daemonset和k8s调度插件gpu-quota-admission。

vcuda库是一个对nvidia-ml和libcuda库的封装库，通过劫持容器内用户程序的cuda调用限制当前容器内进程对GPU和显存的使用。

gpu-manager-daemonset是标准的k8s device plugin，实现了GPU拓扑感知、设备和驱动映射等功能。GPUManager支持共享和独占两种模式，当负载里tencent.com/vcuda-core request 值在0-100情况下，采用共享模式调度，优先将碎片资源集中到一张卡上，当负载里的tencent.com/vcuda-core request为100的倍数时，采用独占模式调度，需要注意的是GPUManager仅支持0~100和100的整数倍的GPU需求调度，无法支持150，220类的非100整数倍的GPU需求调度。

gpu-quota-admission是一个k8s Scheduler extender，实现了Scheduler的predicates接口，kube-scheduler在调度tencent.com/vcuda-core资源请求的Pod时，predicates阶段会调用gpu-quota-admission的predicates接口对节点进行过滤和绑定，同时gpu-quota-admission提供了GPU资源池调度功能，解决不同类型的GPU在namespace下的配额问题。
![架构图](Kubernetes-GPU-虚拟化方案/img_1.png)

方案优点：
1. 同时支持碎片和整卡调度，提高GPU资源利用率
2. 支持同一张卡上容器间GPU和显存的使用隔离
3. 基于拓扑感知，提供最优的调度策略
4. 对用户程序无侵入，用户无感

方案缺点：
1. 驱动和加速库的兼容性依赖于厂商
2. 存在约5%的性能损耗

**此项目腾讯云官方已不再支持，社区也处在无人维护状态，亲测cuda12有问题，调用报错**

### HAMi
[HAMi](https://github.com/Project-HAMi/HAMi/tree/master) 可为多种异构设备提供虚拟化功能，支持设备共享和资源隔离。
支持的设备：
![支持的设备](Kubernetes-GPU-虚拟化方案/img_2.png)

![架构](Kubernetes-GPU-虚拟化方案/img_3.png)

HAMi 由多个组件组成，包括统一的 mutatingwebhook、统一的调度器扩展器、不同的设备插件以及针对每种异构 AI 设备的容器内虚拟化技术。
https://github.com/Project-HAMi/HAMi/tree/master

能力：
- 支持碎片、整卡、多卡调度隔离，支持按量或者按百分比调度隔离
- 支持指定目标卡型
- 支持指定目标卡

目前该项目非常活跃，并且支持的cuda版本也比较友好，[>10.1](https://github.com/Project-HAMi/HAMi/issues/785)