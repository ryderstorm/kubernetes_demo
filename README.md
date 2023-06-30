# Kubernetes Demo

## Requirements

WIP

## Deploying a Kubernetes cluster using Terraform and AWS EKS

WIP

## Using k3s for Local Development

k3s is a lightweight Kubernetes distribution. It is a single binary that provides a fully compliant Kubernetes API server and Kubernetes controller components. This project uses k3s to provide a local development environment for Kubernetes.

### Install and set up local k3s cluster

Run the `setup_k3s.sh` script to install k3s and set up the local cluster.

```bash
./bin/setup_k3s.sh
```

## Set up kubectl

Ensure that the `KUBECONFIG` environment variable is set to the location of the k3s configuration file so that kubectl can connect to the local cluster.

```bash
export KUBECONFIG=tmp/k3s.yaml
```

## Set up Traefik and demo apps

Run the script that installs Traefik and the demo apps via `helm` and `kubectl`.

```bash
./bin/deploy_apps_to_k8s.sh
```

## Uninstall k3s

Run the `uninstall_k3s.sh` script to uninstall k3s and remove the local cluster.

```bash
/usr/local/bin/k3s-uninstall.sh
```

## References

- [k3s](https://k3s.io/)
- [k3s Documentation](https://docs.k3s.io/installation)
