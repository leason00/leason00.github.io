---
title: StackStorm(事件驱动的自动化引擎)
date: 2021-02-25 20:57:38
tags:
    - 运维
    - StackStorm
---


### 概念

StackStorm是一个功能强大的开源自动化平台，可将所有应用程序，服务和工作流程连接起来。 它具有可扩展性，灵活性, 设计中包含了对DevOps和ChatOps的热爱。它可以将您现有的基础架构和应用程序环境联系在一起，以便您可以更轻松地自动化操作该环境。它特别专注于针对事件采取行动。

* 便利的故障排除 - 触发由监控系统捕获的系统故障，在物理节点、OpenStack或Amazon实例和应用程序组件上运行一系列诊断检查，并将结果发布到共享通信环境中，如HipChat或JIRA。

* 自动修复 - 识别和验证OpenStack计算节点上的硬件故障，正确隔离实例并向管理员发送关于潜在停机时间的电子邮件，但如果出现任何问题 - 暂停工作流程并呼叫人员。
* 持续部署 - 与Jenkins一起构建和测试，配置新的AWS群集，基于NewRelic的应用程序性能数据，打开负载均衡器的一些流量，以及前滚或回滚

<!--more-->

![649e1caba0f4cbb43c121b074316e9db.jpeg](evernotecid://4A1C4057-93FE-4241-906F-1516D067837A/appyinxiangcom/22342343/ENResource/p34)

#### 角色
* Sensors是用于分别接收或监视事件的入站或出站集成的Python插件。 当来自外部系统的事件发生并由传感器处理时，StackStorm触发器将发射到系统中。
* Triggers是外部事件的StackStorm表示形式。 有通用触发器（例如定时器，webhooks）和集成触发器（例如，Sensu告警，JIRA问题更新）。 通过编写传感器插件可以定义新的触发器类型。
* Actions是StackStorm出站集成。 有通用动作（ssh，REST调用），集成（OpenStack，Docker，Puppet）或自定义操作。 动作是Python插件或任何脚本，通过添加几行元数据将其消耗到StackStorm中。 动作可以由用户通过CLI或API直接调用，或者作为规则和工作流程的一部分使用和调用。
* Rules将触发器映射到动作（或工作流），应用匹配条件并将触发器加载到动作输入中。
* Workflows将动作拼接成“超级Actions”，定义顺序，转换条件以及传递数据。 大多数自动化不止一步，因此需要多个动     作。 工作流就像“原子”动作一样，可在Action库中使用，并且可以手动调用或由规则触发。
* Packs是内容部署的单位。 它们通过对集成（触发器和动作）和自动化（规则和工作流）进行分组，简化了StackStorm可插拔内容的管理和共享。 StackStorm Exchange上有越来越多的包可用。 用户可以创建自己的包，在Github上共享它们，或者提交给StackStorm Exchange.

#### 流程
![bf6047ae0c9f762d5e48233f46d44c65.png](evernotecid://4A1C4057-93FE-4241-906F-1516D067837A/appyinxiangcom/22342343/ENResource/p35)

1. 从各个服务系统通过push或pull的方式把event传给sensors
2. sensors会产生一个trigger到规则配置中查询该trigger对应的动作或者工作流
3. 将来自工作流的Action发送到消息队列（内置rabbitmq）中Actions到达外部的系统后就执行相应的动作
4. 日志和审计历史被推送到数据库进行存储（Mongodb）


### Sensors
传感器是将外部系统和事件与StackStorm集成的一种方式。传感器是一段Python代码，它们要么定期轮询某些外部系统，要么被动地等待入站事件。

SampleSensor Yaml:
```
  class_name: "SampleSensor"
  entry_point: "sample_sensor.py"
  description: "Sample sensor that emits triggers."
  trigger_types:
    -
      name: "event"
      description: "An example trigger."
      payload_schema:
        type: "object"
        properties:
          executed_at:
            type: "string"
            format: "date-time"
            default: "2014-07-30 05:04:24.578325"
```

SampleSensor Python:
```
from st2reactor.sensor.base import Sensor


class SampleSensor(Sensor):
    """
    * self.sensor_service
        - provides utilities like
            - get_logger() - returns logger instance specific to this sensor.
            - dispatch() for dispatching triggers into the system.
    * self._config
        - contains parsed configuration that was specified as
          config.yaml in the pack.
    """

    def setup(self):
        # Setup stuff goes here. For example, you might establish connections
        # to external system once and reuse it. This is called only once by the system.
        pass

    def run(self):
        # This is where the crux of the sensor work goes.
        # This is called once by the system.
        # (If you want to sleep for regular intervals and keep
        # interacting with your external system, you'd inherit from PollingSensor.)
        # For example, let's consider a simple flask app. You'd run the flask app here.
        # You can dispatch triggers using sensor_service like so:
        # self.sensor_service(trigger, payload, trace_tag)
        #   # You can refer to the trigger as dict
        #   # { "name": ${trigger_name}, "pack": ${trigger_pack} }
        #   # or just simply by reference as string.
        #   # i.e. dispatch(${trigger_pack}.${trigger_name}, payload)
        #   # E.g.: dispatch('examples.foo_sensor', {'k1': 'stuff', 'k2': 'foo'})
        #   # trace_tag is a tag you would like to associate with the dispatched TriggerInstance
        #   # Typically the trace_tag is unique and a reference to an external event.
        pass

    def cleanup(self):
        # This is called when the st2 system goes down. You can perform cleanup operations like
        # closing the connections to external system here.
        pass

    def add_trigger(self, trigger):
        # This method is called when trigger is created
        pass

    def update_trigger(self, trigger):
        # This method is called when trigger is updated
        pass

    def remove_trigger(self, trigger):
        # This method is called when trigger is deleted
        pass
```

### Triggers
用于标识传入StackStorm的事件
Internal Triggers：

1. st2.generic.actiontrigger
2. st2.generic.notifytrigger
3. st2.action.file_writen
4. st2.generic.inquiry


### Rules
StackStorm使用Rules和Workflow操作模式捕获为自动化。规则将触发器映射到操作（或工作流），应用匹配条件，并将触发器有效负载映射到Actions输入

```
    name: "rule_name"                      # required
    pack: "examples"                       # optional
    description: "Rule description."       # optional
    enabled: true                          # required

    trigger:                               # required
        type: "trigger_type_ref"

    criteria:                              # optional
        trigger.payload_parameter_name1:
            type: "regex"
            pattern : "^value$"
        trigger.payload_parameter_name2:
            type: "iequals"
            pattern : "watchevent"

    action:                                # required
        ref: "action_ref"
        parameters:                        # optional
            foo: "bar"
            baz: "{{ trigger.payload_parameter_1 }}"
```
### Actions
Action是可以在您的环境中执行任意自动化或修复任务的代码段。它们可以用任何编程语言编写，是最小执行单元。

* local-shell-cmd/local-shell-script
* remote-shell-cmd/remote-shell-script
* python-script
* http-request
* workflow
* 自定义

Sample Python Action：
```
name: "echo_action"
runner_type: "python-script"
description: "Print message to standard output."
enabled: true
entry_point: "my_echo_action.py"
parameters:
    message:
        type: "string"
        description: "Message to print."
        required: true
        position: 0
```
```
import sys

from st2common.runners.base_action import Action

class MyEchoAction(Action):
    def run(self, message):
        print(message)

        if message == 'working':
            return (True, message)
        return (False, message)
```
### Workflows
为了捕获并自动执行这些操作，StackStorm使用了工作流程。工作流将原子动作嵌入到更高级别的自动化中，并通过在正确的时间以正确的输入调用正确的动作来编排其执行。可以理解为扩展版本的Actions

1. Orquesta: designed specifically for StackStorm 
2. ActionChain: one by one
3. Mistral: a dedicated workflow service, originated in OpenStack

Orquesta:
```
version: 1.0

description: A simple workflow.

# A list of strings, assuming value will be provided at runtime or
# key value pairs where value is the default value when value
# is not provided at runtime.
input:
  - arg1
  - arg2: abc

# A list of key value pairs.
vars:
  - var1: 123
  - var2: True
  - var3: null

# A dictionary of task definition. The order of execution is
# determined by inbound task transition and the condition of
# the outbound transition.
tasks:
  task1:
    action: core.noop
    next:
      - do: task2
  task2:
    action: core.noop

# A list of key value pairs to output.
output:
  - var3: <% ctx().arg1 %>
  - var4:
      var41: 456
      var42: def
  - var5:
      - 1.0
      - 2.0
      - 3.0
```
https://docs.stackstorm.com/3.2/orquesta/languages/orquesta.html

### Packs
Packs是扩展StackStorm的集成和自动化的部署单位。Pack里包含了Actions, Workflows, Rules, Sensors。

![fe629c1ca1bc3f3841149fe8aa017d07.png](evernotecid://4A1C4057-93FE-4241-906F-1516D067837A/appyinxiangcom/22342343/ENResource/p36)

Pack如何安装到worker上：

1. pull code 
2. install requirements
3. config
4. reload
