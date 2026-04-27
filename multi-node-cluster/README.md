# Multi-node Kubernetes via Ansible (kubeadm)

Bring up a Kubernetes v1.32 cluster on Ubuntu 24.04 VMs deployed by the
sibling [`deploy-vm-google/`](../deploy-vm-google) Terraform module:

- **1 control-plane node** (master)
- **N worker nodes** (defined in `inventory.ini`)
- **containerd** runtime, **Calico** CNI, systemd cgroup driver
- Idempotent: re-runs are safe; tear down with `reset.yml`

For a beginner-friendly walkthrough of *why* every step exists, read
[GUIDE.md](GUIDE.md).

---

## Prerequisites

1. **VMs already created** by Terraform, all in the same VPC/subnet.
   The VM image must be Ubuntu 24.04. If you used the default
   `debian-cloud/debian-12` image, override `image` in
   `terraform.tfvars` to `ubuntu-os-cloud/ubuntu-2404-lts-amd64` (or
   `-arm64`) and re-apply.
2. **Ansible installed** on your controller machine. The repo ships a
   helper for that:

   ```bash
   sudo bash ../install-ansible/install-ansible.sh
   ```

3. **The Ansible community.general and ansible.posix collections** are
   pulled in automatically by the playbooks. If you have a sealed
   environment, install them once with:

   ```bash
   ansible-galaxy collection install community.general ansible.posix
   ```

4. **SSH access from the controller to every VM** using the keypair
   that Terraform generated (or the one you supplied).

---

## Quickstart

```bash
# 1. Move into this folder
cd multi-node-cluster

# 2. Copy the inventory template and fill in your VM IPs
cp inventory.ini.example inventory.ini
$EDITOR inventory.ini
#   - put the master's INTERNAL IP under [masters]
#   - put each worker's INTERNAL IP under [workers]
#   - point ansible_ssh_private_key_file at your key
#
# Tip: grab the IPs from Terraform:
#   cd ../deploy-vm-google && terraform output -json vm_internal_ips

# 3. Smoke-test connectivity (optional, recommended)
ansible -i inventory.ini k8s_cluster -m ping

# 4. Build the cluster
ansible-playbook site.yml
```

When the playbook finishes you'll see the node and pod listing in the
final play's debug output.

---

## Using `kubectl` from your laptop

The playbook fetches `/etc/kubernetes/admin.conf` from the master,
rewrites the `server:` URL to point at the master's reachable IP, and
saves it under `./artifacts/admin.conf`.

```bash
export KUBECONFIG=$PWD/artifacts/admin.conf
kubectl get nodes
kubectl get pods -A
```

If your master only has a private IP, you need a route to it (VPN,
bastion `ssh -L`, etc).

---

## Adding a worker later

1. Add a new line under `[workers]` in `inventory.ini`.
2. Run only that worker:

   ```bash
   ansible-playbook site.yml --limit <new-worker>,masters
   ```

   We include `masters` in the limit so the master can re-issue a
   join token for the new worker. The master's tasks are idempotent.

---

## Tearing the cluster down

```bash
ansible-playbook reset.yml
```

This runs `kubeadm reset -f` on every node, removes CNI state, kube
configs, kubelet/etcd data, flushes iptables, and restarts containerd.
Then `ansible-playbook site.yml` will build a fresh cluster.

---

## Project layout

```
multi-node-cluster/
  ansible.cfg                   # forks, fact cache, ssh pipelining
  inventory.ini.example         # copy to inventory.ini and edit
  group_vars/all.yml            # k8s version, CIDRs, CNI URL...
  site.yml                      # main playbook
  reset.yml                     # teardown playbook
  roles/
    common/                     # swap, modules, sysctl
    containerd/                 # runtime
    kube_packages/              # kubelet, kubeadm, kubectl
    control_plane/              # kubeadm init, CNI, join token
    worker/                     # kubeadm join
  artifacts/                    # admin.conf appears here after a run
```

---

## Out of scope (call-outs)

- **HA control plane** (multiple masters + LB): the layout supports it
  (`controlPlaneEndpoint` is set from day one), but only one master is
  initialised by default.
- Storage classes, Ingress controllers, metrics-server, cluster
  autoscaler, GCE cloud-controller integration: not included here.

---

## Troubleshooting

- **Node stays `NotReady`** — Calico is still rolling out. Give it
  60-90 seconds and re-check with `kubectl get pods -n kube-system`.
- **`kubeadm init` fails with swap errors** — run
  `ansible-playbook reset.yml` then re-run; the `common` role disables
  swap, but a manual `swapon` would re-enable it.
- **Worker fails to join with "couldn't validate the identity"** —
  the join token expired (24h). Re-run `ansible-playbook site.yml
  --limit <worker>,masters`.
- **Kubelet logs show cgroup driver mismatch** — your containerd
  config didn't get `SystemdCgroup = true`. Re-run the `containerd`
  role: `ansible-playbook site.yml --tags containerd` (or just re-run
  the whole playbook, it's idempotent).
