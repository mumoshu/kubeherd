# Ship

A opinionated toolkit to automate your application release process on top of Kubernetes on AWS.

It is **opinionated** in the sense that it assumes that:

> Your Kubernetes on AWS clusters are not pets but cattles, like EC2 instances combined with UserData/LaunchConfiguration/ASG, hence any cluster can be recreated anytime without worrying anything.

## Goal

Automate your application release process as much as possible.

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

## No goals

### Re-inventing existing tools

This toolkit does its best to reuse existing tools and adapt your existing, used tools.

For example, this toolkit should not force you to write your k8s manifest as jsonnet, json, yaml, golang-template, jinja2, etc.
You should be able to bring your existing template engine to this toolkit and it should be a matter of invoking the engine to render manifests consumed by the toolkit.
