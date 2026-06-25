locals {

  public_lb_urls = {
    for region in local.compute_regions : region => module.public_load_balancers[region].lb_dns_name
  }

  ## Primary private LB target-group ARNs, by TG name. Exposed for consumers
  ## (incl. the parent wrapper's add-on zones, which resolve per-zone private TG
  ## ARNs from this + private_load_balancers_regional via child outputs).
  private_target_group_arns_by_name = module.private_load_balancer.target_group_arns_by_name

  public_target_group_arns_by_name = {
    for region in local.compute_regions :
    region => module.public_load_balancers[region].target_group_arns_by_name
  }

  public_windows_user_data = file("${local.userdata_dir}/${var.windows_userdata_file}")

  autoscale_agent_userdata = {
    for region in local.all_regions : region =>
    templatefile("${local.userdata_dir}/${var.agent_userdata_file}", {
      ADDITIONAL_AGENT_INSTALL_ARGS = var.agent_additional_install_arguments
      CUSTOMER_ENV                  = var.kasm_domain_name
      CUSTOMER_NAME                 = local.standard_customer_name
      DEPLOYMENT_DOMAIN             = var.kasm_domain_name
      DEPLOYMENT_TYPE               = var.deployment_type
      IMAGE_TYPE                    = var.image_type
      IS_DEV                        = "false"
      KASM_STIG_OVERRIDE            = var.kasm_stig_url
      KASM_VERSION                  = var.kasm_version
      KASM_DOWNLOAD_URL             = var.kasm_download_url
      MANAGER_TOKEN                 = local.manager_token
      NFS_ENABLED                   = var.deploy_nfs
      NFS_PROFILE_PATH              = var.nfs_profile_path
      NFS_URL                       = var.deploy_nfs ? module.nfs[region].nfs_url : ""
      PROJECT_NAME                  = local.standard_customer_name
      TELEPORT_VERSION              = var.teleport_version
      WAZUH_JOIN_GROUP              = var.wazuh_group
    })
  }

  cpx_userdata = {
    for region in local.all_regions : region =>
    base64encode(templatefile("${local.userdata_dir}/${var.cpx_userdata_file}", {
      ADDITIONAL_CPX_INSTALL_ARGS = var.cpx_additional_install_arguments
      CUSTOMER_ENV                = var.kasm_domain_name
      CUSTOMER_NAME               = local.standard_customer_name
      DEPLOYMENT_DOMAIN           = var.kasm_domain_name
      DEPLOYMENT_TYPE             = var.deployment_type
      IMAGE_TYPE                  = var.image_type
      IS_DEV                      = "false"
      KASM_DOWNLOAD_URL           = var.kasm_download_url
      KASM_SERVICE_TOKEN          = local.service_token
      KASM_STIG_OVERRIDE          = var.kasm_stig_url
      KASM_VERSION                = var.kasm_version
      KASM_ZONE_NAME              = var.aws_to_kasm_zone_map[region]
      PRIVATE_LB_HOSTNAME         = "${region}.${local.private_domain}"
      PROJECT_NAME                = local.standard_customer_name
      TELEPORT_VERSION            = var.teleport_version
      WAZUH_JOIN_GROUP            = var.wazuh_group
    }))
  }

  proxy_userdata = {
    for region in var.secondary_regions : region => base64encode(templatefile("${local.userdata_dir}/${var.proxy_userdata_file}", {
      ADDITIONAL_PROXY_INSTALL_ARGS = var.proxy_additional_install_arguments
      CUSTOMER_ENV                  = var.kasm_domain_name
      CUSTOMER_NAME                 = local.standard_customer_name
      DEPLOYMENT_DOMAIN             = var.kasm_domain_name
      DEPLOYMENT_TYPE               = var.deployment_type
      IS_DEV                        = "false"
      IMAGE_TYPE                    = var.image_type
      KASM_DOWNLOAD_URL             = var.kasm_download_url
      KASM_SERVICE_TOKEN            = local.service_token
      KASM_STIG_OVERRIDE            = var.kasm_stig_url
      KASM_VERSION                  = var.kasm_version
      KASM_ZONE_NAME                = var.aws_to_kasm_zone_map[region]
      PROJECT_NAME                  = local.standard_customer_name
      PUBLIC_LB_HOSTNAME            = "${region}.private.${var.kasm_domain_name}"
      REGION_PROXY_DOMAIN_NAME      = "${region}-proxy-lb.${var.kasm_domain_name}"
      TELEPORT_VERSION              = var.teleport_version
      WAZUH_SERVICE_URL             = var.wazuh_url
    }))
  }

  webapp_userdata = {
    for region in local.all_regions : region =>
    base64encode(templatefile("${local.userdata_dir}/${var.webapp_userdata_file}", {
      ADDITIONAL_WEBAPP_INSTALL_ARGS = var.webapp_additional_install_arguments
      CUSTOMER_ENV                   = var.kasm_domain_name
      CUSTOMER_NAME                  = local.standard_customer_name
      DB_ADDRESS                     = var.use_rds ? "database-${local.manager_db_target_resolved[region]}.${local.private_domain}" : local.db_private_hostname
      DEPLOYMENT_DOMAIN              = var.kasm_domain_name
      DEPLOYMENT_TYPE                = var.deployment_type
      IMAGE_TYPE                     = var.image_type
      IS_DEV                         = "false"
      KASM_DB_PASS                   = local.database_password
      KASM_DOWNLOAD_URL              = var.kasm_download_url
      KASM_STIG_OVERRIDE             = var.kasm_stig_url
      KASM_VERSION                   = var.kasm_version
      KASM_ZONE_NAME                 = var.aws_to_kasm_zone_map[region]
      PROJECT_NAME                   = local.standard_customer_name
      TELEPORT_VERSION               = var.teleport_version
      WAZUH_JOIN_GROUP               = var.wazuh_group
    }))
  }

  ## Per-LZ userdata. Mirrors regular_userdata in but
  ## KASM_ZONE_NAME comes from local.local_zone_kasm_names and DB_ADDRESS
  ## resolves through manager_db_target_resolved (which falls through the LZ's

  local_zones_cpx_userdata = {
    for lz in local.local_zone_keys : lz =>
    base64encode(templatefile("${local.userdata_dir}/${var.cpx_userdata_file}", {
      ADDITIONAL_CPX_INSTALL_ARGS = var.cpx_additional_install_arguments
      CUSTOMER_ENV                = var.kasm_domain_name
      CUSTOMER_NAME               = local.standard_customer_name
      DEPLOYMENT_DOMAIN           = var.kasm_domain_name
      DEPLOYMENT_TYPE             = var.deployment_type
      IMAGE_TYPE                  = var.image_type
      IS_DEV                      = "false"
      KASM_DOWNLOAD_URL           = var.kasm_download_url
      KASM_SERVICE_TOKEN          = local.service_token
      KASM_STIG_OVERRIDE          = var.kasm_stig_url
      KASM_VERSION                = var.kasm_version
      KASM_ZONE_NAME              = local.local_zone_kasm_names[lz]
      PRIVATE_LB_HOSTNAME         = "${lz}.${local.private_domain}"
      PROJECT_NAME                = local.standard_customer_name
      TELEPORT_VERSION            = var.teleport_version
      WAZUH_JOIN_GROUP            = var.wazuh_group
    }))
  }
  ## parent region to a cluster).
  local_zones_webapp_userdata = {
    for lz in local.local_zone_keys : lz =>
    base64encode(templatefile("${local.userdata_dir}/${var.webapp_userdata_file}", {
      ADDITIONAL_WEBAPP_INSTALL_ARGS = var.webapp_additional_install_arguments
      CUSTOMER_ENV                   = var.kasm_domain_name
      CUSTOMER_NAME                  = local.standard_customer_name
      DB_ADDRESS                     = var.use_rds ? "database-${local.manager_db_target_resolved[lz]}.${local.private_domain}" : local.db_private_hostname
      DEPLOYMENT_DOMAIN              = var.kasm_domain_name
      DEPLOYMENT_TYPE                = var.deployment_type
      IMAGE_TYPE                     = var.image_type
      IS_DEV                         = "false"
      KASM_DB_PASS                   = local.database_password
      KASM_DOWNLOAD_URL              = var.kasm_download_url
      KASM_STIG_OVERRIDE             = var.kasm_stig_url
      KASM_VERSION                   = var.kasm_version
      KASM_ZONE_NAME                 = local.local_zone_kasm_names[lz]
      PROJECT_NAME                   = local.standard_customer_name
      TELEPORT_VERSION               = var.teleport_version
      WAZUH_JOIN_GROUP               = var.wazuh_group
    }))
  }
}
