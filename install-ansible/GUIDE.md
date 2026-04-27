# Guide: Installing Ansible on Ubuntu

This folder contains [`install-ansible.sh`](install-ansible.sh), which installs
Ansible on Ubuntu using the distribution packages. Read this if you want to
know what the script does before you run it.

---

## What you get

**What it is.** Ubuntu ships an `ansible` package (in the **Universe** software
channel). It pulls in **ansible-core** (the engine and CLI) plus the bundled
**ansible** collections set, which is what most tutorials mean by “Ansible”.

**Why apt.** You get a version that matches your Ubuntu release, integrated
with `apt` upgrades, without managing Python virtual environments on the host.

---

## How to run it

From this directory:

```bash
sudo bash install-ansible.sh
```

From the repository root:

```bash
sudo bash install-ansible/install-ansible.sh
```

You must run as **root** (for example with `sudo`), because the script uses
`apt-get` to install system packages.

---

## What each part of the script does

### Preflight

**Why.** Catches mistakes early (wrong user, unexpected OS).

**What the script does.** Exits unless the effective user is root. If
`/etc/os-release` exists, it warns if the OS is not Ubuntu or if the version is
not 24.04 (the version this was tested against); it still continues on other
Ubuntu releases.

### Install

**Why.** Refreshes package indexes and installs Ansible.

**What the script does.** Sets `DEBIAN_FRONTEND=noninteractive` so apt does not
stop for prompts, runs `apt-get update`, then `apt-get install -y ansible`.

If install fails because the package is missing, enable Universe, update, and
retry:

```bash
sudo add-apt-repository universe
sudo apt-get update
```

Then run the install script again.

### Verify

**Why.** Confirms the `ansible` command is on your `PATH` and reports a
version.

**What the script does.** Runs `ansible --version` and prints a short success
message.

---

## After installation

Use `ansible`, `ansible-playbook`, and related commands as documented in the
[Ansible documentation](https://docs.ansible.com/). This installer does not
configure inventory, SSH keys, or `sudo` on target hosts; you still set those up
for your own playbooks.
