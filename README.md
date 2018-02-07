# kubeherd

A opinionated toolkit to herd your ephemeral Kubernetes clusters.

## Assumptions

It is **opinionated** in the sense that it assumes that:

1. Your Kubernetes on AWS clusters are not pets but cattles, like EC2 instances combined with UserData/LaunchConfiguration/ASG, hence any cluster can be recreated anytime without worrying anything.
2. Your Kubernetes on AWS clusters should not serve persistent databases or persistent cache stores. Delegate those to AWS. Use RDS, Elasticache, ES, etc.

## Goal

Automate your cluster management tasks and application release process as much as possible.

## Scope

This toolkit aims to resolve following problems to achieve the goal:

### Container image builds

Building a secure, small container image for running script languages like ruby, python, nodejs is too hard.
Building docker images from your private git repos with plain docker builds, multi-stage builds and build-args are wrong in several ways.
Many exsiting solutions either give up utilizing docker layer caches and therefore docker builds are slow, or give up removing SSH private keys and/or GitHub personal access tokens from the resulting docker images.

Solution: `kubeherd build dockerimage` builds pulls image layer cache, inject secrets, docker-run and docker-commit to build an image. Under the hood it utilizes reusable and/or educative scripts contained in this repo.

### Common helm charts

Writing a helm chart to maintain your K8S on AWS workload in a highly-avaialble, secure, sustainable manner is too hard.

- Pod anti affinity: In many cases, your pods should prefer spreading over multiple nodes, so that a single node failure doesn't affect your service availability.
- Minimum replicas: Similarly, in many cases your workload should be typed as k8s' `Depoyment` with `replicas` greater than or equal to `2`. Otherwise, even with pod anti-affinity above, your service may suffer downtime due to a single node failure.
- and so on...

This toolkit provides a reusable and/or educative helm charts to make it easier for most people.

### Automatic (re)deployment

Recreating your cluster requires you to gather/reproduce the whole apps which were intended to be running on the old cluster to the new one. Do you manually kick your Jenkins to deploy all of your apps to the new cluster?

Solution: `kubeherd deploy` deploys a set of helm charts declared in your charts.yaml(helmfile), so that

- You have an in-cluster CI pipeline per kubeherd-system and per microservice/namespace reacts by installing the required helm charts whenever a cluster starts and GitHub deployments are created.


Note that this relies the following assumptions:

- DO NOT deploy any stateful workloads on Kubernetes on AWS. Use [kube-ingress-aws-controller](https://github.com/zalando-incubator/kube-ingress-aws-controller) instead.
- DO NOT use k8s' `Service` of `type: LoadBalancer`. Use other than that to automatically update existing ELBs to add the worker nodes in the new k8s cluster.

### Machine image builds

It is often cumbersome to update your OS on every node. Even with Container Linux, the standard method of enabling locksmithd + update_engine, or even container-linux-update-operator don't fit when you bake specific binaries and images into machine images. It also doesn't work well with ASG and Spot Fleets as an OS update doesn't (of course) update the launch configuration/specification to have a newer AMI ID. It eventually results in unnecessary rolling-updates of nodes.

Solution: `kubeherd build ami` invokes a packer build to produce an AMI based on the latest Container Linux release.

### Tech stacks

This toolkit has chosen the following solutions for various reasons

#### nginx-ingress-controller

We chose the nginx ingress because it supports widest feature set compared to the alternatives: Skipper, Istio Ingress, Istio Gateway, Ambassador, Contour

- TCP/UDP load-balancing
- HTTP->HTTPS redirecting
- and [so on](https://github.com/kubernetes/contrib/tree/master/ingress/controllers/nginx/examples)

## Non goals

### Re-inventing existing tools

This toolkit does its best to reuse existing tools and adapt your existing, used tools.

For example, this toolkit should not force you to write your k8s manifest as jsonnet, json, yaml, golang-template, jinja2, etc.
You should be able to bring your existing template engine to this toolkit and it should be a matter of invoking the engine to render manifests consumed by the toolkit.

## Utilized existing solutions

- brigade for a workflow of k8s jobs
- plain-old k8s service for optional blue-green deployment capability
- helm for simple workflows(install -> post-install) and k8s manifest templating/packaing
- helmfile to declare a set of local/remote helm charts used for per-microservice deployment
- helm-secrets for managing per-cluster, per-microservice secrets
- smith for possible support for dependency management after service catalog adoption
- prometheus for optional canary analysis and automated rollback
- elasticsearch-operator for persisting ephemeral in-cluster logs for summarizing logs prior to the deployment rollback
- your preferred SaaS or self-hosted services for cross-cluster monitoring and cross-cluster distributed logging
  - sysdig
  - datadog
- your preferred APM for cross-cluster, app-centric view of your application healthiness

## Usage

Run the below bash snippet on cluster startup/cluster update:

```
# possibly inside userdata of a controller nodes

docker run --rm mumoshu/kube-hearder:$ver init --github-repo github.com:yourorg/yourrepo.git --github-username mybotname --parameter-store-key-ghtoken myghtoken --parameter-store-key-slacktoken myslacktoken
```

Note: A set of IAM permissions to access AWS parameter store for retrieving a github/slack token is required

This will invoke the following steps:

- `helm init --upgrade --version $chart_ver --namespace kube-system kube-hearder charts/kube-hearder-controller` to install/uprgade a brigade project for the system

Note: post-install job to `brig run` the per-cluster pipeline for initial deployment

Which periodically invokes the following steps to sync the infrastructure:

- `git clone/fetch/checkout the repo`
- `helm upgrade --install kube-herder charts/kube-hearder -f repo/.kube-herder/config.yaml`
- `for n in $microservices; do git clone $(git-repo $n) sourcetree/$n && helm upgrade --install $n-infra charts/namespace-defaults -f sourcetree/$n/.kube-herder/config.yaml; done`

Note: post-install job to `brig run` the per-microservice pipeline for initial deployment

And after that, per-microservice brigade project is responsible to run the app deployment on each github webhook event.

## Example setup

Your whole projects structure would look like:


* `GitHub/`
  * `your-org/`
    * `your-cluster-repo/`
      * `environments/`
        * test/
          * `cluster-infra/`
            * `helmfile`
              * Create a brigade and a brigade-project per cluster into the k8s namespace `cluster-system`
              * The brigade-project continuously pulls this git repo and sync your cluster state to the helmfile for each repo like `your-app1-repo`
            * `brigade-project.values.yaml`
            * `brigade-project.secrets.yaml.enc`
          * `app-infra/`
            * `helmfile`
              * Create namespaces `your-app1-repo`
              * Install a brigade and a brigade-project per app into the k8s namespace `your-app1-repo`
              * Create a set of service accounts(tiller, brigade), RBAC(especially, "developer" role which is used by service accounts and the user authenticated via AWS IAM) and network policies in the namespace named `your-app1-repo` per app
            * namespace-defaults.values.yaml
            * brigade.values.yaml
        * production/
    * your-app1-repo/
      * `ci/`
        * `environments/`
          * `$env/`
            * `$env` specific `brigade.values.yaml` and/or `brigade.secrets.yaml`, used by the `app-infra` helmfile.
        * `brigade.values.yaml`
        * `brigade.secrets.yaml.enc`
  
## Example cluster-bootstrap sequence

- `docker run --rm mumoshu/kuebherd init --upgdade -e $env -c $cluster -r github.com/your-org/your-cluster-repo -u yourbot -t name/of/ssm/parameter/containing/ssh/key/or/token` is run on one of k8s controller nodes so that(for example `$env=test` and `$cluster=k8stest1`. there could be 2 or more clusters per env for cluster blue-green deployment)
  - `git clone github.com/your-org/your-cluster-repo`
  - `cd your-cluster-repo/environments/$env`
  - `sops -d brigade-project.secrets.yaml.enc > brigade-project.secrets.yaml`
  - `CLUSTER=$cluster helmfile sync -f helmfile`
    - `CLUSTER` is embeded into ENV of the brigade project so that it can be accessed from within the pipeline
  - A cluster-level brigade pipeline is created
  - App-level brigade pipeline(s) are created
- The cluster-level brigade pipeline runs the following steps on each webhook event(github deployment) for `github.com/your-org/your-cluster-repo`
  - `git clone github.com/your-org/your-cluster-repo`
  - `cd your-cluster-repo/environments/$env`
  - `sops -d brigade-project.secrets.yaml.enc > brigade-project.secrets.yaml`
  - `CLUSTER=$cluster helmfile sync -f helmfile`
  - The brigade pipeline for the cluster is updated
- The app-level brigade pipeline runs the following steps on each webhook event(github deployment) for `github.com/your-org/your-app1-repo`
  - `git clone github.com/your-org/your-app1-repo`
  - `cd your-app1-repo/ci/environments/$env`
  - `sops -d brigade-project.secrets.yaml.enc > brigade-project.secrets.yaml`
  - `helmfile sync -f ../../ci/helmfile`
  - The app-level brigade-pipeline is updated
  - The app managed by the pipeline is updated
