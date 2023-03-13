{{/*
Expand the name of the chart.
*/}}
{{- define "clouddefense.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "clouddefense.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "clouddefense.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Allow the release namespace to be overridden
*/}}
{{- define "clouddefense.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "clouddefense.labels" -}}
helm.sh/chart: {{ include "clouddefense.chart" . }}
{{ include "clouddefense.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "clouddefense.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clouddefense.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Renders a value that contains template.
Usage:
{{ include "clouddefense.renderTemplate" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "clouddefense.renderTemplate" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "clouddefense.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "clouddefense.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper CloudDefense image name
*/}}
{{- define "clouddefense.image" -}}
{{- with .Values.image.registry -}}
    {{- . }}/
{{- end -}}
{{- .Values.image.repository }}:
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{/*
Return the proper CloudDefense driver loader image name
*/}}
{{- define "clouddefense.driverLoader.image" -}}
{{- with .Values.driver.loader.initContainer.image.registry -}}
    {{- . }}/
{{- end -}}
{{- .Values.driver.loader.initContainer.image.repository }}:
{{- .Values.driver.loader.initContainer.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{/*
Return the proper clouddefensectl image name
*/}}
{{- define "clouddefensectl.image" -}}
{{ printf "%s/%s:%s" .Values.clouddefensectl.image.registry .Values.clouddefensectl.image.repository .Values.clouddefensectl.image.tag }}
{{- end -}}

{{/*
Extract the unixSocket's directory path
*/}}
{{- define "clouddefense.unixSocketDir" -}}
{{- if and .Values.clouddefense.grpc.enabled .Values.clouddefense.grpc.bind_address (hasPrefix "unix://" .Values.clouddefense.grpc.bind_address) -}}
{{- .Values.clouddefense.grpc.bind_address | trimPrefix "unix://" | dir -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for rbac.
*/}}
{{- define "rbac.apiVersion" -}}
{{- if .Capabilities.APIVersions.Has "rbac.authorization.k8s.io/v1" }}
{{- print "rbac.authorization.k8s.io/v1" -}}
{{- else -}}
{{- print "rbac.authorization.k8s.io/v1beta1" -}}
{{- end -}}
{{- end -}}

{{/*
 Build http url for clouddefensecollector.
*/}}
{{- define "clouddefensecollector.url" -}}
{{- if not .Values.clouddefense.http_output.url -}}
    {{- $clouddefenseName := include "clouddefense.fullname" . -}}
    {{- $listenPort := .Values.clouddefensecollector.listenport | default "2801" -}}
    {{- if .Values.clouddefensecollector.fullfqdn -}}
       {{- printf "http://%s-clouddefensecollector.%s.svc.cluster.local:%s" $clouddefenseName .Release.Namespace $listenPort -}}
    {{- else -}}
        {{- printf "http://%s-clouddefensecollector:%s" $clouddefenseName $listenPort -}}
    {{- end -}}
{{- else -}}
    {{- .Values.clouddefense.http_output.url -}}
{{- end -}}
{{- end -}}


{{/*
Set appropriate clouddefense configuration if clouddefensecollector has been configured.
*/}}
{{- define "clouddefense.clouddefensecollectorConfig" -}}
{{- if .Values.clouddefensecollector.enabled  -}}
    {{- $_ := set .Values.clouddefense "json_output" true -}}
    {{- $_ := set .Values.clouddefense "json_include_output_property" true -}}
    {{- $_ := set .Values.clouddefense.http_output "enabled" true -}}
    {{- $_ := set .Values.clouddefense.http_output "url" (include "clouddefensecollector.url" .) -}}
{{- end -}}
{{- end -}}

{{/*
Get port from .Values.clouddefense.grpc.bind_addres.
*/}}
{{- define "grpc.port" -}}
{{- $error := "unable to extract listenPort from .Values.clouddefense.grpc.bind_address. Make sure it is in the correct format" -}}
{{- if and .Values.clouddefense.grpc.enabled .Values.clouddefense.grpc.bind_address (not (hasPrefix "unix://" .Values.clouddefense.grpc.bind_address)) -}}
    {{- $tokens := split ":" .Values.clouddefense.grpc.bind_address -}}
    {{- if $tokens._1 -}}
        {{- $tokens._1 -}}
    {{- else -}}
        {{- fail $error -}}
    {{- end -}}
{{- else -}}
    {{- fail $error -}}
{{- end -}}
{{- end -}}

{{/*
Disable the syscall source if some conditions are met.
By default the syscall source is always enabled in clouddefense. If no syscall source is enabled, clouddefense
exits. Here we check that no producers for syscalls event has been configured, and if true
we just disable the sycall source.
*/}}
{{- define "clouddefense.configSyscallSource" -}}
{{- $userspaceDisabled := true -}}
{{- $gvisorDisabled := (not .Values.gvisor.enabled) -}}
{{- $driverDisabled :=  (not .Values.driver.enabled) -}}
{{- if or (has "-u" .Values.extra.args) (has "--userspace" .Values.extra.args) -}}
{{- $userspaceDisabled = false -}}
{{- end -}}
{{- if and $driverDisabled $userspaceDisabled $gvisorDisabled }}
- --disable-source
- syscall
{{- end -}}
{{- end -}}

{{/*
We need the clouddefense binary in order to generate the configuration for gVisor. This init container
is deployed within the CloudDefense pod when gVisor is enabled. The image is the same as the one of CloudDefense we are
deploying and the configuration logic is a bash script passed as argument on the fly. This solution should
be temporary and will stay here until we move this logic to the clouddefensectl tool.
*/}}
{{- define "clouddefense.gvisor.initContainer" -}}
- name: {{ .Chart.Name }}-gvisor-init
  image: {{ include "clouddefense.image" . }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  args:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      root={{ .Values.gvisor.runsc.root }}
      config={{ .Values.gvisor.runsc.config }}

      echo "* Configuring CloudDefense+gVisor integration...".
      # Check if gVisor is configured on the node.
      echo "* Checking for /host${config} file..."
      if [[ -f /host${config} ]]; then
          echo "* Generating the CloudDefense configuration..."
          /usr/bin/clouddefense --gvisor-generate-config=${root}/clouddefense.sock > /host${root}/pod-init.json
          sed -E -i.orig '/"ignore_missing" : true,/d' /host${root}/pod-init.json
          if [[ -z $(grep pod-init-config /host${config}) ]]; then
            echo "* Updating the runsc config file /host${config}..."
            echo "  pod-init-config = \"${root}/pod-init.json\"" >> /host${config}
          fi
          # Endpoint inside the container is different from outside, add
          # "/host" to the endpoint path inside the container.
          echo "* Setting the updated CloudDefense configuration to /gvisor-config/pod-init.json..."
          sed 's/"endpoint" : "\/run/"endpoint" : "\/host\/run/' /host${root}/pod-init.json > /gvisor-config/pod-init.json
      else
          echo "* File /host${config} not found."
          echo "* Please make sure that the gVisor is configured in the current node and/or the runsc root and config file path are correct"
          exit -1
      fi
      echo "* CloudDefense+gVisor correctly configured."
      exit 0
  volumeMounts:
    - mountPath: /host{{ .Values.gvisor.runsc.path }}
      name: runsc-path
      readOnly: true
    - mountPath: /host{{ .Values.gvisor.runsc.root }}
      name: runsc-root
    - mountPath: /host{{ .Values.gvisor.runsc.config }}
      name: runsc-config
    - mountPath: /gvisor-config
      name: clouddefense-gvisor-config
{{- end -}}


{{- define "clouddefensectl.initContainer" -}}
- name: clouddefensectl-artifact-install
  image: {{ include "clouddefensectl.image" . }}
  imagePullPolicy: {{ .Values.clouddefensectl.image.pullPolicy }}
  args: 
    - artifact
    - install
  {{- with .Values.clouddefensectl.artifact.install.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.clouddefensectl.artifact.install.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.clouddefensectl.artifact.install.securityContext }}
    {{- toYaml .Values.clouddefensectl.artifact.install.securityContext | nindent 4 }}
  {{- end }}
  volumeMounts:
    - mountPath: {{ .Values.clouddefensectl.config.artifact.install.pluginsDir }}
      name: plugins-install-dir
    - mountPath: {{ .Values.clouddefensectl.config.artifact.install.rulesfilesDir }}
      name: rulesfiles-install-dir
    - mountPath: /etc/falcoctl
      name: clouddefensectl-config-volume
  env:
  {{- if .Values.clouddefensectl.artifact.install.env }}
  {{- include "clouddefense.renderTemplate" ( dict "value" .Values.clouddefensectl.artifact.install.env "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}

{{- define "clouddefensectl.sidecar" -}}
- name: clouddefensectl-artifact-follow
  image: {{ include "clouddefensectl.image" . }}
  imagePullPolicy: {{ .Values.clouddefensectl.image.pullPolicy }}
  args:
    - artifact
    - follow
  {{- with .Values.clouddefensectl.artifact.follow.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.clouddefensectl.artifact.follow.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.clouddefensectl.artifact.follow.securityContext }}
    {{- toYaml .Values.clouddefensectl.artifact.follow.securityContext | nindent 4 }}
  {{- end }}
  volumeMounts:
    - mountPath: {{ .Values.clouddefensectl.config.artifact.follow.pluginsDir }}
      name: plugins-install-dir
    - mountPath: {{ .Values.clouddefensectl.config.artifact.follow.rulesfilesDir }}
      name: rulesfiles-install-dir
    - mountPath: /etc/falcoctl
      name: clouddefensectl-config-volume
  env:
  {{- if .Values.clouddefensectl.artifact.follow.env }}
  {{- include "clouddefense.renderTemplate" ( dict "value" .Values.clouddefensectl.artifact.follow.env "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}