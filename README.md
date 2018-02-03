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

This toolkit provides reusable, and/or educative scripts to make it easier for most people.

### Common helm charts

Writing a helm chart to maintain your K8S on AWS workload in a highly-avaialble, secure, sustainable manner is too hard.

- Pod anti affinity: In many cases, your pods should prefer spreading over multiple nodes, so that a single node failure doesn't affect your service availability.
- Minimum replicas: Similarly, in many cases your workload should be typed as k8s' `Depoyment` with `replicas` greater than or equal to `2`. Otherwise, even with pod anti-affinity above, your service may suffer downtime due to a single node failure.
- and so on...

This toolkit provides a reusable and/or educative helm charts to make it easier for most people.

### Automatic redeployment

Recreating your cluster requires you to gather/reproduce the whole apps which were intended to be running on the old cluster to the new one.
In case you have a StatefulSet running on the old node, migration from old to new one is even harder.

This toolkit "resolves" this problem by forcing you:

- to NOT deploy any stateful workloads on Kubernetes on AWS. Use [kube-ingress-aws-controller](https://github.com/zalando-incubator/kube-ingress-aws-controller) instead.
- to NOT use k8s' `Service` of `type: LoadBalancer`. Use other than that to automatically update existing ELBs to add the worker nodes in the new k8s cluster.

while allowing you:

- to have an in-cluster CI pipeline reacts by deployments the required apps whenever a cluster starts and GitHub deployments are created.

### Machine image builds

It is often cumbersome to update your OS on every node. Even with Container Linux, the standard method of enabling locksmithd + update_engine, or even container-linux-update-operator don't fit when you bake specific binaries and images into machine images. It also doesn't work well with ASG and Spot Fleets as an OS update doesn't (of course) update the launch configuration/specification to have a newer AMI ID. It eventually results in unnecessary rolling-updates of nodes.

`kubeherd build ami` invokes a packer build to produce an AMI based on the latest Container Linux release.

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
