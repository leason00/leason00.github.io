---
title: 从Workload中优雅隔离Pod
date: 2024-07-17 10:58:34
categories: Kubernetes
tags:
  - 云原生
  - Kubernetes
keywords:
---


线上集群中，业务跑着跑着，突然发现有个Pod上出现大量错误日志，其他的Pod是正常的，该如何处理呢？

- 直接删除Pod？

这样不便于保留现场，可能会影响判断问题的根因

- 让业务方忍一会，先排查下问题？

会被喷死


最好的方案是既让Pod停止接收流量，又保留Pod
<!--more-->

1. 停止接收流量

停止接收流量这个动作是通过Pod的label来实现的，通过修改label来实现。其实本质就是把Pod从endpoint中移除，这样无论是服务化，还是http都会把当前这个节点移除，不再转发流量。
当然，这里的前提是服务化和http的节点发现是基于k8s的endpoint来实现的（理论上大家都会这么干，不排除有黑科技）。

首先要主动调用服务下线的方法，理论上这个调用应该会配再Pod的prestop钩子中，这样Pod被删除的时候，会先调用这个方法，然后再删除Pod。

```yaml
preStop:
    exec:
      command:
      - /bin/sh
      - -c
      - /bin/stop.sh
```

2. 将Pod从Workload中移除

调用下线完毕之后，再修改Pod的标签，这个标签的修改可以让Pod脱离Workload的控制，变成孤儿Pod，注意修改Pod标签也要让service的selector选择不到这个Pod，这样Pod也就从endpoint中移除，服务发现也就感知不到这个节点了。


3. 如果Pod是消费型业务，比如说 nsq worker，不具备主动发起下线怎么办？

这种情况，可以直接将Pod网络切断，这样Pod就无法接收流量了，切断方式也很简单，直接在Pod上加一个iptables规则，将流量全部丢弃即可。

```text
/sbin/iptables -A INPUT -s {node_ip}/32 -j ACCEPT &&   // 允许节点访问，避免kubelet liveness检查失败
/sbin/iptables -A OUTPUT -d {node_ip}/32 -j ACCEPT &&
/sbin/iptables -A OUTPUT -s localhost -d localhost -j ACCEPT &&
/sbin/iptables -A INPUT -s localhost -d localhost -j ACCEPT &&
/sbin/iptables -A INPUT -p tcp --tcp-flags RST RST -j ACCEPT &&
/sbin/iptables -A OUTPUT -p tcp --tcp-flags RST RST -j ACCEPT &&
/sbin/iptables -A INPUT -p tcp -j REJECT --reject-with tcp-reset &&
/sbin/iptables -A OUTPUT -p tcp -j REJECT --reject-with tcp-reset"""
```
