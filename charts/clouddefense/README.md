# CloudDefense

[CloudDefense](https://clouddefense.org) is a *Cloud Native Runtime Security* tool designed to detect anomalous activity in your applications. You can use CloudDefense to monitor runtime security of your Kubernetes applications and internal components.

## Introduction

The deployment of CloudDefense in a Kubernetes cluster is managed through a **Helm chart**. This chart manages the lifecycle of CloudDefense in a cluster by handling all the k8s objects needed by CloudDefense to be seamlessly integrated in your environment. Based on the configuration in `values.yaml` file, the chart will render and install the required k8s objects. Keep in mind that CloudDefense could be deployed in your cluster using a `daemonset` or a `deployment`. See next sections for more info.

## Attention

Before installing CloudDefense in a Kubernetes cluster, a user should check that the kernel version used in the nodes is supported by the community. Also, before reporting any issue with CloudDefense (missing kernel image, CrashLoopBackOff and similar), make sure to read [about the driver](#about-the-driver) section and adjust your setup as required.

## Adding `clouddefensesecurity` repository

Before installing the chart, add the `clouddefensesecurity` charts repository:

```bash
helm repo add clouddefensesecurity https://clouddefensesecurity.github.io/charts
helm repo update
```

## Installing the Chart

To install the chart with the release name `clouddefense` in namespace `clouddefense` run:

```bash
helm install clouddefense clouddefensesecurity/clouddefense --namespace clouddefense --create-namespace
```

After a few minutes CloudDefense instances should be running on all your nodes. The status of CloudDefense pods can be inspected through *kubectl*:
```bash
kubectl get pods -n clouddefense -o wide
```
If everything went smoothly, you should observe an output similar to the following, indicating that all CloudDefense instances are up and running in you cluster:

```bash
NAME          READY   STATUS    RESTARTS   AGE     IP          NODE            NOMINATED NODE   READINESS GATES
clouddefense-57w7q   1/1     Running   0          3m12s   10.244.0.1   control-plane   <none>           <none>
clouddefense-h4596   1/1     Running   0          3m12s   10.244.1.2   worker-node-1   <none>           <none>
clouddefense-kb55h   1/1     Running   0          3m12s   10.244.2.3   worker-node-2   <none>           <none>
```
The cluster in our example has three nodes, one *control-plane* node and two *worker* nodes. The default configuration in `values.yaml` of our helm chart deploys CloudDefense using a `daemonset`. That's the reason why we have one CloudDefense pod in each node. 
> **Tip**: List CloudDefense release using `helm list -n clouddefense`, a release is a name used to track a specific deployment

### CloudDefense, Event Sources and Kubernetes
Starting from CloudDefense 0.31.0 the [new plugin system](https://clouddefense.org/docs/plugins/) is stable and production ready. The **plugin system** can be seen as the next step in the evolution of CloudDefense. Historically, CloudDefense monitored system events from the **kernel** trying to detect malicious behaviors on Linux systems. It also had the capability to process k8s Audit Logs to detect suspicious activities in Kubernetes clusters. Since CloudDefense 0.32.0 all the related code to the k8s Audit Logs in CloudDefense was removed and ported in a [plugin](https://github.com/clouddefensesecurity/plugins/tree/master/plugins/k8saudit). At the time being CloudDefense supports different event sources coming from **plugins** or **drivers** (system events). 

Note that **a CloudDefense instance can handle multiple event sources in parallel**. you can deploy CloudDefense leveraging **drivers** for syscalls events and at the same time loading **plugins**. A step by step guide on how to deploy CloudDefense with multiple sources can be found [here](https://clouddefense.org/docs/getting-started/third-party/learning/#clouddefense-with-multiple-sources).

#### About Drivers

CloudDefense needs a **driver** to analyze the system workload and pass security events to userspace. The supported drivers are:

* [Kernel module](https://clouddefense.org/docs/event-sources/drivers/#kernel-module) 
* [eBPF probe](https://clouddefense.org/docs/event-sources/drivers/#ebpf-probe)
* [Modern eBPF probe](https://clouddefense.org/docs/event-sources/drivers/#modern-ebpf-probe-experimental) (starting from CloudDefense `0.34.0`)

The driver should be installed on the node where CloudDefense is running. The _kernel module_ (default option) and the _eBPF probe_ are installed on the node through an *init container* (i.e. `clouddefense-driver-loader`) that tries to build drivers to download a prebuilt driver or build it on-the-fly or as a fallback. The _Modern eBPF probe_ doesn't require an init container because it is shipped directly into the CloudDefense binary. However, the _Modern eBPF probe_ requires a kernel version equal to or greater than `5.8`.

##### Pre-built drivers

The [kernel-crawler](https://github.com/clouddefensesecurity/kernel-crawler) automatically discovers kernel versions and flavors. At the time being, it runs weekly. We have a site where users can check for the discovered kernel flavors and versions, [example for Amazon Linux 2](https://clouddefensesecurity.github.io/kernel-crawler/?arch=x86_64&target=AmazonLinux2).

The discovery of a kernel version by the [kernel-crawler](https://clouddefensesecurity.github.io/kernel-crawler/) does not imply that pre-built kernel modules and bpf probes are available. That is because once kernel-crawler has discovered new kernels versions, the drivers need to be built by jobs running on our [Driver Build Grid infra](https://github.com/clouddefensesecurity/test-infra#dbg). Please keep in mind that the building process is based on best effort. Users can check the existence of prebuilt modules at the following [link](https://download.clouddefense.org/driver/site/index.html?lib=3.0.1%2Bdriver&target=all&arch=all&kind=all).

##### Building the driver on the fly (fallback)

If a prebuilt driver is not available for your distribution/kernel, users can build the modules by them self or install the kernel headers on the nodes, and the init container (clouddefense-driver-loader) will try and build the module on the fly.

CloudDefense needs **kernel headers** installed on the host as a prerequisite to build the driver on the fly correctly. You can find instructions for installing the kernel headers for your system under the [Install section](https://clouddefense.org/docs/getting-started/installation/) of the official documentation.

#### About Plugins
[Plugins](https://clouddefense.org/docs/plugins/) are used to extend CloudDefense to support new **data sources**. The current **plugin framework** supports *plugins* with the following *capabilities*:

* Event sourcing capability;
* Field extraction capability;

Plugin capabilities are *composable*, we can have a single plugin with both capabilities. Or on the other hand, we can load two different plugins each with its capability, one plugin as a source of events and another as an extractor. A good example of this is the [Kubernetes Audit Events](https://github.com/clouddefensesecurity/plugins/tree/master/plugins/k8saudit) and the [CloudDefensesecurity Json](https://github.com/clouddefensesecurity/plugins/tree/master/plugins/json) *plugins*. By deploying them both we have support for the **K8s Audit Logs** in CloudDefense



Note that **the driver is not required when using plugins**. 

#### About gVisor
gVisor is an application kernel, written in Go, that implements a substantial portion of the Linux system call interface. It provides an additional layer of isolation between running applications and the host operating system. For more information please consult the [official docs](https://gvisor.dev/docs/). In version `0.32.1`, CloudDefense first introduced support for gVisor by leveraging the stream of system call information coming from gVisor.
CloudDefense requires the version of [runsc](https://gvisor.dev/docs/user_guide/install/) to be equal to or above `20220704.0`. The following snippet shows the gVisor configuration variables found in `values.yaml`:
```yaml
gvisor:
  enabled: true
  runsc:
    path: /home/containerd/usr/local/sbin
    root: /run/containerd/runsc
    config: /run/containerd/runsc/config.toml
```
CloudDefense uses the [runsc](https://gvisor.dev/docs/user_guide/install/) binary to interact with sandboxed containers. The following variables need to be set:
* `runsc.path`: absolute path of the `runsc` binary in the k8s nodes;
* `runsc.root`: absolute path of the root directory of the `runsc` container runtime. It is of vital importance for CloudDefense since `runsc` stores there the information of the workloads handled by it;
* `runsc.config`: absolute path of the `runsc` configuration file, used by CloudDefense to set its configuration and make aware `gVisor` of its presence.

If you want to know more how CloudDefense uses those configuration paths please have a look at the `clouddefense.gvisor.initContainer` helper in [helpers.tpl](./templates/_helpers.tpl).
A preset `values.yaml` file [values-gvisor-gke.yaml](./values-gvisor-gke.yaml) is provided and can be used as it is to deploy CloudDefense with gVisor support in a [GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/sandbox-pods) cluster. It is also a good starting point for custom deployments.

##### Example: running CloudDefense on GKE, with or without gVisor-enabled pods

If you use GKE with k8s version at least `1.24.4-gke.1800` or `1.25.0-gke.200` with gVisor sandboxed pods, you can install a CloudDefense instance to monitor them with, e.g.:

```
helm install clouddefense-gvisor clouddefensesecurity/clouddefense -f https://raw.githubusercontent.com/clouddefensesecurity/charts/master/clouddefense/values-gvisor-gke.yaml --namespace clouddefense-gvisor --create-namespace
```

Note that the instance of CloudDefense above will only monitor gVisor sandboxed workloads on gVisor-enabled node pools. If you also need to monitor regular workloads on regular node pools you can use the eBPF driver as usual:

```
helm install clouddefense clouddefensesecurity/clouddefense --set driver.kind=ebpf --namespace clouddefense --create-namespace
```

The two instances of CloudDefense will operate independently and can be installed, uninstalled or configured as needed. If you were already monitoring your regular node pools with eBPF you don't need to reinstall it.

##### CloudDefense+gVisor additional resources
An exhaustive blog post about CloudDefense and gVisor can be found on the [CloudDefense blog](https://clouddefense.org/blog/intro-gvisor-clouddefense/).
If you need help on how to set gVisor in your environment please have a look at the [gVisor official docs](https://gvisor.dev/docs/user_guide/quick_start/kubernetes/)

### About CloudDefense Artifacts
Historically **rules files** and **plugins** used to be shipped inside the CloudDefense docker image and/or inside the chart. Starting from version `v0.3.0` of the chart, the [**clouddefensectl tool**](https://github.com/clouddefensesecurity/clouddefensectl) can be used to install/update **rules files** and **plugins**. When referring to such objects we will use the term **artifact**.  For more info please check out the following [proposal](https://github.com/clouddefensesecurity/clouddefensectl/blob/main/proposals/20220916-rules-and-plugin-distribution.md).

The default configuration of the chart for new installations is to use the **clouddefensectl** tool to handle **artifacts**. The chart will deploy two new containers along the CloudDefense one:
* `clouddefensectl-artifact-install` an init container that makes sure to install the configured **artifacts** before the CloudDefense container starts;
* `clouddefensectl-artifact-follow` a sidecar container that periodically checks for new artifacts (currently only *clouddefense-rules*) and downloads them;

For more info on how to enable/disable and configure the **clouddefensectl** tool checkout the config values [here](./generated/helm-values.md) and the [upgrading notes](./BREAKING-CHANGES.md#300)
### Deploying CloudDefense in Kubernetes
After the clarification of the different [**event sources**](#clouddefense-event-sources-and-kubernetes) and how they are consumed by CloudDefense using the **drivers** and the **plugins**, now let us discuss how CloudDefense is deployed in Kubernetes.

The chart deploys CloudDefense using a `daemonset` or a `deployment` depending on the **event sources**.

#### Daemonset
When using the [drivers](#about-the-driver), CloudDefense is deployed as `daemonset`. By using a `daemonset`, k8s assures that a CloudDefense instance will be running in each of our nodes even when we add new nodes to our cluster. So it is the perfect match when we need to monitor all the nodes in our cluster.

**Kernel module**

To run CloudDefense with the [kernel module](https://clouddefense.org/docs/event-sources/drivers/#kernel-module) you can use the default values of the helm chart:

```yaml
driver:
  enabled: true
  kind: module
```

**eBPF probe**

To run CloudDefense with the [eBPF probe](https://clouddefense.org/docs/event-sources/drivers/#ebpf-probe) you just need to set `driver.kind=ebpf` as shown in the following snippet:

```yaml
driver:
  enabled: true
  kind: ebpf
```

There are other configurations related to the eBPF probe, for more info please check the `values.yaml` file. After you have made your changes to the configuration file you just need to run:

```bash
helm install clouddefense clouddefensesecurity/clouddefense --namespace "your-custom-name-space" --create-namespace
```

**modern eBPF probe**

To run CloudDefense with the [modern eBPF probe](https://clouddefense.org/docs/event-sources/drivers/#modern-ebpf-probe-experimental) you just need to set `driver.kind=modern-bpf` as shown in the following snippet:

```yaml
driver:
  enabled: true
  kind: modern-bpf
```

#### Deployment
In the scenario when CloudDefense is used with **plugins** as data sources, then the best option is to deploy it as a k8s `deployment`. **Plugins** could be of two types, the ones that follow the **push model** or the **pull model**. A plugin that adopts the firs model expects to receive the data from a remote source in a given endpoint. They just expose and endpoint and wait for data to be posted, for example [Kubernetes Audit Events](https://github.com/clouddefensesecurity/plugins/tree/master/plugins/k8saudit) expects the data to be sent by the *k8s api server* when configured in such way. On the other hand other plugins that abide by the **pull model** retrieves the data from a given remote service. 
The following points explain why a k8s `deployment` is suitable when deploying CloudDefense with plugins:

* need to be reachable when ingesting logs directly from remote services;
* need only one active replica, otherwise events will be sent/received to/from different CloudDefense instances;


## Uninstalling the Chart

To uninstall a CloudDefense release from your Kubernetes cluster always you helm. It will take care to remove all components deployed by the chart and clean up your environment. The following command will remove a release called `clouddefense` in namespace `clouddefense`;

```bash
helm uninstall clouddefense --namespace clouddefense
```

## Showing logs generated by CloudDefense container
There are many reasons why we would have to inspect the messages emitted by the CloudDefense container. When deployed in Kubernetes the CloudDefense logs can be inspected through:
```bash
kubectl logs -n clouddefense clouddefense-pod-name
```
where `clouddefense-pods-name` is the name of the CloudDefense pod running in your cluster. 
The command described above will just display the logs emitted by clouddefense until the moment you run the command. The `-f` flag comes handy when we are doing live testing or debugging and we want to have the CloudDefense logs as soon as they are emitted. The following command:
```bash
kubectl logs -f -n clouddefense clouddefense-pod-name
```
The `-f (--follow)` flag follows the logs and live stream them to your terminal and it is really useful when you are debugging a new rule and want to make sure that the rule is triggered when some actions are performed in the system.

If we need to access logs of a previous CloudDefense run we do that by adding the `-p (--previous)` flag:
```bash
kubectl logs -p -n clouddefense clouddefense-pod-name
```
A scenario when we need the `-p (--previous)` flag is when we have a restart of a CloudDefense pod and want to check what went wrong.

### Enabling real time logs
By default in CloudDefense the output is buffered. When live streaming logs we will notice delays between the logs output (rules triggering) and the event happening. 
In order to enable the logs to be emitted without delays you need to set `.Values.tty=true` in `values.yaml` file.
## Loading custom rules

CloudDefense ships with a nice default ruleset. It is a good starting point but sooner or later, we are going to need to add custom rules which fit our needs.

So the question is: How can we load custom rules in our CloudDefense deployment?

We are going to create a file that contains custom rules so that we can keep it in a Git repository.

```bash
cat custom-rules.yaml
```

And the file looks like this one:

```yaml
customRules:
  rules-traefik.yaml: |-
    - macro: traefik_consider_syscalls
      condition: (evt.num < 0)

    - macro: app_traefik
      condition: container and container.image startswith "traefik"

    # Restricting listening ports to selected set

    - list: traefik_allowed_inbound_ports_tcp
      items: [443, 80, 8080]

    - rule: Unexpected inbound tcp connection traefik
      desc: Detect inbound traffic to traefik using tcp on a port outside of expected set
      condition: inbound and evt.rawres >= 0 and not fd.sport in (traefik_allowed_inbound_ports_tcp) and app_traefik
      output: Inbound network connection to traefik on unexpected port (command=%proc.cmdline pid=%proc.pid connection=%fd.name sport=%fd.sport user=%user.name %container.info image=%container.image)
      priority: NOTICE

    # Restricting spawned processes to selected set

    - list: traefik_allowed_processes
      items: ["traefik"]

    - rule: Unexpected spawned process traefik
      desc: Detect a process started in a traefik container outside of an expected set
      condition: spawned_process and not proc.name in (traefik_allowed_processes) and app_traefik
      output: Unexpected process spawned in traefik container (command=%proc.cmdline pid=%proc.pid user=%user.name %container.info image=%container.image)
      priority: NOTICE
```

So next step is to use the custom-rules.yaml file for installing the CloudDefense Helm chart.

```bash
helm install clouddefense -f custom-rules.yaml clouddefensesecurity/clouddefense
```

And we will see in our logs something like:

```bash
Tue Jun  5 15:08:57 2018: Loading rules from file /etc/clouddefense/rules.d/rules-traefik.yaml:
```

And this means that our CloudDefense installation has loaded the rules and is ready to help us.

## Kubernetes Audit Log

The Kubernetes Audit Log is now supported via the built-in [k8saudit](https://github.com/clouddefensesecurity/plugins/tree/master/plugins/k8saudit) plugin. It is entirely up to you to set up the [webhook backend](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/#webhook-backend) of the Kubernetes API server to forward the Audit Log event to the CloudDefense listening port.

The following snippet shows how to deploy CloudDefense with the [k8saudit](https://github.com/clouddefensesecurity/plugins/tree/master/plugins/k8saudit) plugin:
```yaml
# -- Disable the drivers since we want to deplouy only the k8saudit plugin.
driver:
  enabled: false

# -- Disable the collectors, no syscall events to enrich with metadata.
collectors:
  enabled: false

# -- Deploy CloudDefense as a deployment. One instance of CloudDefense is enough. Anyway the number of replicas is configurabale.
controller:
  kind: deployment
  deployment:
    # -- Number of replicas when installing CloudDefense using a deployment. Change it if you really know what you are doing.
    # For more info check the section on Plugins in the README.md file.
    replicas: 1


clouddefensectl:
  artifact:
    install:
      # -- Enable the clouddefensectl tool as init container. It installs artifacts in the config.artifact.install.refs list.
      enabled: true
    follow:
      # -- Disable the sidecar container. We do not support it yet for plugins. It is used only for rules feed such as CloudDefense rules.
      enabled: false
  config:
    artifact:
      install:
        # -- List of artifacts to be installed by the clouddefensectl init container.
        # Same plugins we are loading in CloudDefense. See "load_plugins" section.
        refs: [k8saudit:0, json:0]

services:
  - name: k8saudit-webhook
    type: NodePort
    ports:
      - port: 9765 # See plugin open_params
        nodePort: 30007
        protocol: TCP

clouddefense:
  rules_file:
    - /etc/clouddefense/k8s_audit_rules.yaml
    - /etc/clouddefense/rules.d
  plugins:
    - name: k8saudit
      library_path: libk8saudit.so
      init_config:
        ""
        # maxEventBytes: 1048576
        # sslCertificate: /etc/clouddefense/clouddefense.pem
      open_params: "http://:9765/k8s-audit"
    - name: json
      library_path: libjson.so
      init_config: ""
  # Plugins that CloudDefense will load. Note: the same plugins are installed by the clouddefensectl-artifact-install init container.
  load_plugins: [k8saudit, json]

```
Here is the explanation of the above configuration:
* disable the drivers by setting `driver.enabled=false`;
* disable the collectors by setting `collectors.enabled=false`;
* deploy the CloudDefense using a k8s *deploment* by setting `controller.kind=deployment`;
* makes our CloudDefense instance reachable by the `k8s api-server` by configuring a service for it in `services`;
* enable the `clouddefensectl-artifact-install` init container;
* configure `clouddefensectl-artifact-install` to install the required plugins;
* disable the `clouddefensectl-artifact-follow` sidecar container;
* load the correct ruleset for our plugin in `clouddefense.rulesFile`;
* configure the plugins to be loaded, in this case, the `k8saudit` and `json`;
* and finally we add our plugins in the `load_plugins` to be loaded by CloudDefense.

The configuration can be found in the `values-k8saudit.yaml` file ready to be used:


```bash
#make sure the clouddefense namespace exists
helm install clouddefense clouddefensesecurity/clouddefense --namespace clouddefense -f ./values-k8saudit.yaml --create-namespace
```
After a few minutes a CloudDefense instance should be running on your cluster. The status of CloudDefense pod can be inspected through *kubectl*:
```bash
kubectl get pods -n clouddefense -o wide
```
If everything went smoothly, you should observe an output similar to the following, indicating that the CloudDefense instance is up and running:

```bash
NAME                     READY   STATUS    RESTARTS   AGE    IP           NODE            NOMINATED NODE   READINESS GATES
clouddefense-64484d9579-qckms   1/1     Running   0          101s   10.244.2.2   worker-node-2   <none>           <none>
```

Furthermore you can check that CloudDefense logs through *kubectl logs*

```bash
kubectl logs -n clouddefense clouddefense-64484d9579-qckms
```
In the logs you should have something similar to the following, indcating that CloudDefense has loaded the required plugins:
```bash
Fri Jul  8 16:07:24 2022: CloudDefense version 0.32.0 (driver version 39ae7d40496793cf3d3e7890c9bbdc202263836b)
Fri Jul  8 16:07:24 2022: CloudDefense initialized with configuration file /etc/clouddefense/falco.yaml
Fri Jul  8 16:07:24 2022: Loading plugin (k8saudit) from file /usr/share/clouddefense/plugins/libk8saudit.so
Fri Jul  8 16:07:24 2022: Loading plugin (json) from file /usr/share/clouddefense/plugins/libjson.so
Fri Jul  8 16:07:24 2022: Loading rules from file /etc/clouddefense/k8s_audit_rules.yaml:
Fri Jul  8 16:07:24 2022: Starting internal webserver, listening on port 8765
```
*Note that the support for the dynamic backend (also known as the `AuditSink` object) has been deprecated from Kubernetes and removed from this chart.*

### Manual setup with NodePort on kOps

Using `kops edit cluster`, ensure these options are present, then run `kops update cluster` and `kops rolling-update cluster`:
```yaml
spec:
  kubeAPIServer:
    auditLogMaxBackups: 1
    auditLogMaxSize: 10
    auditLogPath: /var/log/k8s-audit.log
    auditPolicyFile: /srv/kubernetes/assets/audit-policy.yaml
    auditWebhookBatchMaxWait: 5s
    auditWebhookConfigFile: /srv/kubernetes/assets/webhook-config.yaml
  fileAssets:
  - content: |
      # content of the webserver CA certificate
      # remove this fileAsset and certificate-authority from webhook-config if using http
    name: audit-ca.pem
    roles:
    - Master
  - content: |
      apiVersion: v1
      kind: Config
      clusters:
      - name: clouddefense
        cluster:
          # remove 'certificate-authority' when using 'http'
          certificate-authority: /srv/kubernetes/assets/audit-ca.pem
          server: https://localhost:32765/k8s-audit
      contexts:
      - context:
          cluster: clouddefense
          user: ""
        name: default-context
      current-context: default-context
      preferences: {}
      users: []
    name: webhook-config.yaml
    roles:
    - Master
  - content: |
      # ... paste audit-policy.yaml here ...
      # https://raw.githubusercontent.com/clouddefensesecurity/evolution/master/examples/k8s_audit_config/audit-policy.yaml
    name: audit-policy.yaml
    roles:
    - Master
```
## Enabling gRPC

The CloudDefense gRPC server and the CloudDefense gRPC Outputs APIs are not enabled by default.
Moreover, CloudDefense supports running a gRPC server with two main binding types:
- Over a local **Unix socket** with no authentication
- Over the **network** with mandatory mutual TLS authentication (mTLS)

> **Tip**: Once gRPC is enabled, you can deploy [clouddefense-exporter](https://github.com/clouddefensesecurity/clouddefense-exporter) to export metrics to Prometheus.

### gRPC over unix socket (default)

The preferred way to use the gRPC is over a Unix socket.

To install CloudDefense with gRPC enabled over a **unix socket**, you have to:

```shell
helm install clouddefense \
  --set clouddefense.grpc.enabled=true \
  --set clouddefense.grpc_output.enabled=true \
  clouddefensesecurity/clouddefense
```

### gRPC over network

The gRPC server over the network can only be used with mutual authentication between the clients and the server using TLS certificates.
How to generate the certificates is [documented here](https://clouddefense.org/docs/grpc/#generate-valid-ca).

To install CloudDefense with gRPC enabled over the **network**, you have to:

```shell
helm install clouddefense \
  --set clouddefense.grpc.enabled=true \
  --set clouddefense.grpc_output.enabled=true \
  --set clouddefense.grpc.unixSocketPath="" \
  --set-file certs.server.key=/path/to/server.key \
  --set-file certs.server.crt=/path/to/server.crt \
  --set-file certs.ca.crt=/path/to/ca.crt \
  clouddefensesecurity/clouddefense
```

## Deploy clouddefensecollector with CloudDefense

[`clouddefensecollector`](https://github.com/clouddefensesecurity/clouddefensecollector) can be installed with `CloudDefense` by setting `--set clouddefensecollector.enabled=true`. This setting automatically configures all options of `CloudDefense` for working with `clouddefensecollector`.
All values for the configuration of `clouddefensecollector` are available by prefixing them with `clouddefensecollector.`. The full list of available values is [here](https://github.com/clouddefensesecurity/charts/tree/master/clouddefensecollector#configuration).
For example, to enable the deployment of [`clouddefensecollector-UI`](https://github.com/clouddefensesecurity/clouddefensecollector-ui), add `--set clouddefensecollector.enabled=true --set clouddefensecollector.webui.enabled=true`.

If you use a Proxy in your cluster, the requests between `CloudDefense` and `clouddefensecollector` might be captured, use the full FQDN of `clouddefensecollector` by using `--set clouddefensecollector.fullfqdn=true` to avoid that.

## Configuration

All the configurable parameters of the clouddefense chart and their default values can be found [here](./generated/helm-values.md).
