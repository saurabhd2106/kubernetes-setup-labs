# gcp_ccm role

Deploys [kubernetes/cloud-provider-gcp](https://github.com/kubernetes/cloud-provider-gcp) so `Service` resources with `type: LoadBalancer` create Google Cloud Network Load Balancers.

Enable with `enable_gcp_cloud_controller: true` in `group_vars/all.yml` and set `gcp_*` variables from `terraform output` in `deploy-vm-google/`.
