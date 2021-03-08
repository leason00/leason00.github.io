---
title: Terraform管理云资源实践
date: 2021-03-08 10:08:57
categories: Terraform
tags:
    - 运维
    - Terraform
---

### 背景
Terraform是一款开源的Cli工具，网上的很多文章都是单机安装一个然后创建个目录就去操作云资源；如果在高可用的前提，如何将Terraform cli变成一个嵌入运维流程的一个组件？不仅仅是人编写tf模板然后去apply？

自动化的驱动Terraform，无非包含这几个步骤：

* 初始化Terraform
* 填充资源模板
* apply资源
* show资源
<!--more-->

### 初始化Terraform
创建一个云资源目录，如cloudxxx-test001
云资源的目录下需要有Terrafor的Provider信息，以及实例声明信息。
创建好了模板文件，就需要初始化Terraform，以及下载Provider插件，建议提前下载好插件到指定的目录，使用容器可以直接打到镜像里
这样初始化直接指定plugin地址：
```
/usr/local/bin/terraform init -plugin-dir=/Users/lixiangli/.terraform.d/plugins
```
**注意:确保插件地址内有你声明的插件版本**

由于Terraform apply是不支持选择apply哪个资源，因此上面的实现方式可以发现，一个目录是放一个云资源。为了让每次操作的影响范围是可控的。这种方式会带来一个问题，就是state的文件存储也必须是隔离的，否则出现的情况是apply 资源cloudxxx-test001时 cloudxxx-test002会被直接删除。
### 模板文件生成
通过代码的方式去驱动Terraform, 无法避免的一步就是生成所对应的云资源的模板文件，我们这边使用golang，所以找到需要对接的云的Provider的文档然后定义成如下：
```
resource "ucloud_disk" "ucloud_disk_{{ .ObjectMeta.UID }}" {
  availability_zone = "{{ .Spec.Zone }}"
  name              = "{{ .Spec.InstanceName }}"
  disk_size         = "{{ .Spec.InstanceSize }}"
  disk_type         = "{{ .Spec.InstanceType }}"
  charge_type       = "{{ .Spec.ChargeType }}"
}

```
在程序运行时动态填充这些模板即可

### 选择合适的状态存储
Terraform是个有状态的组件，如果部署多个实例的话，官方默认的state文件的模式必然是无法满足需求的。
所以我们这边选择的是etcdv3
配置如下：
```
terraform {
  required_providers {
    ucloud = {
      source = "ucloud/ucloud"
      version = "~>1.23.0"
    }
  }
  backend "etcdv3" {
    endpoints = ["http://127.0.0.1:2379/"]
    lock      = true
    prefix    = "/terraform-state/clouddisk/77c2d636-7a59-11eb-9d32-12caef3c0b88"
    cacert_path = ""
    cert_path = ""
    key_path = ""
  }
}
provider "ucloud" {
    public_key  = "xxxxxxx"
    private_key = "xxxxxx"
    region      = "cn-bj2"
    project_id  = ""
}

```
backend的prefix资源加了uuid，实际上是为了解决上面一个目录是放一个云资源锁带来的问题，也就是说那个uuid实际上是对应的单独资源id，每个资源都有单独的state文件

### 如何支持多云
支持多云是Terraform的强项，支持多云依然需要在上次软件做好一定的屏蔽工作。
Terraform需要做的就是准备好多套云的tf模板去填充
如腾讯云：
```
resource "tencentcloud_cbs_storage" "tencentcloud_disk_{{ .ObjectMeta.UID }}" {
  storage_type      = "{{ .Spec.InstanceType }}"
  storage_name      = "{{ .Spec.InstanceName }}"
  storage_size      = "{{ .Spec.InstanceSize }}"
  availability_zone = "{{ .Spec.Zone }}"
  project_id        = "{{ .Spec.ProjectID }}"
}
```
如优刻得：
```
resource "ucloud_disk" "ucloud_disk_{{ .ObjectMeta.UID }}" {
  availability_zone = "{{ .Spec.Zone }}"
  name              = "{{ .Spec.InstanceName }}"
  disk_size         = "{{ .Spec.InstanceSize }}"
  disk_type         = "{{ .Spec.InstanceType }}"
  charge_type       = "{{ .Spec.ChargeType }}"
}
```
上层的数据结构可以声明成一样的，所有的差异由tf模板来屏蔽