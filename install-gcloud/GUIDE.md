# Install gcloud CLI — plain-language guide

This folder installs the **Google Cloud CLI** (`gcloud`), which you need before following [deploy-vm-google/AUTH_GUIDE.md](../deploy-vm-google/AUTH_GUIDE.md) or running Terraform against Google Cloud.

## When to use this

- You do not have `gcloud` yet, or `gcloud` is not on your `PATH`.
- You are on **macOS** or **Linux** (see Windows below).

## What the script does

1. Checks that `curl` is available.
2. If `gcloud` is already installed, it prints the version and **exits** (nothing is changed).
3. Otherwise:
   - **macOS with Homebrew**: runs `brew install --cask google-cloud-sdk`.
   - **macOS without Homebrew**, **Linux**, or other Unix: runs Google’s official **non-interactive** installer. Files usually land under `~/google-cloud-sdk/`; on many systems the real SDK is nested as `~/google-cloud-sdk/google-cloud-sdk/` (the script detects both and adds `gcloud` to `PATH` for verification).
4. Runs `gcloud --version` to confirm the install worked.

You do **not** need `sudo` for the curl-based install (it goes under your home directory). Homebrew itself may ask for your password the first time you use it.

## How to run it

From the repository root:

```bash
bash install-gcloud/install-gcloud.sh
```

Or:

```bash
cd install-gcloud
bash install-gcloud.sh
```

## After installation

1. **Open a new terminal window** (or reload your shell config) so `PATH` picks up `gcloud`.
2. If `gcloud` is still “command not found”, add Google’s path snippets to your shell profile. **Check which folder exists** — the installer often prints paths like `.../google-cloud-sdk/google-cloud-sdk/path.bash.inc` (nested). Use the same directory for both `path` and `completion` lines.

   **Nested layout** (common after the curl installer on Linux) — **bash**:

   ```bash
   source "$HOME/google-cloud-sdk/google-cloud-sdk/path.bash.inc"
   source "$HOME/google-cloud-sdk/google-cloud-sdk/completion.bash.inc"
   ```

   **Nested layout** — **zsh**:

   ```bash
   source "$HOME/google-cloud-sdk/google-cloud-sdk/path.zsh.inc"
   source "$HOME/google-cloud-sdk/google-cloud-sdk/completion.zsh.inc"
   ```

   **Flat layout** (if those files are directly under `~/google-cloud-sdk/`) — **bash**:

   ```bash
   source "$HOME/google-cloud-sdk/path.bash.inc"
   source "$HOME/google-cloud-sdk/completion.bash.inc"
   ```

   **Flat layout** — **zsh**:

   ```bash
   source "$HOME/google-cloud-sdk/path.zsh.inc"
   source "$HOME/google-cloud-sdk/completion.zsh.inc"
   ```

   (If `path.zsh.inc` does not exist, use `path.bash.inc` as a fallback.)

3. Continue with authentication in [AUTH_GUIDE.md](../deploy-vm-google/AUTH_GUIDE.md), for example:

   ```bash
   gcloud auth application-default login
   gcloud config set project YOUR_PROJECT_ID
   ```

## Ubuntu / Debian alternative (apt)

If you prefer installing from Google’s **apt** repository instead of the curl installer, follow the official steps:

https://cloud.google.com/sdk/docs/install#deb

The script in this folder does not use apt, so you do not need both.

## Windows

This shell script is for macOS and Linux. On Windows, use one of:

- **WSL** (Windows Subsystem for Linux), then run this script inside WSL, or  
- Google’s Windows installer: https://cloud.google.com/sdk/docs/install-sdk#windows

## Troubleshooting

| Problem | What to try |
|--------|--------------|
| `curl: command not found` | Install `curl` with your OS package manager, then re-run the script. |
| Homebrew install fails | Run `brew update`, then `brew install --cask google-cloud-sdk` manually. |
| Curl installer fails (firewall/proxy) | Use a network that allows `https://sdk.cloud.google.com` and `https://dl.google.com`, or install via apt (Linux) / brew (macOS). |
| `gcloud` not found after success | Prefer the **nested** `source` lines (`.../google-cloud-sdk/google-cloud-sdk/path.bash.inc`) if that path exists on disk; otherwise use the flat paths. |
| Script says gcloud is already installed | You are done; use `gcloud components update` to upgrade components. |

## Uninstall

The companion script [`uninstall-gcloud.sh`](uninstall-gcloud.sh) removes the SDK for **the user that runs it**. It is per-user by design — if you installed as `root`, run the uninstall as `root` (e.g. `sudo -i`); if you installed as `student`, run it as `student`.

```bash
# interactive (asks to confirm)
bash install-gcloud/uninstall-gcloud.sh

# non-interactive
bash install-gcloud/uninstall-gcloud.sh --yes

# remove SDK + profile lines, but keep ~/.config/gcloud (auth, ADC, configs)
bash install-gcloud/uninstall-gcloud.sh --keep-config
```

What it does:

- Removes `$HOME/google-cloud-sdk` (covers both flat and nested layouts).
- On macOS, runs `brew uninstall --cask google-cloud-sdk` if the cask is installed.
- Removes `source ".../google-cloud-sdk/(path|completion).(bash|zsh).inc"` lines from `~/.bashrc`, `~/.bash_profile`, `~/.profile`, `~/.zshrc`, `~/.zprofile`. A timestamped backup of each edited file is kept as `<file>.bak.gcloud-uninstall.<timestamp>`.
- Removes `$HOME/.config/gcloud` by default (skip with `--keep-config`).

What it does **not** do (intentionally):

- It does not remove an apt-installed package. For that:

  ```bash
  sudo apt-get remove --purge google-cloud-cli
  ```

- It does not touch other users' home directories or system paths.

If `gcloud` is still on `PATH` after uninstall, the script prints `which -a gcloud` so you can see which copy remains (typically an apt package or another user's install).

## Next steps

- [../deploy-vm-google/AUTH_GUIDE.md](../deploy-vm-google/AUTH_GUIDE.md) — log in and grant IAM roles for Terraform.  
- [../deploy-vm-google/USER_GUIDE.md](../deploy-vm-google/USER_GUIDE.md) — deploy VMs with Terraform.
