# Single-node Kubernetes cluster on Ubuntu 24.04

A one-shot installer that turns a fresh Ubuntu 24.04 host into a working
single-node Kubernetes cluster using `kubeadm`, `containerd`, and `Flannel`.

If you want the *why* behind every step, read [GUIDE.md](GUIDE.md).

## What it installs

| Component   | Version / Source                                              |
| ----------- | ------------------------------------------------------------- |
| Kubernetes  | `v1.32` from `pkgs.k8s.io` (kubelet, kubeadm, kubectl)        |
| Runtime     | `containerd.io` from Docker's official apt repo               |
| CNI plugin  | Flannel (latest release), pod CIDR `10.244.0.0/16`            |

Optional add-ons (metrics-server, dashboard, ingress, helm) are intentionally
**not** installed.

## Prerequisites

- Ubuntu 24.04 LTS (Noble Numbat), `amd64` or `arm64`
- Minimum 2 CPU cores, 2 GB RAM, 20 GB free disk (4 GB RAM recommended)
- `sudo` / root access
- Outbound internet access to `download.docker.com`, `pkgs.k8s.io`, `registry.k8s.io`, and `github.com`
- A static IP or stable DHCP lease (the API server certificate is bound to the host's IP)

## Usage

```bash
sudo bash install-k8s.sh
```

The script is idempotent: re-running it after a successful install will skip
`kubeadm init` and just re-apply the Flannel manifest.

When it finishes you should see all `kube-system` and `kube-flannel` pods in
`Running` state and the node in `Ready` state.

## Verify the cluster

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

Run a quick smoke test:

```bash
kubectl run hello --image=nginx --port=80
kubectl get pods -w
kubectl delete pod hello
```

## Tear down / start over

```bash
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d ~/.kube /root/.kube
sudo systemctl restart containerd
```

After that you can re-run `sudo bash install-k8s.sh` to get a clean cluster.

## Troubleshooting

**`kubelet` keeps crashing right after `kubeadm init`**
Almost always a cgroup-driver mismatch. Check that
`/etc/containerd/config.toml` contains `SystemdCgroup = true` and then
`sudo systemctl restart containerd`.

**`kubeadm init` complains about swap**
Confirm swap is off: `swapon --show` should print nothing. If it doesn't,
run `sudo swapoff -a` and check `/etc/fstab` for any uncommented swap line.

**Node stays in `NotReady`**
The CNI plugin probably failed to apply. Check
`kubectl -n kube-flannel get pods` and `kubectl describe node`. A common
cause is `br_netfilter` not loaded - run `sudo modprobe br_netfilter` and
re-apply the Flannel manifest.

**`kubectl` says "connection refused" or "the server has asked for the client to provide credentials"**
Your kubeconfig is missing or pointing at the wrong cluster. Re-run:

```bash
mkdir -p ~/.kube
sudo install -m 0600 -o "$USER" -g "$USER" /etc/kubernetes/admin.conf ~/.kube/config
```

**Can't pull container images**
Check that `containerd` is running (`systemctl status containerd`) and that
the host can reach `registry.k8s.io` (`curl -I https://registry.k8s.io`).

## Files

- `install-k8s.sh` - the installer.
- `README.md` - this file.
- `GUIDE.md` - plain-language explanation of every step.
