{{/*
Expand the name of the chart.
*/}}
{{- define "cw-milvus.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cw-milvus.fullname" -}}
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
{{- define "cw-milvus.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cw-milvus.labels" -}}
helm.sh/chart: {{ include "cw-milvus.chart" . }}
{{ include "cw-milvus.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cw-milvus.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cw-milvus.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cw-milvus.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cw-milvus.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Set node affinities for GPU indexing
*/}}
{{- define "cw-milvus.gpuIndexingAffinities" -}}
dataNode:
  affinity:
    nodeAffinity:
      # override global component affinity when using GPU indexing
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node.coreweave.cloud/class
            operator: In
            values:
            - gpu
queryNode:
  affinity:
    nodeAffinity:
      # override global component affinity when using GPU indexing
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
        - matchExpressions:
          - key: node.coreweave.cloud/class
            operator: In
            values:
            - gpu
{{- end }}

{{/*
Default bucket prefix, if not specified
*/}}
{{- define "cw-milvus.caiosBucketRootPath" -}}
{{- default (include "cw-milvus.name" .) .Values.caiosBucketRootPath }}
{{- end }}

{{/*
Default bucket prefix for backup, if not specified
*/}}
{{- define "cw-milvus.backupBucketRootPath" -}}
{{- default "backup" .Values.backupBucketRootPath }}
{{- end }}

{{/*
Default backup bucket, if not specified
*/}}
{{- define "cw-milvus.backupBucketName" -}}
{{- default .Values.caiosBucketName .Values.backupCaiosBucketName }}
{{- end }}

{{/*
Backup bucket access key, if not specified
*/}}
{{- define "cw-milvus.backupBucketAccessKey" -}}
{{- default .Values.caiosAccessKey .Values.backupCaiosAccessKey }}
{{- end }}

{{/*
Backup bucket secret key, if not specified
*/}}
{{- define "cw-milvus.backupBucketSecretKey" -}}
{{- default .Values.caiosSecretKey .Values.backupCaiosSecretKey }}
{{- end }}

{{/*
Resource deletion policies
*/}}
{{- define "cw-milvus.deleteDependencies" -}}
deletionPolicy: Delete
pvcDeletion: true
{{- end }}

{{/*
Milvus address
*/}}
{{- define "cw-milvus.address" -}}
{{- include "cw-milvus.name" . }}-milvus.{{.Release.Namespace}}.svc.cluster.local
{{- end }}

{{- define "retemplate" -}}
  {{- $value := index . 0 }}
  {{- $context := index . 1 }}
  {{- if typeIs "string" $value }}
      {{- tpl $value $context }}
  {{- else }}
      {{- tpl ($value | toYaml) $context }}
  {{- end }}
{{- end}}
