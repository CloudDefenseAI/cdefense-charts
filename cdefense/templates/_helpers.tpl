{{/*
Expand the name of the chart.
*/}}
{{- define "cdefense.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cdefense.fullname" -}}
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
{{- define "cdefense.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Allow the release namespace to be overridden
*/}}
{{- define "cdefense.namespace" -}}
{{- default .Release.Namespace .Values.namespaceOverride -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "cdefense.labels" -}}
helm.sh/chart: {{ include "cdefense.chart" . }}
{{ include "cdefense.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cdefense.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cdefense.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Renders a value that contains template.
Usage:
{{ include "cdefense.renderTemplate" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "cdefense.renderTemplate" -}}
    {{- if typeIs "string" .value }}
        {{- tpl .value .context }}
    {{- else }}
        {{- tpl (.value | toYaml) .context }}
    {{- end }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "cdefense.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cdefense.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper Cdefense image name
*/}}
{{- define "cdefense.image" -}}
{{- with .Values.image.registry -}}
    {{- . }}/
{{- end -}}
{{- .Values.image.repository }}:
{{- .Values.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{/*
Return the proper Cdefense driver loader image name
*/}}
{{- define "cdefense.driverLoader.image" -}}
{{- with .Values.driver.loader.initContainer.image.registry -}}
    {{- . }}/
{{- end -}}
{{- .Values.driver.loader.initContainer.image.repository }}:
{{- .Values.driver.loader.initContainer.image.tag | default .Chart.AppVersion -}}
{{- end -}}

{{/*
Return the proper Cdefensectl image name
*/}}
{{- define "cdefensectl.image" -}}
{{ printf "%s/%s:%s" .Values.cdefensectl.image.registry .Values.cdefensectl.image.repository .Values.cdefensectl.image.tag }}
{{- end -}}

{{/*
Extract the unixSocket's directory path
*/}}
{{- define "cdefense.unixSocketDir" -}}
{{- if and .Values.cdefense.grpc.enabled .Values.cdefense.grpc.bind_address (hasPrefix "unix://" .Values.cdefense.grpc.bind_address) -}}
{{- .Values.cdefense.grpc.bind_address | trimPrefix "unix://" | dir -}}
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
 Build http url for cdefensesidekick.
*/}}
{{- define "cdefensesidekick.url" -}}
{{- if not .Values.cdefense.http_output.url -}}
    {{- $cdefenseName := include "cdefense.fullname" . -}}
    {{- $listenPort := .Values.cdefensesidekick.listenport | default "2801" -}}
    {{- if .Values.cdefensesidekick.fullfqdn -}}
       {{- printf "http://%s-cdefensesidekick.%s.svc.cluster.local:%s" $cdefenseName .Release.Namespace $listenPort -}}
    {{- else -}}
        {{- printf "http://%s-cdefensesidekick:%s" $cdefenseName $listenPort -}}
    {{- end -}}
{{- else -}}
    {{- .Values.cdefense.http_output.url -}}
{{- end -}}
{{- end -}}


{{/*
Set appropriate cdefense configuration if cdefensesidekick has been configured.
*/}}
{{- define "cdefense.cdefensesidekickConfig" -}}
{{- if .Values.cdefensesidekick.enabled  -}}
    {{- $_ := set .Values.cdefense "json_output" true -}}
    {{- $_ := set .Values.cdefense "json_include_output_property" true -}}
    {{- $_ := set .Values.cdefense.http_output "enabled" true -}}
    {{- $_ := set .Values.cdefense.http_output "url" (include "cdefensesidekick.url" .) -}}
{{- end -}}
{{- end -}}

{{/*
Get port from .Values.cdefense.grpc.bind_addres.
*/}}
{{- define "grpc.port" -}}
{{- $error := "unable to extract listenPort from .Values.cdefense.grpc.bind_address. Make sure it is in the correct format" -}}
{{- if and .Values.cdefense.grpc.enabled .Values.cdefense.grpc.bind_address (not (hasPrefix "unix://" .Values.cdefense.grpc.bind_address)) -}}
    {{- $tokens := split ":" .Values.cdefense.grpc.bind_address -}}
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
By default the syscall source is always enabled in cdefense. If no syscall source is enabled, cdefense
exits. Here we check that no producers for syscalls event has been configured, and if true
we just disable the sycall source.
*/}}
{{- define "cdefense.configSyscallSource" -}}
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
We need the cdefense binary in order to generate the configuration for gVisor. This init container
is deployed within the Cdefense pod when gVisor is enabled. The image is the same as the one of Cdefense we are
deploying and the configuration logic is a bash script passed as argument on the fly. This solution should
be temporary and will stay here until we move this logic to the cdefensectl tool.
*/}}
{{- define "cdefense.gvisor.initContainer" -}}
- name: {{ .Chart.Name }}-gvisor-init
  image: {{ include "cdefense.image" . }}
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

      echo "* Configuring Cdefense+gVisor integration...".
      # Check if gVisor is configured on the node.
      echo "* Checking for /host${config} file..."
      if [[ -f /host${config} ]]; then
          echo "* Generating the Cdefense configuration..."
          /usr/bin/cdefense --gvisor-generate-config=${root}/cdefense.sock > /host${root}/pod-init.json
          sed -E -i.orig '/"ignore_missing" : true,/d' /host${root}/pod-init.json
          if [[ -z $(grep pod-init-config /host${config}) ]]; then
            echo "* Updating the runsc config file /host${config}..."
            echo "  pod-init-config = \"${root}/pod-init.json\"" >> /host${config}
          fi
          # Endpoint inside the container is different from outside, add
          # "/host" to the endpoint path inside the container.
          echo "* Setting the updated Cdefense configuration to /gvisor-config/pod-init.json..."
          sed 's/"endpoint" : "\/run/"endpoint" : "\/host\/run/' /host${root}/pod-init.json > /gvisor-config/pod-init.json
      else
          echo "* File /host${config} not found."
          echo "* Please make sure that the gVisor is configured in the current node and/or the runsc root and config file path are correct"
          exit -1
      fi
      echo "* Cdefense+gVisor correctly configured."
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
      name: cdefense-gvisor-config
{{- end -}}


{{- define "cdefensectl.initContainer" -}}
- name: cdefensectl-artifact-install
  image: {{ include "cdefensectl.image" . }}
  imagePullPolicy: {{ .Values.cdefensectl.image.pullPolicy }}
  args: 
    - artifact
    - install
  {{- with .Values.cdefensectl.artifact.install.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.cdefensectl.artifact.install.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.cdefensectl.artifact.install.securityContext }}
    {{- toYaml .Values.cdefensectl.artifact.install.securityContext | nindent 4 }}
  {{- end }}
  volumeMounts:
    - mountPath: {{ .Values.cdefensectl.config.artifact.install.pluginsDir }}
      name: plugins-install-dir
    - mountPath: {{ .Values.cdefensectl.config.artifact.install.rulesfilesDir }}
      name: rulesfiles-install-dir
    - mountPath: /etc/cdefensectl
      name: cdefensectl-config-volume
  env:
  {{- if .Values.cdefensectl.artifact.install.env }}
  {{- include "cdefense.renderTemplate" ( dict "value" .Values.cdefensectl.artifact.install.env "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}

{{- define "cdefensectl.sidecar" -}}
- name: cdefensectl-artifact-follow
  image: {{ include "cdefensectl.image" . }}
  imagePullPolicy: {{ .Values.cdefensectl.image.pullPolicy }}
  args:
    - artifact
    - follow
  {{- with .Values.cdefensectl.artifact.follow.args }}
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.cdefensectl.artifact.follow.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  securityContext:
  {{- if .Values.cdefensectl.artifact.follow.securityContext }}
    {{- toYaml .Values.cdefensectl.artifact.follow.securityContext | nindent 4 }}
  {{- end }}
  volumeMounts:
    - mountPath: {{ .Values.cdefensectl.config.artifact.follow.pluginsDir }}
      name: plugins-install-dir
    - mountPath: {{ .Values.cdefensectl.config.artifact.follow.rulesfilesDir }}
      name: rulesfiles-install-dir
    - mountPath: /etc/cdefensectl
      name: cdefensectl-config-volume
  env:
  {{- if .Values.cdefensectl.artifact.follow.env }}
  {{- include "cdefense.renderTemplate" ( dict "value" .Values.cdefensectl.artifact.follow.env "context" $) | nindent 4 }}
  {{- end }}
{{- end -}}