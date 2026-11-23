{{- define "sabnzbd.selectorLabels" -}}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "sabnzbd.labels" -}}
{{ include "sabnzbd.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{- end }}

{{/* Without the chart's version, so a release that changes only the chart doesn't restart SABnzbd. */}}
{{- define "sabnzbd.podLabels" -}}
{{ include "sabnzbd.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}

{{- define "sabnzbd.secretKeyRef" -}}
{{- $path := index . 0 }}
{{- $ref := (index . 1).secretKeyRef }}
secretKeyRef:
  name: {{ required (printf "%s.secretKeyRef.name is required" $path) $ref.name }}
  key: {{ required (printf "%s.secretKeyRef.key is required" $path) $ref.key }}
{{- end }}

{{/* The settings the init container applies; the deployment hashes it to restart on a change. */}}
{{- define "sabnzbd.settings" -}}
{{- if not .Values.persistence.media }}
{{- fail "persistence.media needs at least one mount" }}
{{- end }}
{{- $completeDir := required "completeDir is required" .Values.completeDir }}
{{- $underMount := false }}
{{- range .Values.persistence.media }}
{{- $prefix := printf "%s/" (trimSuffix "/" (required "each persistence.media mount needs a mountPath" .mountPath)) }}
{{- if hasPrefix $prefix (printf "%s/" (trimSuffix "/" $completeDir)) }}{{ $underMount = true }}{{ end }}
{{- end }}
{{- if not $underMount }}
{{- fail "completeDir must be on one of the persistence.media mounts" }}
{{- end }}
{{- $servers := list }}
{{- range .Values.servers }}
{{- $given := . }}
{{- $name := required "each server needs a name" .name }}
{{- $server := dict "name" $name "host" (required (printf "server %s needs a host" $name) .host) "port" 563 "ssl" true "connections" 8 "enable" true }}
{{- range $key := list "port" "ssl" "connections" "enable" }}
{{- if hasKey $given $key }}{{ $_ := set $server $key (get $given $key) }}{{ end }}
{{- end }}
{{- $servers = append $servers $server }}
{{- end }}
{{- $categories := list }}
{{- range .Values.categories }}
{{- $given := . }}
{{- $name := required "each category needs a name" .name }}
{{- $category := dict "name" $name "dir" $name "pp" "" "script" "Default" "priority" -100 }}
{{- range $key := list "dir" "pp" "script" "priority" }}
{{- if hasKey $given $key }}{{ $_ := set $category $key (get $given $key) }}{{ end }}
{{- end }}
{{- $categories = append $categories $category }}
{{- end }}
{{- $settings := dict "downloadDir" .Values.persistence.incomplete.mountPath "completeDir" $completeDir "cacheLimit" .Values.cacheLimit "servers" $servers "categories" $categories }}
{{- toJson $settings }}
{{- end }}
