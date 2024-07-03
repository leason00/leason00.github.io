---
title: 开发一个MutatingWebhook
date: 2024-04-28 16:11:03
categories: Kubernetes
tags:
  - 云原生
  - Kubernetes
keywords:
---

# 介绍
Webhook就是一种HTTP回调，用于在某种情况下执行某些动作，Webhook不是K8S独有的，很多场景下都可以进行Webhook，比如在提交完代码后调用一个Webhook自动构建docker镜像

准入 Webhook 是一种用于接收准入请求并对其进行处理的 HTTP 回调机制。 可以定义两种类型的准入 Webhook， 即验证性质的准入 Webhook 和变更性质的准入 Webhook。 变更性质的准入 Webhook 会先被调用。它们可以修改发送到 API 服务器的对象以执行自定义的设置默认值操作。

在完成了所有对象修改并且 API 服务器也验证了所传入的对象之后， 验证性质的 Webhook 会被调用，并通过拒绝请求的方式来强制实施自定义的策略。

Admission Webhook使用较多的场景如下
1. 在资源持久化到ETCD之前进行修改（Mutating Webhook），比如增加init Container或者sidecar Container
2. 在资源持久化到ETCD之前进行校验（Validating Webhook），不满足条件的资源直接拒绝并给出相应信息

<!--more-->
组成

1. webhook 服务
2. webhook 配置
3. webhook 证书


# 创建核心组件Pod的Webhook
## 使用kubebuilder新建webhook项目

```text
kubebuilder init --domain test.com --repo gitlab.qima-inc.com/test-operator
```
```text
(base) (⎈ |kubernetes-admin@qa-u03:qa)➜  test-operator kubebuilder init --domain test.com --repo gitlab.qima-inc.com/test-operator
INFO Writing kustomize manifests for you to edit...
INFO Writing scaffold for you to edit...
INFO Get controller runtime:
$ go get sigs.k8s.io/controller-runtime@v0.17.2
INFO Update dependencies:
$ go mod tidy
go: go.mod file indicates go 1.21, but maximum version supported by tidy is 1.19
Error: failed to initialize project: unable to run post-scaffold tasks of "base.go.kubebuilder.io/v4": exit status 1
```
因为我默认是是go1.19所以版本达不到要求，这里两种处理方式
1. 指定 --plugins go/v3 --project-version 3
2. 切换高版本golang 这里我切换了go1.22


```text
(base) (⎈ |kubernetes-admin@qa-u03:qa)➜  test-operator kubebuilder init --domain test.com --repo gitlab.qima-inc.com/test-operator                                    
INFO Writing kustomize manifests for you to edit... 
INFO Writing scaffold for you to edit...          
INFO Get controller runtime:
$ go get sigs.k8s.io/controller-runtime@v0.17.2 
INFO Update dependencies:
$ go mod tidy           
Next: define a resource with:
$ kubebuilder create api
```

## 生成核心组件Pod的API

```text
(base) (⎈ |kubernetes-admin@qa-u03:qa)➜  test-operator kubebuilder create api --group core --version v1 --kind Pod                                                    
INFO Create Resource [y/n]                        
n
INFO Create Controller [y/n]                      
n
INFO Writing kustomize manifests for you to edit... 
INFO Writing scaffold for you to edit...          
INFO Update dependencies:
$ go mod tidy        
```
这里有两个选项，创建资源和创建控制器
因为是内置资源Pod所以不需要创建资源，也不需要控制器
假如是自定义资源，需要创建资源，创建控制器

## 创建webhook
```text
(base) (⎈ |kubernetes-admin@qa-u03:qa)➜  test-operator kubebuilder create webhook --group core --version v1 --kind Pod --defaulting --programmatic-validation
INFO Writing kustomize manifests for you to edit... 
ERRO Unable to find the target(s) #- path: patches/webhook/* to uncomment in the file config/crd/kustomization.yaml. 
ERRO Unable to find the target(s) #configurations:
#- kustomizeconfig.yaml to uncomment in the file config/crd/kustomization.yaml. 
INFO Writing scaffold for you to edit...          
INFO api/v1/pod_webhook.go                        
INFO api/v1/pod_webhook_test.go                   
INFO api/v1/webhook_suite_test.go                 
INFO Update dependencies:
$ go mod tidy           
INFO Running make:
$ make generate                
mkdir -p /Users/xxxx/test-operator/bin
Downloading sigs.k8s.io/controller-tools/cmd/controller-gen@v0.14.0
/Users/xxxx/test-operator/bin/controller-gen-v0.14.0 object:headerFile="hack/boilerplate.go.txt" paths="./..."
Next: implement your new Webhook and generate the manifests with:
$ make manifests
```

代码结构

```text
.
├── Dockerfile
├── Makefile
├── PROJECT
├── README.md
├── api
│   └── v1
│       ├── pod_webhook.go
│       ├── pod_webhook_test.go
│       └── webhook_suite_test.go
├── bin
│   └── controller-gen-v0.14.0
├── cmd
│   └── main.go
├── config
│   ├── certmanager
│   │   ├── certificate.yaml
│   │   ├── kustomization.yaml
│   │   └── kustomizeconfig.yaml
│   ├── crd
│   │   └── patches
│   │       ├── cainjection_in_pods.yaml
│   │       └── webhook_in_pods.yaml
│   ├── default
│   │   ├── kustomization.yaml
│   │   ├── manager_auth_proxy_patch.yaml
│   │   ├── manager_config_patch.yaml
│   │   ├── manager_webhook_patch.yaml
│   │   └── webhookcainjection_patch.yaml
│   ├── manager
│   │   ├── kustomization.yaml
│   │   └── manager.yaml
│   ├── prometheus
│   │   ├── kustomization.yaml
│   │   └── monitor.yaml
│   ├── rbac
│   │   ├── auth_proxy_client_clusterrole.yaml
│   │   ├── auth_proxy_role.yaml
│   │   ├── auth_proxy_role_binding.yaml
│   │   ├── auth_proxy_service.yaml
│   │   ├── kustomization.yaml
│   │   ├── leader_election_role.yaml
│   │   ├── leader_election_role_binding.yaml
│   │   ├── role.yaml
│   │   ├── role_binding.yaml
│   │   └── service_account.yaml
│   └── webhook
│       ├── kustomization.yaml
│       ├── kustomizeconfig.yaml
│       ├── manifests.yaml
│       └── service.yaml
├── go.mod
├── go.sum
├── hack
│   └── boilerplate.go.txt
└── test
├── e2e
│   ├── e2e_suite_test.go
│   └── e2e_test.go
└── utils
└── utils.go
```
## 实现Webhook相关代码

因为只有Webhook，没有Controller 所以只需要实现Webhook相关代码即可，同时需要注释掉一些代码如：
Dockerfile中的
```Dockerfile
# COPY internal/controller/ internal/controller/
```

修改api/v1/xxx_suite_test.go
因为核心组件Pod的Webhook和一般的CRD的webhook不一样，此处生成的pod_webhook.go只有Default()这个function，因此，我们需要直接重写整个代码，最重要的是Handle()方法。

```go
/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1

import (
	"fmt"
	"net/http"
	"sigs.k8s.io/controller-runtime/pkg/client"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/webhook/admission"
)

// log is for logging in this package.
var podlog = logf.Log.WithName("pod-resource")

// 定义核心组件pod的webhook的主struct，类似于java的Class
type PodWebhookMutate struct {
	Client  client.Client
	decoder *admission.Decoder
}

// +kubebuilder:webhook:path=/mutate-core-v1-pod,mutating=true,failurePolicy=fail,sideEffects=None,groups=core,resources=pods,verbs=create;update,versions=v1,name=mpod.kb.io,admissionReviewVersions=v1
func (a *PodWebhookMutate) Handle(ctx context.Context, req admission.Request) admission.Response {
	pod := &corev1.Pod{}
	err := a.decoder.Decode(req, pod)
	if err != nil {
		return admission.Errored(http.StatusBadRequest, err)
	}

	// TODO: 变量marshaledPod是一个Map，可以直接修改pod的一些属性
	marshaledPod, err := json.Marshal(pod)
	if err != nil {
		return admission.Errored(http.StatusInternalServerError, err)
	}
	// 打印
	fmt.Println("======================================================")
	fmt.Println(string(marshaledPod))
	return admission.PatchResponseFromRaw(req.Object.Raw, marshaledPod)
}

func (a *PodWebhookMutate) InjectDecoder(d *admission.Decoder) error {
	a.decoder = d
	return nil
}
```

修改main.go文件：
```go
if os.Getenv("ENABLE_WEBHOOKS") != "false" {
    //if err = (&corev1.Pod{}).SetupWebhookWithManager(mgr); err != nil {
    //	setupLog.Error(err, "unable to create webhook", "webhook", "Pod")
    //	os.Exit(1)
    //}
    mgr.GetWebhookServer().Register("/mutate-core-v1-pod", &webhook.Admission{Handler: &v1.PodWebhookMutate{Client: mgr.GetClient()}})
}
```

生成mainfests
```bash
make manifests generate
```

## 证书

### 手动签发证书
https://cuisongliu.github.io/2020/07/kubernetes/admission-webhook/

### 自动签发证书
webhook 服务启动时自动生成证书，授权证书

1. 创建CA根证书以及服务的证书
2. 将服务端、CA证书写入 k8s Secret，并且支持find or create
3. 本地写入证书
4. 获取MutatingWebhookConfiguration和ValidatingWebhookConfiguration将caCert写入webhook config中的ClientConfig.CABundle（这里有个问题是webhook需要提前创建，CABundle可以写个临时值，等webhook server 启动覆盖）

自动签发证书参考项目： https://github.com/koordinator-sh/koordinator/blob/main/pkg/webhook/util/controller/webhook_controller.go#L187
