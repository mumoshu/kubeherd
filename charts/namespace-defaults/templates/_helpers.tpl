{{- define "namespaceObjects" -}}
{{- $ns := .name -}}
kind: Namespace
apiVersion: v1
metadata:
  name: "{{$ns}}"
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  namespace: "{{$ns}}"
  name: deny-from-other-namespaces
spec:
  podSelector:
    matchLabels:
  ingress:
  - from:
    - podSelector: {}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "tiller-{{$ns}}"
  namespace: "{{$ns}}"
automountServiceAccountToken: false
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  namespace: "{{$ns}}"
  name: "operator-{{$ns}}"
rules:
- apiGroups: ["", "extensions", "apps", "networking"]
  resources: ["deployments", "replicasets", "pods", "configmaps", "secrets", "networkpolicies"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"] # You can also use ["*"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: "tiller-{{$ns}}"
  namespace: "{{$ns}}"
subjects:
- kind: ServiceAccount
  name: "tiller-{{$ns}}"
  namespace: "{{$ns}}"
roleRef:
  kind: Role
  name: "operator-{{$ns}}"
  apiGroup: rbac.authorization.k8s.io
{{- end -}}
