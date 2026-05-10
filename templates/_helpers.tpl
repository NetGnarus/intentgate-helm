{{/*
Naming helpers for the intentgate chart.

intentgate.name        — the chart name (overridable via nameOverride)
intentgate.fullname    — release-qualified name (overridable via fullnameOverride)
intentgate.labels      — common labels stamped on every object
intentgate.matchLabels — the subset used for selectors (must be stable across upgrades)
intentgate.serviceAccountName — picks chart-managed or pre-existing
*/}}

{{- define "intentgate.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "intentgate.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "intentgate.gateway.fullname" -}}
{{- printf "%s-gateway" (include "intentgate.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "intentgate.extractor.fullname" -}}
{{- printf "%s-extractor" (include "intentgate.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "intentgate.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Common labels stamped on every object. The Chart and Release labels are
required so `helm uninstall` cleans up correctly; the rest follow the
Kubernetes recommended-labels convention (app.kubernetes.io/*).
*/}}
{{- define "intentgate.labels" -}}
helm.sh/chart: {{ include "intentgate.chart" . }}
app.kubernetes.io/name: {{ include "intentgate.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: intentgate
{{- end -}}

{{/*
Selector labels. MUST be a strict subset of intentgate.labels and MUST
NOT change across chart upgrades — Deployment selectors are immutable.
*/}}
{{- define "intentgate.gateway.matchLabels" -}}
app.kubernetes.io/name: {{ include "intentgate.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: gateway
{{- end -}}

{{- define "intentgate.extractor.matchLabels" -}}
app.kubernetes.io/name: {{ include "intentgate.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: extractor
{{- end -}}

{{/*
ServiceAccount name: either the one this chart created or a
pre-existing name supplied via values.serviceAccount.name.
*/}}
{{- define "intentgate.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "intentgate.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{/*
Master-key Secret name. If the user supplied an existing Secret, use it;
otherwise the chart manages its own.
*/}}
{{- define "intentgate.masterKeySecretName" -}}
{{- if .Values.gateway.existingMasterKeySecret -}}
{{- .Values.gateway.existingMasterKeySecret -}}
{{- else -}}
{{- printf "%s-master-key" (include "intentgate.gateway.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Policy ConfigMap name. Same chart-managed-vs-existing logic as the
master-key Secret.
*/}}
{{- define "intentgate.policyConfigMapName" -}}
{{- if .Values.gateway.existingPolicyConfigMap -}}
{{- .Values.gateway.existingPolicyConfigMap -}}
{{- else -}}
{{- printf "%s-policy" (include "intentgate.gateway.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Anthropic API-key Secret name (used by the extractor when stubMode=false).
*/}}
{{- define "intentgate.extractor.apiKeySecretName" -}}
{{- if .Values.extractor.existingApiKeySecret -}}
{{- .Values.extractor.existingApiKeySecret -}}
{{- else -}}
{{- printf "%s-anthropic" (include "intentgate.extractor.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Admin-token Secret name (used by /v1/admin/* auth).
*/}}
{{- define "intentgate.adminTokenSecretName" -}}
{{- if .Values.gateway.existingAdminTokenSecret -}}
{{- .Values.gateway.existingAdminTokenSecret -}}
{{- else -}}
{{- printf "%s-admin-token" (include "intentgate.gateway.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Postgres URL Secret name (used by the revocation store).
*/}}
{{- define "intentgate.postgresUrlSecretName" -}}
{{- if .Values.existingPostgresUrlSecret -}}
{{- .Values.existingPostgresUrlSecret -}}
{{- else -}}
{{- printf "%s-postgres-url" (include "intentgate.gateway.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
SIEM Secret names. Same chart-managed-vs-existing pattern as the
other Secret helpers.
*/}}
{{- define "intentgate.splunkTokenSecretName" -}}
{{- if .Values.gateway.siem.splunk.existingTokenSecret -}}
{{- .Values.gateway.siem.splunk.existingTokenSecret -}}
{{- else -}}
{{- printf "%s-splunk-token" (include "intentgate.gateway.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "intentgate.datadogApiKeySecretName" -}}
{{- if .Values.gateway.siem.datadog.existingApiKeySecret -}}
{{- .Values.gateway.siem.datadog.existingApiKeySecret -}}
{{- else -}}
{{- printf "%s-datadog-api-key" (include "intentgate.gateway.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "intentgate.sentinelClientSecretSecretName" -}}
{{- if .Values.gateway.siem.sentinel.existingClientSecretSecret -}}
{{- .Values.gateway.siem.sentinel.existingClientSecretSecret -}}
{{- else -}}
{{- printf "%s-sentinel-client-secret" (include "intentgate.gateway.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/*
Resolved image references. Empty tag falls through to .Chart.AppVersion
so a chart upgrade tracks the appVersion bump automatically.
*/}}
{{- define "intentgate.gateway.image" -}}
{{- $tag := default .Chart.AppVersion .Values.gateway.image.tag -}}
{{- printf "%s:%s" .Values.gateway.image.repository $tag -}}
{{- end -}}

{{- define "intentgate.extractor.image" -}}
{{- $tag := default .Chart.AppVersion .Values.extractor.image.tag -}}
{{- printf "%s:%s" .Values.extractor.image.repository $tag -}}
{{- end -}}
