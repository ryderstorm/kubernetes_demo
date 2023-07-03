# Kubernetes Demo

## Requirements

WIP

## Building Docker Images for the Demo Apps

Before you can deploy the demo apps to Kubernetes, you'll need to build the Docker images for the demo apps. To do this, run the build script:

```bash
./bin/build_docker_images.sh
```

## Deploying a Kubernetes cluster using Terraform and AWS EKS

WIP

## Using k3s for Local Development

k3s is a lightweight Kubernetes distribution. It is a single binary that provides a fully compliant Kubernetes API server and Kubernetes controller components. This project uses k3s to provide a local development environment for Kubernetes.

### Install k3s, set up local cluster, and deploy Traefik and demo apps

Run the script to install k3s and set up the local k8s cluster.

```bash
./bin/setup_k3s.sh
```

### Set up kubectl

Ensure that the `KUBECONFIG` environment variable is set to the location of the k3s configuration file so that kubectl can connect to the local cluster and you can run kubectl commands.

```bash
export KUBECONFIG=tmp/k3s.yaml
```

### Update hosts file for local domains

You'll need to update your `/etc/hosts` file to access the demo apps via the local domain. Instructions on how to do thisYou'll get this IP address from the output of the `setup_k3s.sh` script.

### Uninstall k3s

Run the script to uninstall k3s and remove the local cluster.

```bash
/usr/local/bin/k3s-uninstall.sh
```

### k3s References

- [k3s](https://k3s.io/)
- [k3s Documentation](https://docs.k3s.io/installation)

## Running cluster validation tests

To run the tests to validate the demo apps are working, run the following script:

```bash
./bin/run_tests.sh
```
