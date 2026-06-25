locals {
  default_api_configs = {
    kasm_engineering_api = {
      api_key  = "KasmRWApiKey"
      enabled  = true
      expires  = null
      name     = "Kasm Engineering Automation"
      password = var.passwords.kasm_engineering_api
      permissions = [
        "autoscale_create",
        "autoscale_delete",
        "autoscale_modify",
        "autoscale_schedule_create",
        "autoscale_schedule_delete",
        "autoscale_schedule_modify",
        "autoscale_schedule_view",
        "autoscale_view",
        "managers_view",
        "server_pools_view",
        "servers_view",
        "vm_provider_create",
        "vm_provider_delete",
        "vm_provider_modify",
        "vm_provider_view",
        "zones_view"
      ]
      read_only = false
    }
    kcs_api = {
      api_key  = "KcsReadApiKy"
      enabled  = true
      expires  = null
      name     = "Kasm Customer Support"
      password = var.passwords.kcs_api
      permissions = [
        "user",
        "users_view",
        "groups_view",
        "groups_view_ifmember",
        "groups_view_system",
        "agents_view",
        "staging_view",
        "casting_view",
        "images_view",
        "sessions_view",
        "session_recordings_view",
        "webfilters_view",
        "brandings_view",
        "settings_view",
        "auth_view",
        "licenses_view",
        "system_view",
        "reports_view",
        "managers_view",
        "zones_view",
        "companies_view",
        "connection_proxy_view",
        "physical_tokens_view",
        "servers_view",
        "server_pools_view",
        "autoscale_view",
        "vm_provider_view",
        "autoscale_schedule_view",
        "dns_providers_view",
        "registries_view",
        "storage_providers_view",
        "egress_providers_view",
        "egress_gateways_view",
        "ad_user_management_view",
        "banners_view",
        "server_templates_view",
        "labels_view"
      ]
      read_only = true
    }
  }
  all_api_configs = merge(local.default_api_configs, var.extra_api_configs)
  rdp_conn = {
    category         = "connections"
    description      = "Default connection settings for VM RDP sessions."
    name             = "default_vm_rdp_connection_settings"
    sanitize         = false
    services_restart = "api"
    title            = "Default VM RDP Connection Settings"
    value = jsonencode({
      guac = {
        type = "rdp"
        settings = {
          security                = "any"
          ignore-cert             = true
          enable-font-smoothing   = true
          enable-wallpaper        = true
          enable-theming          = true
          enable-full-window-drag = false
          enable-menu-animations  = false
          resize-method           = "display-update"
          server-layout           = "en-us-qwerty"
          printer-name            = "Kasm"
        }
      }
      kasm_svc = {
        port = 4902
      }
    })
    value_type = "json"
  }
  ssh_conn = {
    category         = "connections"
    description      = "Default connection settings for VM SSH sessions."
    name             = "default_vm_ssh_connection_settings"
    sanitize         = false
    services_restart = "api"
    title            = "Default VM SSH Connection Settings"
    value = jsonencode({
      guac = {
        type = "ssh"
        settings = {
          font-size    = 11
          color-scheme = "gray-black"
          font-name    = "monospace"
          scrollback   = 1000
        }
      }
    })
    value_type = "json"
  }
  vnc_conn = {
    category         = "connections"
    description      = "Default connection settings for VM VNC sessions."
    name             = "default_vm_vnc_connection_settings"
    sanitize         = false
    services_restart = "api"
    title            = "Default VM VNC Connection Settings"
    value = jsonencode({
      guac : {
        type : "vnc",
        settings : {
          autoretry : 5,
          color_depth : 32
        }
      }
    })
    value_type = "json"
  }

  ## Create simple lists of users and groups to create from variables
  users_to_create  = [for key, value in var.passwords : key if value != ""]
  groups_to_create = distinct(flatten([for key, value in var.default_users : value.groups if contains(local.users_to_create, key)]))

  ## Create initial uuidv5 namespace UUIDs for reuse and declarative UUID generation
  namespace_uuids = merge([{
    user  = uuid()
    admin = uuid()
    },
    { for user in local.users_to_create : user => uuid() },
    { for group in local.groups_to_create : group => uuid() if group != "all_users" },
    { all_users = var.default_groups.all_users.group_id }
  ]...)

  ## API settings to use
  api_configs = {
    for name, config in local.all_api_configs : name => merge(
      {
        for k, v in config : k => v if !contains(["password", "permissions"], k)
      },
      {
        api_id              = uuidv5(local.namespace_uuids[name], name)
        salt                = uuidv5(local.namespace_uuids[name], "password/salt")
        api_key_secret_hash = sha256("${config.password}${uuidv5(local.namespace_uuids[name], "password/salt")}")
        created             = "$${datetime:utcnow}"
      }
    )
  }

  api_keys = {
    for k, v in local.api_configs : v.api_id => local.all_api_configs[k].permissions
  }

  ## Create a list of object of the user data and add UUID for salt, user_id, and generate PW hash for user
  users = [for user, values in var.default_users : merge([{ for key, value in values : key => value if key != "groups" && lookup(local.namespace_uuids, user, null) != null && key != "index" },
    {
      user_id        = uuidv5(local.namespace_uuids[(user)], "user/id")
      salt           = uuidv5(local.namespace_uuids[(user)], "password/salt")
      pw_hash        = values.pw_hash == null ? sha256("${var.passwords[(user)]}${uuidv5(local.namespace_uuids[(user)], "password/salt")}") : values.pw_hash
      crypt_password = "$${crypt:password:${values.index}}"
      crypt_salt     = "$${crypt:salt:${values.index}}"
  }]...)]

  ## Create a list of object of the group data and add UUID for group_id to the object
  groups = [for group, values in var.default_groups : merge([{ for key, value in values : key => value if key != "settings" && key != "permissions" }, {
    group_id = group == "all_users" ? values.group_id : uuidv5(local.namespace_uuids[(group)], "group/id")
  }]...) if contains(local.groups_to_create, group)]

  ## Create a list of maps associating users with groups and generating UUIDs
  user_groups = flatten([for key, value in var.default_users : [
    for group in value.groups : {
      group_id      = group != "all_users" ? uuidv5(local.namespace_uuids[(group)], "group/id") : local.namespace_uuids[(group)]
      user_group_id = uuid()
      user_id       = uuidv5(local.namespace_uuids[(key)], "user/id")
    } if contains(keys(local.namespace_uuids), key)
  ]])

  api_permissions = flatten([for key, value in local.api_keys : [
    for permission in value : {
      api_id              = key
      group_id            = null
      group_permission_id = uuid()
      permission_id       = local.kasm_permissions[(permission)].id
    }
  ]])

  group_permissions = flatten([for key, value in var.default_groups : [
    for permission in value.permissions : {
      api_id              = null
      group_id            = key != "all_users" ? uuidv5(local.namespace_uuids[(key)], "group/id") : local.namespace_uuids[(key)]
      group_permission_id = uuid()
      permission_id       = local.kasm_permissions[(permission)].id
    }
    ] if contains(keys(local.namespace_uuids), key)
  ])

  all_permissions = flatten([local.api_permissions, local.group_permissions])

  ## Kasm default Global settings
  system_settings = concat([for key, value in var.global_settings : merge(value, {
    name  = (key)
    value = (var.disable_db_logging && key == "log_retention") ? "0" : value.value
  })], [local.rdp_conn, local.ssh_conn, local.vnc_conn])

  ## Map group settings to settings values
  group_settings = flatten([[for key, setting in var.group_settings : {
    description      = setting.description
    group_id         = null
    group_setting_id = uuid()
    name             = key
    value            = setting.value
    value_type       = setting.value_type
    }],
    [for key, value in var.default_groups : [
      for val, setting in value.settings : {
        description      = var.group_settings[(val)].description
        group_id         = key != "all_users" ? uuidv5(local.namespace_uuids[(key)], "group/id") : local.namespace_uuids[(key)]
        group_setting_id = uuid()
        name             = val
        value            = setting.value
        value_type       = setting.value_type
      }
    ] if value.settings != null && contains(keys(local.namespace_uuids), key)]
  ])

  ## Add Branding ID UUIDs
  full_branding_configs = var.branding_configs == null ? [] : [for config in var.branding_configs : merge([{
    branding_config_id = uuid()
    },
    var.branding_configs
  ]...)]

  ## Generate SAML ID UUIDs for use in saml_configs and sso_attribute_userfield_mapping
  saml_configs = var.saml_configs == null ? [] : [for config in var.saml_configs : merge([{
    saml_id = uuid()
    }, {
    for key, value in config : key => value if key != "sso_attribute_mapping"
    }
  ]...)]

  sso_attribute_userfield_mapping = length(local.saml_configs) == 0 ? [] : length(var.saml_configs[*].sso_attribute_mapping) == 0 ? [] : flatten([for index, config in var.saml_configs : [
    for key, value in config.sso_attribute_mapping : merge([{
      saml_id = local.saml_configs[index].saml_id
      ldap_id = null
      oidc_id = null
    }, value]...)
  ]])

  ## Storage provider configs
  storage_providers = var.storage_providers == null ? [] : [for config in var.storage_providers : merge([{
    storage_provider_id = uuid()
    }, config]...) if contains(var.provider_types, config.storage_provider_type)
  ]

  base_autoscale_config_id = uuid()
  autoscale_configs = {
    for autoscale_name, autoscale_value in var.autoscale_configs : autoscale_name => merge(
      autoscale_value,
      {
        autoscale_config_id   = uuidv5(local.base_zone_id, autoscale_name),
        autoscale_config_name = autoscale_name
        oci_vm_config_id      = local.oci_vm_configs[autoscale_value.oci_vm_config_id].config_id
        server_pool_id        = local.server_pools[autoscale_value.server_pool_id].server_pool_id
        zone_id               = local.zone_configs[autoscale_value.zone_id].zone_id
      }
    )
  }

  base_oci_vm_config_id = uuid()
  oci_vm_configs = {
    for config_name, config_value in var.oci_vm_configs : config_name => merge(
      config_value,
      {
        config_id   = uuidv5(local.base_zone_id, config_name),
        config_name = config_name
      }
    )
  }

  base_server_pool_id = uuid()
  server_pools = {
    for server_pool_name, server_pool_config in var.server_pools : server_pool_name => {
      server_assignment_enabled = false
      server_pool_id            = uuidv5(local.base_server_pool_id, server_pool_name)
      server_pool_name          = server_pool_name
      server_pool_type          = server_pool_config.type
    }
  }

  base_zone_id = uuid()
  zone_configs = {
    for zone_name, zone_info in var.zone_config : zone_name => merge(
      zone_info,
      {
        zone_id = uuidv5(local.base_zone_id, zone_name)
      }
    )
  }



  ## Combine all locals and variables to generate default_properties.yaml
  kasm_custom_default_properties = {
    alembic_version                 = var.alembic_version
    groups                          = local.groups
    group_permissions               = local.all_permissions
    group_settings                  = local.group_settings
    api_configs                     = values(local.api_configs)
    registries                      = var.registries
    settings                        = local.system_settings
    users                           = local.users
    user_groups                     = local.user_groups
    branding_configs                = local.full_branding_configs
    saml_configs                    = local.saml_configs
    sso_attribute_userfield_mapping = local.sso_attribute_userfield_mapping
    storage_providers               = local.storage_providers
    autoscale_configs               = values(local.autoscale_configs)
    cast_configs                    = []
    filter_policies                 = []
    group_images                    = []
    images                          = []
    oci_vm_configs                  = values(local.oci_vm_configs)
    oidc_configs                    = []
    staging_configs                 = []
    servers                         = []
    server_pools                    = values(local.server_pools)
    zones                           = values(local.zone_configs)
  }
}
