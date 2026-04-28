Source of truth for manifests is Ansible: [`roles/gcp_ccm/templates/`](../roles/gcp_ccm/templates/).

Run `ansible-playbook site.yml` with `enable_gcp_cloud_controller: true` so the master renders `/root/gcp-ccm-manifest.yaml` and applies it.
