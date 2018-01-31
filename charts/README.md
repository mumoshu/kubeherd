## How it works

There is a convension that the helm release name is formatted as `<app=git repo name without user/org name>(-<component name>)-<short-commit-id or hash>`
so that:

### Deploying a typical web app

cd to your app root:

```
cd myrailsapp
```

cd to your component root:

```
cd .ship/components/web
```

```
helm secrets upgrade --install charts/rails-nginx-unicorn \
  --name myrailsapp-web-abcdefg \
  --namespace myrailsapp \
  -f .ship/environments/$env/secrets.yaml \
  -f .ship/environments/$env/values.yaml \
  -f .ship/components/web/secrets.yaml \
  -f .ship/components/web/values.yaml \
  --set registry=<aws account id>.ecr... \
  --set image=myrailsapp/web:abcdefg
```

or

```
helm secrets template charts/rails-nginx-unicorn \
  --name myrailsapp-web-abcdefg \
  -f /path/to/environments/$env/secrets.yaml \
  -f /path/to/environments/$env/values.yaml \
  -f secrets.yaml \
  -f values.yaml \
  --set registry=<aws account id>.ecr... \
  --set image=myrailsapp/web:abcdefg \
  | kubectl apply --prune --namespace myrailsapp
```

or just using our helper

```
ship deploy --only web --commit abcdefg
```

in case `deploy.strategy` is set to `blue-green`, it will create a release named `myrailsapp-web-abcdefg` and no k8s service is created.
Oherwise a release `myrailsapp-web` and a k8s service named as so is also created.

> Note:
> 
> * `myrailsapp` is infered from the directory name
> * `web` is searched under .ship/components and located at `.ships/compoents/web`
> * `abcdefg` can be automatically inferred from the git worktree or CI-specific envvar

Will result in pods labeled with:

- `release: myrailsapp-web-abcdefg`
-  `app: myrailsapp`
- `component: web`
- `commit: abcdefg`

* `release` is used solely for tracking and correlating the helm release and the pods
* `commit` is used for blue-green deployments, canary analysis, correlation among logs and pods and git commits
* `app` is used for the per-service default log view of your centralized logging system
* `component` is used for per-component default log view of your centralized logging system
* `replicas` defaults to `2` for high availability
  Pods have pod-anti-affinities for high availability

Note that:

- `--set registry=...` repetition could be avoided with an organization-specific common values.yaml which may contains:
  registry: <aws account id>.ecr...
  Actually, that's what `ship.yaml` contains.

- `--set image=myrailsapp/web:abcdefg` could be omitted because it can be computed from the release name

### Deploying a typical background job worker/message queue consumer

```
helm upgrade --install charts/resque --name myrailsapp-worker-abcdefg --set registry=<aws account id>.ecr... --set image=myrailsapp/worker:abcdefg
```

* The resulting pods will be labeled with `release: myrailsapp-stable`
* `replicas` defaults to `2`

### Creating a k8s service

```
helm secrets upgrade --install charts/service --name myrailsapp-web --set service.src-port 80 --set service.dst-port 8080
```

will create a k8s service named `myrailsapp-web` load-balances requests to `<cluster ip>:80` to `<pod ip>:8080` of pods labeled with:

- `app: myrailsapp`
- `component: web`

### Do not automatically route to newer versions of apps

CAUTION: This is an optional, dangerous operation. Understand the possibility to blind down your service on a mis-operation
Also note that this is required only when doing [k8s-native blue-green deployment](https://www.ianlewis.org/en/bluegreen-deployments-kubernetes).

```
helm secrets upgrade --install charts/service --name myrailsapp-web --set service.src-port 80 --set service.dst-port 8080 --set commit=abcdefg
```

Beware that this will break once you undeploy `myrailsapp-web-abcdefg`, hence noted "Dangerous".
For granular routing like this, I'd rather recommend utilizing a service mesh with support for "fallback service".
For example, [Linkerd supports that](https://github.com/linkerd/linkerd/issues/1549).

### Deploying new version

Just specify a newer commit id to be deployed:

```
ship deploy --only web --commit gfedcba
```

in case `ship.deploy.strategy` is set to `blue-green`, it will create a new release named `myrailsapp-web-gfedcba`.
Oherwise the release `myrailsapp-web` is updated to commit `gfedcba`.

### (Optional) Switch to the new version of your app

```
helm secrets upgrade --install charts/service --name myrailsapp-web --set service.src-port 80 --set service.dst-port 8080 --set commit=gfedcba
```

### (Optional) Running an interactive session

```
helm secrets upgrade --install charts/job --name myrailsapp-web-<id> 

pod=$(kubectl get po | grep myrailsapp-web-<id> | cut -d ' ' -f 1)

kubectl exec -i --tty $pod $cmd
```

```
ship run -i --tty --only web -- $cmd
```

### (Optional) Running a command in background

```
ship run --only web -- $cmd
```

### Undeploying

```
helm uninstall myrailsapp-web-abcdefg
```

or

```
ship undeploy --only web --commit abcdefg
```
