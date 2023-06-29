# k3s for Local Development

## Install k3s

```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -
```

## Set up kubectl

```bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

## Set up dashboard

```bash
./bin/setup_dashboard.sh
```
