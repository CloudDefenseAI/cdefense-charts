# Helm chart Breaking Changes

 - [3.0.0](#300)
    - [clouddefensectl](#clouddefensectl-support)
    - [Rulesfiles](#rulesfiles)
    - [CloudDefense Images](#drop-support-for-clouddefensesecurityclouddefense-image)
    - [Driver Loader Init Container](#driver-loader-simplified-logic)


## 3.0.0
The new chart deploys new *k8s* resources and new configuration variables have been added to the `values.yaml` file. People upgrading the chart from `v2.x.y` have to port their configuration variables to the new `values.yaml` file used by the `v3.0.0` chart.

If you still want to use the old values, because you do not want to take advantage of the new and shiny **clouddefensectl** tool then just run:
```bash=
helm upgrade clouddefense clouddefensesecurity/clouddefense \
    --namespace=clouddefense \
    --reuse-values \
    --set clouddefensectl.artifact.install.enabled=false \
    --set clouddefensectl.artifact.follow.enabled=false
```
This way you will upgrade CloudDefense to `v0.34.0`.

**NOTE**: The new version of CloudDefense itself, installed by the chart, does not introduce breaking changes. You can port your previous CloudDefense configuration to the new `values.yaml` by copy-pasting it.


### clouddefensectl support

[clouddefensectl](https://https://github.com/clouddefensesecurity/clouddefensectl) is a new tool born to automatize operations when deploying CloudDefense.

Before the `v3.0.0` of the charts *rulesfiles* and *plugins* were shipped bundled in the CloudDefense docker image. It precluded the possibility to update the *rulesfiles* and *plugins* until a new version of CloudDefense was released. Operators had to manually update the *rulesfiles or add new *plugins* to CloudDefense. The process was cumbersome and error-prone. Operators had to create their own CloudDefense docker images with the new plugins baked into it or wait for a new CloudDefense release.

Starting from the `v3.0.0` chart release, we add support for **clouddefensectl** in the charts. By deploying it alongside CloudDefense it allows to:
- *install* artifacts of the CloudDefense ecosystem (i.e plugins and rules at the moment of writing)
- *follow* those artifacts(only *rulesfile* artifacts are recommended), to keep them up-to-date with the latest releases of the CloudDefensesecurity organization. This allows, for instance, to update rules detecting new vulnerabilities or security issues without the need to redeploy CloudDefense.

The chart deploys *clouddefensectl* using an *init container* and/or *sidecar container*. The first one is used to install artifacts and make them available to CloudDefense at start-up time, the latter runs alongside CloudDefense and updates the local artifacts when new updates are detected.

 Based on your deployment scenario:

1. CloudDefense without *plugins* and you just want to upgrade to the new CloudDefense version:
    ```bash=
    helm upgrade clouddefense clouddefensesecurity/clouddefense \
        --namespace=clouddefense \
        --reuse-values \
        --set clouddefensectl.artifact.install.enabled=false \
        --set clouddefensectl.artifact.follow.enabled=false
    ```
    When upgrading an existing release, *helm* uses the new chart version. Since we added new template files and changed the values schema(added new parameters) we explicitly disable the **clouddefensectl** tool. By doing so, the command will reuse the existing configuration but will deploy CloudDefense version `0.34.0`
    
2. CloudDefense without *plugins* and you want to automatically get new *clouddefense-rules* as soon as they are released:
    ```bash=
    helm upgrade clouddefense clouddefensesecurity/clouddefense \
        --namespace=clouddefense \
    ```
    Helm first applies the values coming from the new chart version, then overrides them using the values of the previous release. The outcome is a new release of CloudDefense that:
    * uses the previous configuration;
    * runs CloudDefense version `0.34.0`;
    * uses **clouddefensectl** to install and automatically update the [*clouddefense-rules*](https://github.com/clouddefensesecurity/rules/);
    * checks for new updates every 6h (default value).
    

3. CloudDefense with *plugins* and you want just to upgrade CloudDefense:
    ```bash=
    helm upgrade clouddefense clouddefensesecurity/clouddefense \
        --namespace=clouddefense \
        --reuse-values \
        --set clouddefensectl.artifact.install.enabled=false \
        --set clouddefensectl.artifact.follow.enabled=false
    ```
    Very similar to scenario `1.`
4. CloudDefense with plugins and you want to use **clouddefensectl** to download the plugins' *rulesfiles*:
    * Save **clouddefensectl** configuration to file:
        ```yaml=
        cat << EOF > ./clouddefensectl-values.yaml
        ####################
        # clouddefensectl config  #
        ####################
        clouddefensectl:
          image:
            # -- The image pull policy.
            pullPolicy: IfNotPresent
            # -- The image registry to pull from.
            registry: docker.io
            # -- The image repository to pull from.
            repository: clouddefensesecurity/clouddefensectl
            #  -- Overrides the image tag whose default is the chart appVersion.
            tag: "main"
          artifact:
            # -- Runs "clouddefensectl artifact install" command as an init container. It is used to install artfacts before
            # CloudDefense starts. It provides them to CloudDefense by using an emptyDir volume.
            install:
              enabled: true
              # -- Extra environment variables that will be pass onto clouddefensectl-artifact-install init container.
              env: {}
              # -- Arguments to pass to the clouddefensectl-artifact-install init container.
              args: ["--verbose"]
              # -- Resources requests and limits for the clouddefensectl-artifact-install init container.
              resources: {}
              # -- Security context for the clouddefensectl init container.
              securityContext: {}
            # -- Runs "clouddefensectl artifact follow" command as a sidecar container. It is used to automatically check for
            # updates given a list of artifacts. If an update is found it downloads and installs it in a shared folder (emptyDir)
            # that is accessible by CloudDefense. Rulesfiles are automatically detected and loaded by CloudDefense once they are installed in the
            # correct folder by clouddefensectl. To prevent new versions of artifacts from breaking CloudDefense, the tool checks if it is compatible
            # with the running version of CloudDefense before installing it.
            follow:
              enabled: true
              # -- Extra environment variables that will be pass onto clouddefensectl-artifact-follow sidecar container.
              env: {}
              # -- Arguments to pass to the clouddefensectl-artifact-follow sidecar container.
              args: ["--verbose"]
              # -- Resources requests and limits for the clouddefensectl-artifact-follow sidecar container.
              resources: {}
              # -- Security context for the clouddefensectl-artifact-follow sidecar container.
              securityContext: {}
          # -- Configuration file of the clouddefensectl tool. It is saved in a configmap and mounted on the clouddefensetl containers.
          config:
            # -- List of indexes that clouddefensectl downloads and uses to locate and download artiafcts. For more info see:
            # https://github.com/clouddefensesecurity/clouddefensectl/blob/main/proposals/20220916-rules-and-plugin-distribution.md#index-file-overview
            indexes:
            - name: clouddefensesecurity
              url: https://clouddefensesecurity.github.io/clouddefensectl/index.yaml
            # -- Configuration used by the artifact commands.
            artifact:

              # -- List of artifact types that clouddefensectl will handle. If the configured refs resolves to an artifact whose type is not contained
              # in the list it will refuse to downloade and install that artifact.
              allowedTypes:
                - rulesfile
              install:
                # -- Do not resolve the depenencies for artifacts. By default is true, but for our use carse we disable it.
                resolveDeps: false
                # -- List of artifacts to be installed by the clouddefensectl init container.
                refs: [k8saudit-rules:0.5]
                # -- Directory where the *rulesfiles* are saved. The path is relative to the container, which in this case is an emptyDir
                # mounted also by the CloudDefense pod.
                rulesfilesDir: /rulesfiles
                # -- Same as the one above but for the artifacts.
                pluginsDir: /plugins
              follow:
                 # -- List of artifacts to be installed by the clouddefensectl init container.
                refs: [k8saudit-rules:0.5]
                # -- Directory where the *rulesfiles* are saved. The path is relative to the container, which in this case is an emptyDir
                # mounted also by the CloudDefense pod.
                rulesfilesDir: /rulesfiles
                # -- Same as the one above but for the artifacts.
                pluginsDir: /plugins
        EOF
        ```
    * Set `clouddefensectl.artifact.install.enabled=true` to install *rulesfiles* of the loaded plugins. Configure **clouddefensectl** to install the *rulesfiles* of the plugins you are loading with CloudDefense. For example, if you are loading **k8saudit** plugin then you need to set `clouddefensectl.config.artifact.install.refs=[k8saudit-rules:0.5]`. When CloudDefense is deployed the **clouddefensectl** init container will download the specified artifacts based on their tag.
    * Set `clouddefensectl.artifact.follow.enabled=true` to keep updated *rulesfiles* of the loaded plugins.
    * Proceed to upgrade your CloudDefense release by running:
        ```bash=
        helm upgrade clouddefense clouddefensesecurity/clouddefense \
            --namespace=clouddefense \
            --reuse-values \
            --values=./clouddefensectl-values.yaml
        ```
5. CloudDefense with **multiple sources** enabled (syscalls + plugins):
    1. Upgrading CloudDefense to the new version:
        ```bash=
        helm upgrade clouddefense clouddefensesecurity/clouddefense \
            --namespace=clouddefense \
            --reuse-values \
            --set clouddefensectl.artifact.install.enabled=false \
            --set clouddefensectl.artifact.follow.enabled=false
        ```
    2. Upgrading CloudDefense and leveraging **clouddefensectl** for rules and plugins. Refer to point 4. for **clouddefensectl** configuration.
    

### Rulesfiles
Starting from `v0.3.0`, the chart drops the bundled **rulesfiles**. The previous version was used to create a configmap containing the following **rulesfiles**:
* application_rules.yaml
* aws_cloudtrail_rules.yaml
* clouddefense_rules.local.yaml
* clouddefense_rules.yaml
* k8s_audit_rules.yaml

The reason why we are dropping them is pretty simple, the files are already shipped within the CloudDefense image and do not apport any benefit. On the other hand, we had to manually update those files for each CloudDefense release.

For users out there, do not worry, we have you covered. As said before the **rulesfiles** are already shipped inside the CloudDefense image. Still, this solution has some drawbacks such as users having to wait for the next releases of CloudDefense to get the latest version of those **rulesfiles**.  Or they could manually update them by using the [custom rules](https://https://github.com/clouddefensesecurity/charts/tree/master/clouddefense#loading-custom-rules).

We came up with a better solution and that is **clouddefensectl**. Users can configure the **clouddefensectl** tool to fetch and install the latest **rulesfiles** as provided by the *clouddefensesecurity* organization. For more info, please check the **clouddefensectl** section.

**NOTE**: if any user (wrongly) used to customize those files before deploying CloudDefense please switch to using the [custom rules](https://https://github.com/clouddefensesecurity/charts/tree/master/clouddefense#loading-custom-rules).

### Drop support for `clouddefensesecurity/clouddefense` image

Starting from version `v2.0.0` of the chart the`clouddefensesecurity/clouddefense-no-driver` is the default image. We were still supporting the `clouddefensesecurity/clouddefense` image in `v2.0.0`. But in `v2.2.0` we broke the chart when using the `clouddefensesecurity/clouddefense` image. For more info please check out the following issue: https://github.com/clouddefensesecurity/charts/issues/419

#### Driver-loader simplified logic
There is only one switch to **enable/disable** the driver-loader init container: driver.loader.enabled=true. This simplification comes as a direct consequence of dropping support for the `clouddefensesecurity/clouddefense` image. For more info: https://github.com/clouddefensesecurity/charts/issues/418
