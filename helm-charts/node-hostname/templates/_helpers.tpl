{{/*
Expand the name of the chart.
*/}}
{{- define "node-hostname-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a fully qualified name.
Priority: fullnameOverride > Release.Name + Chart.Name
Truncate at 63 chars due to DNS naming limits.
*/}}
{{- define "node-hostname-chart.fullname" -}}
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
Chart name and version for labels.
Example: node-hostname-chart-1.0.0
*/}}
{{- define "node-hostname-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels (recommended by Kubernetes)
*/}}
{{- define "node-hostname-chart.labels" -}}
helm.sh/chart: {{ include "node-hostname-chart.chart" . }}
app.kubernetes.io/name: {{ include "node-hostname-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/part-of: {{ include "node-hostname-chart.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end }}

{{/*
Selector labels (must match between Deployment and Service)
*/}}
{{- define "node-hostname-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "node-hostname-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}