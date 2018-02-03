- dedicated ns for per-microservice brigade project
- per-microservice brigade project
- tiller per microservice
- dedicated ns for per-microservice tiller
- network policies
- ns-level resouce quotas
- rbac(only crud for pod, svc, deploy, configmap, secret, ingress, exce, port-forward. no sa, rolebinding, role)
- serviceaccounts with the above rbac policies(used by tiller, brigade-worker, devops)

The above configuration is applied whenever the git repo containing namespaces definitions is updated, by system-level brigade project.
