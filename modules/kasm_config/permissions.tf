locals {
  kasm_permissions = {
    # Internal communications
    kasm_session = {
      id          = 50
      description = "Base permissions allowed for a Kasm session (API calls made by a session container)."
    }
    agent = {
      id          = 60
      description = "Base permissions allowed for a Kasm Agent."
    }
    server_agent = {
      id          = 70
      description = "Base permissions allowed for a Server agent service."
    }
    guac = {
      id          = 80
      description = "Base permissions allowed for a Kasm Guac."
    }
    rdp_gateway = {
      id          = 90
      description = "Base permissions allowed for the rdp-gateway"
    }
    rdp_gateway_connect = {
      id          = 91
      description = "rdp-gateway Permission to allow client connection info lookup"
    }
    network_sidecar = {
      id          = 92
      description = "Base permissions allowed for a network sidecar"
    }

    # Built-in roles
    user = {
      id          = 100
      description = "Default level of permissions for normal users."
    }
    global_admin = {
      id          = 200
      description = "Global Administrator with all permissions."
    }

    # Individual permissions
    # user administration
    users_view = {
      id          = 300
      description = "View users and user information."
    }
    users_modify = {
      id          = 301
      description = "Modify existing users."
    }
    users_create = {
      id          = 302
      description = "Create new users."
    }
    users_delete = {
      id          = 303
      description = "Delete existing users."
    }
    users_modify_admin = {
      id          = 351
      description = "Modify users with root admin permissions."
    }
    users_auth_session = {
      id          = 352
      description = "Login and logout on behalf of another user."
    }

    # groups
    groups_view = {
      id          = 400
      description = "View groups, group members, and group settings."
    }
    groups_modify = {
      id          = 401
      description = "Modify group members and settings."
    }
    groups_create = {
      id          = 402
      description = "Create new groups."
    }
    groups_delete = {
      id          = 403
      description = "Delete existing groups."
    }
    groups_view_ifmember = {
      id          = 420
      description = "View groups you are a member of, excluding system groups."
    }
    groups_modify_ifmember = {
      id          = 421
      description = "Modify groups you are a member of, with the exception of group permissions and excluding system groups."
    }
    groups_view_system = {
      id          = 440
      description = "View groups, group members and group settings of system defined groups."
    }
    groups_modify_system = {
      id          = 441
      description = "Modify group members and settings of system groups."
    }
    groups_delete_system = {
      id          = 443
      description = "Delete a system group."
    }

    # agents
    agents_view = {
      id          = 500
      description = "View agents and agent settings."
    }
    agents_modify = {
      id          = 501
      description = "Modify agent settings."
    }
    agents_create = {
      id          = 502
      description = "Create agents."
    }
    agents_delete = {
      id          = 503
      description = "Delete existing agents."
    }

    # staging
    staging_view = {
      id          = 600
      description = "View staging list and stage configuration settings."
    }
    staging_modify = {
      id          = 601
      description = "Modify existing staging settings."
    }
    staging_create = {
      id          = 602
      description = "Create new staging configurations."
    }
    staging_delete = {
      id          = 603
      description = "Delete existing staging configurations."
    }

    # casting
    casting_view = {
      id          = 700
      description = "View casting list and casting configuration settings."
    }
    casting_modify = {
      id          = 701
      description = "Modify existing casting settings."
    }
    casting_create = {
      id          = 702
      description = "Create new casting configurations."
    }
    casting_delete = {
      id          = 703
      description = "Delete existing casting configurations."
    }

    # sessions
    sessions_view = {
      id          = 800
      description = "View all user sessions."
    }
    sessions_modify = {
      id          = 801
      description = "Perform modifications to a session of another user."
    }
    sessions_delete = {
      id          = 803
      description = "Delete the session of another user."
    }

    # session recordings
    session_recordings_view = {
      id          = 850
      description = "View all user session recordings"
    }

    # images
    images_view = {
      id          = 900
      description = "View images"
    }
    images_modify = {
      id          = 901
      description = "Modify image configurations."
    }
    images_create = {
      id          = 902
      description = "Create new images."
    }
    images_delete = {
      id          = 903
      description = "Delete existing images."
    }
    images_modify_resources = {
      id          = 904
      description = "Modify image resource settings, such as CPU and Memory settings."
    }

    # dev
    devapi_view = {
      id          = 1000
      description = "View developer API list."
    }
    devapi_modify = {
      id          = 1001
      description = "Modify developer API configurations."
    }
    devapi_create = {
      id          = 1002
      description = "Create a new developer API key."
    }
    devapi_delete = {
      id          = 1003
      description = "Delete an existing developer API key."
    }

    # web filter
    webfilters_view = {
      id          = 1100
      description = "View webfilters"
    }
    webfilters_modify = {
      id          = 1101
      description = "Modify existing webfilters"
    }
    webfilters_create = {
      id          = 1102
      description = "Create a new webfilter."
    }
    webfilters_delete = {
      id          = 1103
      description = "Delete an existing webfilter"
    }

    # branding
    brandings_view = {
      id          = 1200
      description = "View branding configurations."
    }
    brandings_modify = {
      id          = 1201
      description = "Modify existing branding configurations."
    }
    brandings_create = {
      id          = 1202
      description = "Create new branding configurations."
    }
    brandings_delete = {
      id          = 1203
      description = "Delete existing branding configurations."
    }

    # settings
    settings_view = {
      id          = 1300
      description = "View global settings."
    }
    settings_modify = {
      id          = 1301
      description = "Modify global settings."
    }
    settings_modify_auth = {
      id          = 1302
      description = "Modify global settings in the authentication category."
    }
    settings_modify_cast = {
      id          = 1303
      description = "Modify global settings in the casting category."
    }
    settings_modify_images = {
      id          = 1304
      description = "Modify global settings in the images category."
    }
    settings_modify_license = {
      id          = 1305
      description = "Modify global settings in the license category."
    }
    settings_modify_logging = {
      id          = 1306
      description = "Modify global settings in the logging category."
    }
    settings_modify_manager = {
      id          = 1307
      description = "Modify global settings in the manager category."
    }
    settings_modify_scale = {
      id          = 1308
      description = "Modify global settings in the scale category."
    }
    settings_modify_subscription = {
      id          = 1309
      description = "Modify global settings in the subscription category."
    }
    settings_modify_filter = {
      id          = 1310
      description = "Modify global settings in the filter category."
    }
    settings_modify_storage = {
      id          = 1311
      description = "Modify global settings in the storage category."
    }
    settings_modify_connections = {
      id          = 1312
      description = "Modify global settings in the connections category."
    }
    settings_modify_theme = {
      id          = 1313
      description = "Modify global settings in the theme category."
    }
    settings_modify_auth_captcha = {
      id          = 1314
      description = "Modify global settings in the auth_captcha category."
    }

    # auth
    auth_view = {
      id          = 1400
      description = "View LDAP/OIDC/SAML configurations."
    }
    auth_modify = {
      id          = 1401
      description = "Modify LDAP/OIDC/SAML configurations."
    }
    auth_create = {
      id          = 1402
      description = "Create LDAP/OIDC/SAML configurations."
    }
    auth_delete = {
      id          = 1403
      description = "Delete LDAP/OIDC/SAML configurations."
    }

    # license
    licenses_view = {
      id          = 1500
      description = "View licenses."
    }
    licenses_create = {
      id          = 1502
      description = "Add new licenses."
    }
    licenses_delete = {
      id          = 1503
      description = "Delete licenses."
    }

    # system
    system_view = {
      id          = 1600
      description = "View system information."
    }
    system_export_schema = {
      id          = 1604
      description = "Export system schema."
    }
    system_import_data = {
      id          = 1605
      description = "Import system data."
    }
    system_export_data = {
      id          = 1606
      description = "Export system data."
    }

    # reporting and logging
    reports_view = {
      id          = 1700
      description = "View system reports."
    }

    # managers
    managers_view = {
      id          = 1800
      description = "View the managers."
    }
    managers_modify = {
      id          = 1801
      description = "Modify existing managers."
    }
    managers_create = {
      id          = 1802
      description = "Create a new manager."
    }
    managers_delete = {
      id          = 1803
      description = "Delete existing managers."
    }

    # zones
    zones_view = {
      id          = 1900
      description = "View Zones and Zone settings."
    }
    zones_modify = {
      id          = 1901
      description = "Modify Zone settings."
    }
    zones_create = {
      id          = 1902
      description = "Create new Zones."
    }
    zones_delete = {
      id          = 1903
      description = "Delete existing Zones."
    }

    # companies
    companies_view = {
      id          = 2000
      description = "View companies."
    }
    companies_modify = {
      id          = 2001
      description = "Modify existing company."
    }
    companies_create = {
      id          = 2002
      description = "Create a new company."
    }
    companies_delete = {
      id          = 2003
      description = "Delete an existing company."
    }

    # connection proxies
    connection_proxy_view = {
      id          = 2100
      description = "View connection proxies."
    }
    connection_proxy_modify = {
      id          = 2101
      description = "Modify connection proxies."
    }
    connection_proxy_create = {
      id          = 2102
      description = "Create a connection proxy."
    }
    connection_proxy_delete = {
      id          = 2103
      description = "Delete an existing connection proxy."
    }

    # physical Tokens
    physical_tokens_view = {
      id          = 2200
      description = "View physical 2FA tokens."
    }
    physical_tokens_modify = {
      id          = 2201
      description = "Assign/Unassign physical 2FA tokens."
    }
    physical_tokens_create = {
      id          = 2202
      description = "Import or create physical 2FA tokens."
    }
    physical_tokens_delete = {
      id          = 2203
      description = "Delete a physical 2FA token."
    }

    # servers
    servers_view = {
      id          = 2300
      description = "View servers."
    }
    servers_modify = {
      id          = 2301
      description = "Modify existing servers."
    }
    servers_create = {
      id          = 2302
      description = "Create new servers."
    }
    servers_delete = {
      id          = 2303
      description = "Delete servers."
    }

    # server pools
    server_pools_view = {
      id          = 2400
      description = "View server pools."
    }
    server_pools_modify = {
      id          = 2401
      description = "Modify server pools."
    }
    server_pools_create = {
      id          = 2402
      description = "Create a new server pool."
    }
    server_pools_delete = {
      id          = 2403
      description = "Delete a server pool."
    }

    # auto scale configuration
    autoscale_view = {
      id          = 2500
      description = "View auto scale configurations."
    }
    autoscale_modify = {
      id          = 2501
      description = "Modify an existing auto scale configuration."
    }
    autoscale_create = {
      id          = 2502
      description = "Create a new auto scale configuration."
    }
    autoscale_delete = {
      id          = 2503
      description = "Delete auto scale configurations."
    }

    # VM provider
    vm_provider_view = {
      id          = 2600
      description = "View VM Provider configurations."
    }
    vm_provider_modify = {
      id          = 2601
      description = "Modify VM Provider configurations."
    }
    vm_provider_create = {
      id          = 2602
      description = "Create new VM Provider configurations."
    }
    vm_provider_delete = {
      id          = 2603
      description = "Delete VM Provider configurations."
    }

    # auto scale schedules
    autoscale_schedule_view = {
      id          = 2700
      description = "View an auto scale schedule."
    }
    autoscale_schedule_modify = {
      id          = 2701
      description = "Modify an auto scale schedule."
    }
    autoscale_schedule_create = {
      id          = 2702
      description = "Create an auto scale schedule."
    }
    autoscale_schedule_delete = {
      id          = 2703
      description = "Delete an auto scale schedule."
    }

    # DNS providers
    dns_providers_view = {
      id          = 2800
      description = "View DNS provider configurations."
    }
    dns_providers_modify = {
      id          = 2801
      description = "Modify DNS provider configurations."
    }
    dns_providers_create = {
      id          = 2802
      description = "Create new DNS Provider configurations."
    }
    dns_providers_delete = {
      id          = 2803
      description = "Delete DNS Provider configurations."
    }

    # registries
    registries_view = {
      id          = 2900
      description = "View Workspace Registries."
    }
    registries_modify = {
      id          = 2901
      description = "Modify existing Workspace Registries."
    }
    registries_create = {
      id          = 2902
      description = "Add new Workspace Registries"
    }
    registries_delete = {
      id          = 2903
      description = "Delete a Workspace Registry"
    }

    # storage providers
    storage_providers_view = {
      id          = 3000
      description = "View Storage Providers."
    }
    storage_providers_modify = {
      id          = 3001
      description = "Modify existing Storage Providers."
    }
    storage_providers_create = {
      id          = 3002
      description = "Create new Storage Providers."
    }
    storage_providers_delete = {
      id          = 3003
      description = "Delete an existing Storage Provider."
    }

    # Egress Providers
    egress_providers_view = {
      id          = 4000
      description = "View Egress Providers."
    }
    egress_providers_modify = {
      id          = 4001
      description = "Modify existing Egress Providers."
    }
    egress_providers_create = {
      id          = 4002
      description = "Create new Egress Providers."
    }
    egress_providers_delete = {
      id          = 4003
      description = "Delete an existing Egress Provider."
    }

    # Egress Gateways
    egress_gateways_view = {
      id          = 4100
      description = "View Egress Gateways"
    }
    egress_gateways_modify = {
      id          = 4101
      description = "Modify Egress Gateways"
    }
    egress_gateways_create = {
      id          = 4102
      description = "Create Egress Gateways"
    }
    egress_gateways_delete = {
      id          = 4103
      description = "Delete Egress Gateways"
    }

    # Egress Credentials
    egress_credentials_view = {
      id          = 4200
      description = "View Egress Credentials"
    }
    egress_credentials_modify = {
      id          = 4201
      description = "Modify Egress Credentials"
    }
    egress_credentials_create = {
      id          = 4202
      description = "Create Egress Credentials"
    }
    egress_credentials_delete = {
      id          = 4203
      description = "Delete Egress Credentials"
    }

    # AD User Management
    ad_user_management_view = {
      id          = 4300
      description = "View AD User Management Configurations"
    }
    ad_user_management_modify = {
      id          = 4301
      description = "Modify AD User Management Configurations"
    }
    ad_user_management_create = {
      id          = 4302
      description = "Create AD User Management Configurations"
    }
    ad_user_management_delete = {
      id          = 4303
      description = "Delete AD User Management Configurations"
    }

    # Banners
    banners_view = {
      id          = 4400
      description = "View banners."
    }
    banners_modify = {
      id          = 4401
      description = "Modify existing banners."
    }
    banners_create = {
      id          = 4402
      description = "Create new banners."
    }
    banners_delete = {
      id          = 4403
      description = "Delete existing banners."
    }

    # Server Templates
    server_templates_view = {
      id          = 4500
      description = "View server templates."
    }
    server_templates_modify = {
      id          = 4501
      description = "Modify existing server templates."
    }
    server_templates_create = {
      id          = 4502
      description = "Create new server templates."
    }
    server_templates_delete = {
      id          = 4503
      description = "Delete server templates."
    }

    # Labels
    labels_view = {
      id          = 4600
      description = "View Labels."
    }
  }
}
