{{/*
Expand the name of the chart.
*/}}
{{- define "galaxyserve.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars (Kubernetes name limit). If release name contains the
chart name it is used as-is to avoid duplication.
*/}}
{{- define "galaxyserve.fullname" -}}
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
Chart name and version, as used by the chart label.
*/}}
{{- define "galaxyserve.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "galaxyserve.labels" -}}
helm.sh/chart: {{ include "galaxyserve.chart" . }}
{{ include "galaxyserve.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: galaxyops
{{- end }}

{{/*
Selector labels (stable across upgrades — never include version here).
*/}}
{{- define "galaxyserve.selectorLabels" -}}
app.kubernetes.io/name: {{ include "galaxyserve.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Service account name to use.
*/}}
{{- define "galaxyserve.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "galaxyserve.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
The container image reference (repository:tag).
*/}}
{{- define "galaxyserve.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}
