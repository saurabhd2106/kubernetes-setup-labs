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
   - **macOS without Homebrew**, **Linux**, or other Unix: runs Google’s official **non-interactive** installer, which installs into `~/google-cloud-sdk` by default.
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
2. If `gcloud` is still “command not found”, add Google’s path snippets to your shell profile:

   **bash** (`~/.bashrc` or `~/.bash_profile`):

   ```bash
   source "$HOME/google-cloud-sdk/path.bash.inc"
   source "$HOME/google-cloud-sdk/completion.bash.inc"
   ```

   **zsh** (`~/.zshrc`):

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
| `gcloud` not found after success | Add the `source ... path.*.inc` lines above to your shell profile, then open a new terminal. |
| Script says gcloud is already installed | You are done; use `gcloud components update` to upgrade components. |

## Next steps

- [../deploy-vm-google/AUTH_GUIDE.md](../deploy-vm-google/AUTH_GUIDE.md) — log in and grant IAM roles for Terraform.  
- [../deploy-vm-google/USER_GUIDE.md](../deploy-vm-google/USER_GUIDE.md) — deploy VMs with Terraform.
