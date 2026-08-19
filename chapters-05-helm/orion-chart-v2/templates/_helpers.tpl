{{- define "orion.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- define "orion.fullname" -}}
{{- printf "%s-%s" .Release.Name (include "orion.name" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}
