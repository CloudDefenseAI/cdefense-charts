# Helm chart Breaking Changes

 - [3.0.0](#300)
    - [Cdefensectl](#cdefensectl-support)
    - [Rulesfiles](#rulesfiles)
    - [Cdefense Images](#drop-support-for-cdefensesecuritycdefense-image)
    - [Driver Loader Init Container](#driver-loader-simplified-logic)


## 3.0.0
The new chart deploys new *k8s* resources and new configuration variables have been added to the `values.yaml` file. People upgrading the chart from `v2.x.y` have to port their configuration variables to the new `values.yaml` file used by the `v3.0.0` chart.

If you still want to use the old values, because you do not want to take advantage of the new and shiny **cdefensectl** tool then just run:
```bash=
helm upgrade cdefense cdefensesecurity/cdefense \
    --namespace=cdefense \
    --reuse-values \
    --set cdefensectl.artifact.install.enabled=false \
    --set cdefensectl.artifact.follow.enabled=false
```
This way you will upgrade Cdefense to `v0.34.0`.

**NOTE**: The new version of Cdefense itself, installed by the chart, does not introduce breaking changes. You can port your previous Cdefense configuration to the new `values.yaml` by copy-pasting it.


### Cdefensectl support

[Cdefensectl](https://https://github.com/cdefensesecurity/cdefensectl) is a new tool born to automatize operations when deploying Cdefense.

Before the `v3.0.0` of the charts *rulesfiles* and *plugins* were shipped bundled in the Cdefense docker image. It precluded the possibility to update the *rulesfiles* and *plugins* until a new version of Cdefense was released. Operators had to manually update the *rulesfiles or add new *plugins* to Cdefense. The process was cumbersome and error-prone. Operators had to create their own Cdefense docker images with the new plugins baked into it or wait for a new Cdefense release.

Starting from the `v3.0.0` chart release, we add support for **cdefensectl** in the charts. By deploying it alongside Cdefense it allows to:
- *install* artifacts of the Cdefense ecosystem (i.e plugins and rules at the moment of writing)
- *follow* those artifacts(only *rulesfile* artifacts are recommended), to keep them up-to-date with the latest releases of the Cdefensesecurity organization. This allows, for instance, to update rules detecting new vulnerabilities or security issues without the need to redeploy Cdefense.

The chart deploys *cdefensectl* using an *init container* and/or *sidecar container*. The first one is used to install artifacts and make them available to Cdefense at start-up time, the latter runs alongside Cdefense and updates the local artifacts when new updates are detected.

 Based on your deployment scenario:

1. Cdefense without *plugins* and you just want to upgrade to the new Cdefense version:
    ```bash=
    helm upgrade cdefense cdefensesecurity/cdefense \
        --namespace=cdefense \
        --reuse-values \
        --set cdefensectl.artifact.install.enabled=false \
        --set cdefensectl.artifact.follow.enabled=false
    ```
    When upgrading an existing release, *helm* uses the new chart version. Since we added new template files and changed the values schema(added new parameters) we explicitly disable the **cdefensectl** tool. By doing so, the command will reuse the existing configuration but will deploy Cdefense version `0.34.0`
    
2. Cdefense without *plugins* and you want to automatically get new *cdefense-rules* as soon as they are released:
    ```bash=
    helm upgrade cdefense cdefensesecurity/cdefense \
        --namespace=cdefense \
    ```
    Helm first applies the values coming from the new chart version, then overrides them using the values of the previous release. The outcome is a new release of Cdefense that:
    * uses the previous configuration;
    * runs Cdefense version `0.34.0`;
    * uses **cdefensectl** to install and automatically update the [*cdefense-rules*](https://github.com/cdefensesecurity/rules/);
    * checks for new updates every 6h (default value).
    

3. Cdefense with *plugins* and you want just to upgrade Cdefense:
    ```bash=
    helm upgrade cdefense cdefensesecurity/cdefense \
        --namespace=cdefense \
        --reuse-values \
        --set cdefensectl.artifact.install.enabled=false \
        --set cdefensectl.artifact.follow.enabled=false
    ```
    Very similar to scenario `1.`
4. Cdefense with plugins and you want to use **cdefensectl** to download the plugins' *rulesfiles*:
    * Save **cdefensectl** configuration to file:
        ```yaml=
        cat << EOF > ./cdefensectl-values.yaml
        ####################
        # cdefensectl config  #
        ####################
        cdefensectl:
          image:
            # -- The image pull policy.
            pullPolicy: IfNotPresent
            # -- The image registry to pull from.
            registry: docker.io
            # -- The image repository to pull from.
            repository: cdefensesecurity/cdefensectl
            #  -- Overrides the image tag whose default is the chart appVersion.
            tag: "main"
          artifact:
            # -- Runs "cdefensectl artifact install" command as an init container. It is used to install artfacts before
            # Cdefense starts. It provides them to Cdefense by using an emptyDir volume.
            install:
              enabled: true
              # -- Extra environment variables that will be pass onto cdefensectl-artifact-install init container.
              env: {}
              # -- Arguments to pass to the cdefensectl-artifact-install init container.
              args: ["--verbose"]
              # -- Resources requests and limits for the cdefensectl-artifact-install init container.
              resources: {}
              # -- Security context for the cdefensectl init container.
              securityContext: {}
            # -- Runs "cdefensectl artifact follow" command as a sidecar container. It is used to automatically check for
            # updates given a list of artifacts. If an update is found it downloads and installs it in a shared folder (emptyDir)
            # that is accessible by Cdefense. Rulesfiles are automatically detected and loaded by Cdefense once they are installed in the
            # correct folder by cdefensectl. To prevent new versions of artifacts from breaking Cdefense, the tool checks if it is compatible
            # with the running version of Cdefense before installing it.
            follow:
              enabled: true
              # -- Extra environment variables that will be pass onto cdefensectl-artifact-follow sidecar container.
              env: {}
              # -- Arguments to pass to the cdefensectl-artifact-follow sidecar container.
              args: ["--verbose"]
              # -- Resources requests and limits for the cdefensectl-artifact-follow sidecar container.
              resources: {}
              # -- Security context for the cdefensectl-artifact-follow sidecar container.
              securityContext: {}
          # -- Configuration file of the cdefensectl tool. It is saved in a configmap and mounted on the cdefensetl containers.
          config:
            # -- List of indexes that cdefensectl downloads and uses to locate and download artiafcts. For more info see:
            # https://github.com/cdefensesecurity/cdefensectl/blob/main/proposals/20220916-rules-and-plugin-distribution.md#index-file-overview
            indexes:
            - name: cdefensesecurity
              url: https://cdefensesecurity.github.io/cdefensectl/index.yaml
            # -- Configuration used by the artifact commands.
            artifact:

              # -- List of artifact types that cdefensectl will handle. If the configured refs resolves to an artifact whose type is not contained
              # in the list it will refuse to downloade and install that artifact.
              allowedTypes:
                - rulesfile
              install:
                # -- Do not resolve the depenencies for artifacts. By default is true, but for our use carse we disable it.
                resolveDeps: false
                # -- List of artifacts to be installed by the cdefensectl init container.
                refs: [k8saudit-rules:0.5]
                # -- Directory where the *rulesfiles* are saved. The path is relative to the container, which in this case is an emptyDir
                # mounted also by the Cdefense pod.
                rulesfilesDir: /rulesfiles
                # -- Same as the one above but for the artifacts.
                pluginsDir: /plugins
              follow:
                 # -- List of artifacts to be installed by the cdefensectl init container.
                refs: [k8saudit-rules:0.5]
                # -- Directory where the *rulesfiles* are saved. The path is relative to the container, which in this case is an emptyDir
                # mounted also by the Cdefense pod.
                rulesfilesDir: /rulesfiles
                # -- Same as the one above but for the artifacts.
                pluginsDir: /plugins
        EOF
        ```
    * Set `cdefensectl.artifact.install.enabled=true` to install *rulesfiles* of the loaded plugins. Configure **cdefensectl** to install the *rulesfiles* of the plugins you are loading with Cdefense. For example, if you are loading **k8saudit** plugin then you need to set `cdefensectl.config.artifact.install.refs=[k8saudit-rules:0.5]`. When Cdefense is deployed the **cdefensectl** init container will download the specified artifacts based on their tag.
    * Set `cdefensectl.artifact.follow.enabled=true` to keep updated *rulesfiles* of the loaded plugins.
    * Proceed to upgrade your Cdefense release by running:
        ```bash=
        helm upgrade cdefense cdefensesecurity/cdefense \
            --namespace=cdefense \
            --reuse-values \
            --values=./cdefensectl-values.yaml
        ```
5. Cdefense with **multiple sources** enabled (syscalls + plugins):
    1. Upgrading Cdefense to the new version:
        ```bash=
        helm upgrade cdefense cdefensesecurity/cdefense \
            --namespace=cdefense \
            --reuse-values \
            --set cdefensectl.artifact.install.enabled=false \
            --set cdefensectl.artifact.follow.enabled=false
        ```
    2. Upgrading Cdefense and leveraging **cdefensectl** for rules and plugins. Refer to point 4. for **cdefensectl** configuration.
    

### Rulesfiles
Starting from `v0.3.0`, the chart drops the bundled **rulesfiles**. The previous version was used to create a configmap containing the following **rulesfiles**:
* application_rules.yaml
* aws_cloudtrail_rules.yaml
* cdefense_rules.local.yaml
* cdefense_rules.yaml
* k8s_audit_rules.yaml

The reason why we are dropping them is pretty simple, the files are already shipped within the Cdefense image and do not apport any benefit. On the other hand, we had to manually update those files for each Cdefense release.

For users out there, do not worry, we have you covered. As said before the **rulesfiles** are already shipped inside the Cdefense image. Still, this solution has some drawbacks such as users having to wait for the next releases of Cdefense to get the latest version of those **rulesfiles**.  Or they could manually update them by using the [custom rules](https://https://github.com/cdefensesecurity/charts/tree/master/cdefense#loading-custom-rules).

We came up with a better solution and that is **cdefensectl**. Users can configure the **cdefensectl** tool to fetch and install the latest **rulesfiles** as provided by the *cdefensesecurity* organization. For more info, please check the **cdefensectl** section.

**NOTE**: if any user (wrongly) used to customize those files before deploying Cdefense please switch to using the [custom rules](https://https://github.com/cdefensesecurity/charts/tree/master/cdefense#loading-custom-rules).

### Drop support for `cdefensesecurity/cdefense` image

Starting from version `v2.0.0` of the chart the`cdefensesecurity/cdefense-no-driver` is the default image. We were still supporting the `cdefensesecurity/cdefense` image in `v2.0.0`. But in `v2.2.0` we broke the chart when using the `cdefensesecurity/cdefense` image. For more info please check out the following issue: https://github.com/cdefensesecurity/charts/issues/419

#### Driver-loader simplified logic
There is only one switch to **enable/disable** the driver-loader init container: driver.loader.enabled=true. This simplification comes as a direct consequence of dropping support for the `cdefensesecurity/cdefense` image. For more info: https://github.com/cdefensesecurity/charts/issues/418
