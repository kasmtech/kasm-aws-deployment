#######################################
##                                   ##
##        Deployment Variables       ##
##                                   ##
#######################################
variable "domain_name" {
  description = "The domain name to use for your Kasm deployment - used when creating a new DNS zone"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+([\\-\\.]{1}[a-z0-9]+)*\\.[a-z]{2,6}", var.domain_name))
    error_message = "There are invalid characters in the kasm_domain_name - it must be a valid domain name."
  }
}

/*
 * Default Properties config settings
 */
variable "alembic_version" {
  description = "The Alembic version of the database schema to use for this configuration"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{12}$", var.alembic_version))
    error_message = "The alembic_version variable can only be a 12 character string consisting of lower-case letters and numbers and must match the Kasm Version you wish to install."
  }
}

variable "disable_db_logging" {
  description = "When true, sets the log_retention global setting to 0 to disable Kasm database log retention."
  type        = bool
  default     = false
}

variable "passwords" {
  description = "Passwords for default accounts"
  type = object({
    kasm_engineering_api = string
    kcs_api              = string
    site_admin           = optional(string, "")
    workspace_admin      = optional(string, "")
    system_admin         = optional(string, "")
  })
}

variable "extra_api_configs" {
  description = "Custom API configuration values"
  type = map(object({
    api_key             = string
    name                = string
    api_key_secret_hash = string
    permissions         = optional(list(string), [])
    expires             = optional(string, null)
    enabled             = optional(bool, true)
    read_only           = optional(bool, true)
  }))
  default = {}
}

variable "global_settings" {
  description = "Kasm user/group settings"
  type = map(object({
    category         = string
    description      = string
    sanitize         = bool
    services_restart = string
    title            = string
    value            = string
    value_type       = string
  }))

  default = {
    add_images_to_default_group = {
      category         = "images"
      description      = "Automatically add images to default group when new images are added."
      sanitize         = false
      services_restart = null
      title            = "Add Images to Default Group"
      value            = "True"
      value_type       = "bool"
    }
    agent_version = {
      category         = "manager"
      description      = "This setting is used to restrict which versions of the Kasm Agent are allowed to communicate with the Manager."
      sanitize         = false
      services_restart = null
      title            = "Agent Version"
      value            = "1"
      value_type       = "string"
    }
    anonymous_user_expiration = {
      category         = "auth"
      description      = "If configured, anonymous user accounts will be automatically deleted after this amount of time specified in hours."
      sanitize         = false
      services_restart = null
      title            = "Anonymous User Expiration (hours)"
      value            = "8"
      value_type       = "float"
    }
    api_private_key = {
      category         = "auth"
      description      = "Private Key used to sign request between Kasm components."
      sanitize         = true
      services_restart = null
      title            = "API Private Key"
      value            = "$${rsa:1:private}"
      value_type       = "multiline_string"
    }
    api_public_cert = {
      category         = "auth"
      description      = "Public key used by Kasm components to validate internal API calls."
      sanitize         = false
      services_restart = null
      title            = "API Public Cert"
      value            = "$${rsa:1:public}"
      value_type       = "multiline_string"
    }
    api_token_lifespan_seconds = {
      category         = "auth"
      description      = "Lifespan of the service tokens used to authenticate requests between back end services. Default value is 259200 seconds, or 3 days."
      sanitize         = false
      services_restart = null
      title            = "API Token Lifespan"
      value            = "259200"
      value_type       = "int"
    }
    api_token_refresh_leeway_seconds = {
      category         = "auth"
      description      = "Refresh window for the service tokens used to authenticate requests between back end services. If you expect to shut down agents or services for some time, this value can be set higher to allow services to refresh their tokens automatically. Default value is 259200 seconds, or 3 days."
      sanitize         = false
      services_restart = null
      title            = "API Token Refresh Leeway"
      value            = "259200"
      value_type       = "int"
    }
    auto_agent = {
      category         = "scale"
      description      = "Automatically enable an agent when it calls in."
      sanitize         = false
      services_restart = null
      title            = "Automatically Enable Agents"
      value            = "False"
      value_type       = "bool"
    }
    captcha_selection = {
      category         = "auth_captcha"
      description      = "Set the CAPTCHA type to use"
      sanitize         = false
      services_restart = null
      title            = "Select CAPTCHA Type"
      value            = "google"
      value_type       = "select"
    }
    cleanup_orphaned_autoscale_servers = {
      category         = "scale"
      description      = "If the system is interrupted or errors during AutoScaling a server can be partially provisioned and the system may lose track of the server orphaning it. This consumes resources that the system cannot provision on. Enabling this setting allows the system to use heuristics to find and destroy orphaned resources."
      sanitize         = false
      services_restart = null
      title            = "Cleanup Orphaned AutoScale Servers"
      value            = "True"
      value_type       = "bool"
    }
    debug_retention = {
      category         = "logging"
      description      = "Number of local Kasm debug logs to retain. WARNING - See Kasm documentation before adjusting."
      sanitize         = false
      services_restart = null
      title            = "Debug Log Retention"
      value            = "300000"
      value_type       = "int"
    }
    enable_experimental_features = {
      category         = "experimental_features"
      description      = "Enable experimental features"
      sanitize         = false
      services_restart = null
      title            = "Enable Experimental Features"
      value            = "False"
      value_type       = "bool"
    }
    default_cpu_allocation_method = {
      category         = "images"
      description      = "Sets the default cpu allocation strategy for container images. Valid options are Quotas or Shares."
      sanitize         = false
      services_restart = null
      title            = "Default CPU Allocation Method"
      value            = "Shares"
      value_type       = "string"
    }
    enable_kasm_auth = {
      category         = "auth"
      description      = "Require client requests to the Kasm for content such as downloads and uploads to be authenticated with the user's current session token."
      sanitize         = false
      services_restart = null
      title            = "Enable Kasm Authorization"
      value            = "True"
      value_type       = "bool"
    }
    forward_inter_zone_agent_requests = {
      category         = "scale"
      description      = "When contacting Agents in a different zone, forward requests through the alternate Zone's proxy address."
      sanitize         = false
      services_restart = null
      title            = "Forward Inter-Zone Agent Requests"
      value            = "False"
      value_type       = "bool"
    }
    google_recaptcha_api_url = {
      category         = "auth_captcha"
      description      = "Google reCAPTCHA API URL."
      sanitize         = false
      services_restart = null
      title            = "Google reCAPTCHA API URL"
      value            = "https://www.google.com/recaptcha/api/siteverify"
      value_type       = "string"
    }
    google_recaptcha_priv_key = {
      category         = "auth_captcha"
      description      = "Google reCAPTCHA Private Key."
      sanitize         = true
      services_restart = null
      title            = "Google reCAPTCHA Private Key"
      value            = "changeme"
      value_type       = "password"
    }
    google_recaptcha_site_key = {
      category         = "auth_captcha"
      description      = "Google reCAPTCHA Site Key."
      sanitize         = false
      services_restart = null
      title            = "Google reCAPTCHA Site Key"
      value            = "changeme"
      value_type       = "string"
    }
    guardian_interval = {
      category         = "scale"
      description      = "The number of seconds between the Manager API inspection of existing Agent, and Kasm availability."
      sanitize         = false
      services_restart = null
      title            = "Guardian Interval"
      value            = "15"
      value_type       = "int"
    }
    guardian_provision_threads = {
      category         = "scale"
      description      = "The number of threads the Manager API server uses for teardown and provision tasks."
      sanitize         = false
      services_restart = null
      title            = "Guardian Provision Threads"
      value            = "10"
      value_type       = "int"
    }
    hec_token = {
      category         = "logging"
      description      = "The Splunk HEC token used for authentication of logs to a Splunk server."
      sanitize         = true
      services_restart = "manager,api"
      title            = "Splunk HEC Token"
      value            = "None"
      value_type       = "password"
    }
    host_dead_expiration = {
      category         = "scale"
      description      = "The number of seconds since an Agent's last check-in before marking it as dead. Dead servers are automatically destroyed if they were dynamically provisioned."
      sanitize         = false
      services_restart = null
      title            = "Host Dead Expiration"
      value            = "3600"
      value_type       = "int"
    }
    host_missing_expiration = {
      category         = "scale"
      description      = "The number of seconds since an Agent's last check-in before marking it as dead."
      sanitize         = false
      services_restart = null
      title            = "Host Missing Expiration"
      value            = "600"
      value_type       = "int"
    }
    component_dead_expiration = {
      category         = "scale"
      description      = "Automatically delete components that fail to check in within this timeframe, a value of 0 disables this feature."
      sanitize         = false
      services_restart = null
      title            = "Component Dead Expiration"
      value            = "0"
      value_type       = "int"
    }
    component_missing_expiration = {
      category         = "scale"
      description      = "Change components to a Missing status after they fail to check in within this timeframe."
      sanitize         = false
      services_restart = null
      title            = "Component Missing Expiration"
      value            = "600"
      value_type       = "int"
    }
    http_method = {
      category         = "logging"
      description      = "HTTP method to use, valid values are post and put. Splunk uses POST while ElasticSearch API uses PUT"
      sanitize         = false
      services_restart = "manager,api"
      title            = "HTTP Method"
      value            = "post"
      value_type       = "string"
    }
    https_insecure = {
      category         = "logging"
      description      = "Set to true if the remote logging server does not have a valid signed cert by a public certificate authority."
      sanitize         = false
      services_restart = "manager,api"
      title            = "Disable Log Certificate Validation"
      value            = "True"
      value_type       = "bool"
    }
    kasm_auth_domain = {
      category         = "auth"
      description      = "Override the domain used in the Kasm session cookie."
      sanitize         = false
      services_restart = null
      title            = "Kasm Authorization Domain"
      value            = "$request_host$"
      value_type       = "string"
    }
    keepalive_expiration = {
      category         = "scale"
      description      = "Clients regularly send keepalive requests when logged into a Kasm. This value is the number of seconds a Kasm will remain active after the last keepalive is received."
      sanitize         = false
      services_restart = null
      title            = "Keep Alive Expiration"
      value            = "3600"
      value_type       = "int"
    }
    knowledgebase_url = {
      category         = "knowledgebase"
      description      = "knowledgebase url."
      title            = "knowledgebase_url"
      value            = "https://kb.kasmweb.com"
      sanitize         = false
      services_restart = null
      value_type       = "string"
    }
    launcher_background_url = {
      category         = "theme"
      description      = "Url used to specify the background image for the launcher."
      sanitize         = false
      services_restart = null
      title            = "Launcher Background URL"
      value            = "img/backgrounds/background1.jpg"
      value_type       = "string"
    }
    license_server_url = {
      category         = "licensing"
      description      = "The URL to the Kasm Licensing Server."
      sanitize         = false
      services_restart = null
      title            = "License Server URL"
      value            = "https://license.kasmweb.com"
      value_type       = "string"
    }
    log_host = {
      category         = "logging"
      description      = "The hostname or IP address of the remote logging server, not applicable for internal logging."
      sanitize         = false
      services_restart = "manager,api"
      title            = "Log Host"
      value            = "None"
      value_type       = "string"
    }
    log_port = {
      category         = "logging"
      description      = "The port to use for logging communication."
      sanitize         = false
      services_restart = "manager,api"
      title            = "Log Port"
      value            = "443"
      value_type       = "int"
    }
    log_protocol = {
      category         = "logging"
      description      = "The logging protocol used, allowed values are internal, https, splunk, and elasticsearch"
      sanitize         = false
      services_restart = "manager,api"
      title            = "Log Protocol"
      value            = "internal"
      value_type       = "string"
    }
    log_retention = {
      category         = "logging"
      description      = "Number of local Kasm logs to retain. WARNING - See Kasm documentation before adjusting."
      sanitize         = false
      services_restart = null
      title            = "Log Retention"
      value            = "400000"
      value_type       = "int"
    }
    login_assistance = {
      category         = "auth"
      description      = "Enables a Login Assitance link on the login page to the entered URL. Not shown if value is empty."
      sanitize         = false
      services_restart = null
      title            = "Login Assistance"
      value            = null
      value_type       = "String"
    }
    manager_expiration = {
      category         = "manager"
      description      = "The number of seconds until the manager is considered permantly unavaiable, at which time the manager record will be removed from the database. A value of 0 disables the expiration check."
      sanitize         = false
      services_restart = "manager"
      title            = "Manager Expiration"
      value            = "0"
      value_type       = "int"
    }
    max_login_attempts = {
      category         = "auth"
      description      = "The number of invalid login attempts before an account is locked out. This setting only applies to local accounts."
      sanitize         = false
      services_restart = null
      title            = "Max Login Attempts"
      value            = "5"
      value_type       = "int"
    }
    minimize_local_logging = {
      category         = "logging"
      description      = "When using a remote logging solution like Splunk, minimize local database logging for better scalability."
      sanitize         = false
      services_restart = "manager"
      title            = "Minimize Local logging"
      value            = "False"
      value_type       = "bool"
    }
    notice_message = {
      category         = "auth"
      description      = "Login notice banner message."
      sanitize         = false
      services_restart = null
      title            = "Notice Message"
      value            = null
      value_type       = "multiline_string"
    }
    notice_title = {
      category         = "auth"
      description      = "Login notice title."
      sanitize         = false
      services_restart = null
      title            = "Notice Title"
      value            = "Notice"
      value_type       = "string"
    }
    object_storage_key = {
      category         = "storage"
      description      = "The object storage (S3) access key ID for S3-based persistent profiles"
      sanitize         = false
      services_restart = "api"
      title            = "Object Storage Access Key ID"
      value            = null
      value_type       = "string"
    }
    object_storage_secret = {
      category         = "storage"
      description      = "The object storage (S3) access key secret for S3-based persistent profiles"
      sanitize         = true
      services_restart = "api"
      title            = "Object Storage Access Key Secret"
      value            = null
      value_type       = "password"
    }
    primary_manager_timeout = {
      category         = "manager"
      description      = "The number of seconds until the primary manager is considered unavailable. If other managers are alive one will take over the primary role."
      sanitize         = false
      services_restart = "manager"
      title            = "Primary Manager Timeout"
      value            = "900"
      value_type       = "int"
    }
    provision_timeout = {
      category         = "scale"
      description      = "The maximum amount of time to wait for auto-scaled VMs to check-in and become available. After this time is exceeded, the VM is automatically destroyed."
      sanitize         = false
      services_restart = null
      title            = "Provision Timeout"
      value            = "600"
      value_type       = "int"
    }
    proxy_path = {
      category         = "proxy"
      description      = "If using reverse provy via a path, set the path here."
      title            = "Proxy Path"
      sanitize         = false
      services_restart = null
      value            = ""
      value_type       = "string"
    }
    rdp_jwt_expiration = {
      category         = "connections"
      description      = "Expiration time for RDP client connection token."
      sanitize         = false
      services_restart = null
      title            = "RDP Client Connection Token Expiration"
      value            = "5"
      value_type       = "int"
    }
    rdp_private_jwt_key = {
      category         = "connections"
      description      = "Private key used to sign requests between RDP proxy and Kasm."
      sanitize         = true
      services_restart = null
      title            = "RDP File Signing Private Key"
      value            = "$${ec:1:private}"
      value_type       = "multiline_string"
    }
    rdp_private_key = {
      category         = "connections"
      description      = "Private Key used to sign RDP connection files."
      sanitize         = true
      services_restart = null
      title            = "RDP File Signing Private Key"
      value            = "$${signing:1:private}"
      value_type       = "multiline_string"
    }
    rdp_public_jwt_cert = {
      category         = "connections"
      description      = "Public key used by RDP proxy to validate internal API calls."
      sanitize         = false
      services_restart = null
      title            = "RDP Public Cert"
      value            = "$${ec:1:public}"
      value_type       = "multiline_string"
    }
    rdp_signer_cert = {
      category         = "connections"
      description      = "Signing certificate for signing RDP files."
      sanitize         = false
      services_restart = null
      title            = "RDP File Signing Cert"
      value            = "$${signing:1:certificate}"
      value_type       = "multiline_string"
    }
    recording_object_storage_key = {
      category         = "session_recording"
      description      = "Object storage (S3) access key ID. This ID is specific for session recording purposes."
      sanitize         = false
      services_restart = null
      title            = "Object Storage Access Key ID"
      value            = null
      value_type       = "string"
    }
    recording_object_storage_secret = {
      category         = "session_recording"
      description      = "Object Storage Access Key Secret. This secret is specific for session recording purposes."
      sanitize         = true
      services_restart = null
      title            = "Object Storage Access Key Secret"
      value            = null
      value_type       = "password"
    }
    registration_token = {
      category         = "auth"
      description      = "Token used to self-register new components to the deployment."
      sanitize         = false
      services_restart = null
      title            = "Component Registration Token"
      value            = "$${random_token:registration_token}"
      value_type       = "password"
    }
    same_site = {
      category         = "auth"
      description      = "Configures the SameSite attribute for the Set-Cookie HTTP response headers. Valid options are Lax, Strict and None."
      sanitize         = false
      services_restart = "api"
      title            = "Same Site Cookie Policy"
      value            = "Lax"
      value_type       = "string"
    }
    same_zone_reply = {
      category         = "manager"
      description      = "If set to true, a manager will only reply to agent heartbeats with a list of managers in the same zone as itself. Otherwise a list of all managers is given. This allows Agents to failover to managers in other zones."
      sanitize         = false
      services_restart = "manager"
      title            = "Same Zone Reply"
      value            = "True"
      value_type       = "bool"
    }
    session_lifetime = {
      category         = "auth"
      description      = "The number of seconds a session token is valid for."
      sanitize         = false
      services_restart = null
      title            = "Session Lifetime"
      value            = "288000"
      value_type       = "int"
    }
    session_recording_bitrate = {
      category         = "session_recording"
      description      = "Bitrate for session recording (in Mbps), affects the quality of the recording."
      sanitize         = false
      services_restart = null
      title            = "Session Recording Bitrate"
      value            = 8
      value_type       = "int"
    }
    session_recording_framerate = {
      category         = "session_recording"
      description      = "Framerate for session recording, changes how many frames (or screen captures) are taken per second."
      sanitize         = false
      services_restart = null
      title            = "Session Recording Framerate"
      value            = 2
      value_type       = "int"
    }
    session_recording_guac_disk_limit = {
      category         = "session_recording"
      description      = "The disk storage limit for RDP, VNC, and SSH sessions in percentage of consumed disk space before session recording will not function."
      sanitize         = false
      services_restart = null
      title            = "Disk Usage Limit for Session Recordings"
      value            = 0.9
      value_type       = "float"
    }
    session_recording_queue_length = {
      category         = "session_recording"
      description      = "Queue length for session recording, how many recording clips are being processed and uploaded at once. Applies to RDP, VNC, and SSH sessions."
      sanitize         = false
      services_restart = null
      title            = "Session Recording Queue Length"
      value            = 2
      value_type       = "int"
    }
    session_recording_res_height = {
      category         = "session_recording"
      description      = "Height for session recording, the number of pixels in height the recording will be (larger numbers give more detail)."
      sanitize         = false
      services_restart = null
      title            = "Session Recording Height"
      value            = 480
      value_type       = "int"
    }
    session_recording_res_width = {
      category         = "session_recording"
      description      = "Width for session recording, the number of pixels in width the recording will be (larger numbers give more detail)."
      sanitize         = false
      services_restart = null
      title            = "Session Recording Width"
      value            = 720
      value_type       = "int"
    }
    session_recording_retention_period = {
      category         = "session_recording"
      description      = "Retention period (in hours) for session recording, how long the connection proxy will continue to try and upload session recording clips that fail to upload. Applies to RDP, VNC, and SSH sessions."
      sanitize         = false
      services_restart = null
      title            = "Session Recording Retention Period"
      value            = 24
      value_type       = "int"
    }
    session_recording_upload_location = {
      category         = "session_recording"
      description      = "Upload location for session recording, this should be an s3 bucket, with a folder path that ends is a filename with the .mp4 extension. A range of variable substitutions are available, check the Kasm documentation for details."
      sanitize         = false
      services_restart = null
      title            = "Session Recording Upload Location"
      value            = null
      value_type       = "string"
    }
    token = {
      category         = "manager"
      description      = "An authentication token used in the communication between Kasm Agents and the Manager API server."
      sanitize         = false
      services_restart = "manager"
      title            = "Token"
      value            = "$${random_token:manager_token}"
      value_type       = "password"
    }
    token_drift_max = {
      category         = "auth"
      description      = "How many minutes should a TOTP token be allowed to drift."
      sanitize         = false
      services_restart = null
      title            = "Token Drift"
      value            = "1"
      value_type       = "int"
    }
    update_check = {
      category         = "manager"
      description      = "This Setting will stop the manager from checking for Kasm system updates."
      sanitize         = false
      services_restart = null
      title            = "Update Check"
      value            = "True"
      value_type       = "bool"
    }
    url_endpoint = {
      category         = "logging"
      description      = "The Splunk endpoint, most likely /service/collector/event. For ElasticSearch it would be index/_doc/."
      sanitize         = false
      services_restart = "manager,api"
      title            = "URL Endpoint"
      value            = "/services/collector/event"
      value_type       = "string"
    }
    web_filter_update_url = {
      category         = "web_filter"
      description      = "Url used to updated the Web Filter Categorization database"
      sanitize         = false
      services_restart = "api"
      title            = "Web Filter Update URL"
      value            = "https://filter.kasmweb.com"
      value_type       = "string"
    }
    webauthn_request_lifetime = {
      category         = "auth"
      description      = "This configures the length of time in seconds the user has to respond to a webauthn authentication or registration prompt before it expires."
      sanitize         = false
      services_restart = "api,manager"
      title            = "WebAuthn request lifetime (seconds)"
      value            = "900"
      value_type       = "int"
    }
    egress_plugin_update_url = {
      category         = "egress_plugin"
      description      = "Url used to update Egress Plugin Information"
      sanitize         = false
      services_restart = "manager"
      title            = "Egress Plugin Update URL"
      value            = "https://egress-api.kasmweb.com"
      value_type       = "string"
    }
    egress_plugin_update_check = {
      category         = "egress_plugin"
      description      = "This Setting will stop the manager from checking for Egress Plugin Updates."
      sanitize         = false
      services_restart = "manager"
      title            = "Egress Plugin Update Check"
      value            = "True"
      value_type       = "bool"
    }
  }
}

variable "group_settings" {
  description = "Default Group settings values for Kasm deployment"
  type = map(object({
    description = string
    value       = string
    value_type  = string
    group_id    = optional(string, null)
  }))

  default = {
    allow_kasm_smart_card_passthrough = {
      description = "When true, users can passthrough a smart card device to the target machine."
      name        = "allow_kasm_smart_card_passthrough"
      value       = "False"
      value_type  = "bool"
    }
    allow_2fa_self_enrollment = {
      description = "Allow users to self enroll two factor devices in the profile settings page when enabled."
      name        = "allow_2fa_self_enrollment"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_audio = {
      description = "Allow audio streaming for a Kasm."
      name        = "allow_kasm_audio"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_clipboard_down = {
      description = "Allows users to paste text from the Kasm to their local computer."
      name        = "allow_kasm_clipboard_down"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_clipboard_seamless = {
      description = "Allows users to copy and paste text without using Kasm control panel."
      name        = "allow_kasm_clipboard_seamless"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_clipboard_up = {
      description = "Allow users to paste from their local computer to the Kasm."
      name        = "allow_kasm_clipboard_up"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_delete = {
      description = "If enabled, users are allowed to delete their running sessions."
      name        = "allow_kasm_delete"
      value       = "True"
      value_type  = "bool"
    }
    allow_kasm_force_delete = {
      description = "If enabled, users are allowed to force-delete sessions that are stuck in the deleting state."
      name        = "allow_kasm_force_delete"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_downloads = {
      description = "Allow users to download files from a Kasm."
      name        = "allow_kasm_downloads"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_gamepad = {
      description = "Allow gamepad passthrough to a Kasm."
      name        = "allow_kasm_gamepad"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_microphone = {
      description = "Allow microphone passthrough to a Kasm."
      name        = "allow_kasm_microphone"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_pause = {
      description = "If enabled, users are allowed to pause their running sessions."
      name        = "allow_kasm_pause"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_printing = {
      description = "Allows users to print documents using their local printers."
      name        = "allow_kasm_printing"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_rdp_client_file_transfer_clipboard = {
      description = "Allows users to copy and paste files via the clipboard in RDP Client sessions."
      name        = "allow_kasm_rdp_client_file_transfer_clipboard"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_rdp_map_local_drives = {
      description = "When true, users can map drives from their client to the target RDP machine."
      name        = "allow_kasm_rdp_map_local_drives"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_rdp_smart_card_passthrough = {
      description = "When true, users can passthrough a smart card device to the target RDP machine."
      name        = "allow_kasm_rdp_smart_card_passthrough"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_rdp_webauthn_passthrough = {
      description = "When true, webauthn requests on the RDP host are passed back to the client."
      name        = "allow_kasm_rdp_webauthn_passthrough"
      value       = "False"
      value_type  = "bool"
    }
    allow_login_kasm_rdp = {
      description = "When true, users can connect to the Kasm URL using an RDP client and their Kasm credentials without a web browser. Requires at least one deployment zone to have direct RDP log in enabled as well."
      name        = "allow_login_kasm_rdp"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_sharing = {
      description = "Allow the user to share access to Kasms with other users."
      name        = "allow_kasm_sharing"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_stop = {
      description = "If enabled, users are allowed to stop their running sessions."
      name        = "allow_kasm_stop"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_uploads = {
      description = "Allow users to upload files to a Kasm."
      name        = "allow_kasm_uploads"
      value       = "False"
      value_type  = "bool"
    }
    allow_kasm_webcam = {
      description = "Allow webcam passthrough to a Kasm."
      name        = "allow_kasm_webcam"
      value       = "False"
      value_type  = "bool"
    }
    allow_persistent_profile = {
      description = "Allow the use of persistent profiles if configured on the Kasm Image."
      name        = "allow_persistent_profile"
      value       = "False"
      value_type  = "bool"
    }
    "allow_totp_2fa" = {
      description = "Allows TOTP two-factor key authentication for group."
      name        = "allow_totp_2fa"
      value       = "True"
      value_type  = "bool"
    }
    allow_user_storage_mapping = {
      description = "Allow storage mappings defined on/by the user."
      name        = "allow_user_storage_mapping"
      value       = "False"
      value_type  = "bool"
    }
    "allow_webauthn_2fa" = {
      description = "Allows WebAuthn two-factor key authentication for group."
      name        = "allow_webauthn_2fa"
      value       = "True"
      value_type  = "bool"
    }
    allow_zone_selection = {
      description = "Allow the user to specify the deployment Zone for applicable Images."
      name        = "allow_zone_selection"
      value       = "False"
      value_type  = "bool"
    }
    auto_add_local_users = {
      description = "When enabled, local users will automatically be added to this group when created and upon each authentication."
      name        = "auto_add_local_users"
      value       = "False"
      value_type  = "bool"
    }
    auto_login_to_kasm = {
      description = "Sends users directly to kasm using default image after login"
      name        = "auto_login_to_kasm"
      value       = "False"
      value_type  = "bool"
    }
    chat_history_messages = {
      description = "The number of chat history messages to show when a new user connects to a shared Kasm. Set this value to 0 to disable showing chat history."
      name        = "chat_history_messages"
      value       = "0"
      value_type  = "int"
    }
    "control_panel.advanced_settings.show_game_mode" = {
      description = "Display game mode on Kasm session control panel"
      name        = "control_panel.advanced_settings.show_game_mode"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.advanced_settings.show_ime_input_mode" = {
      description = "Display IME input mode on Kasm session control panel"
      name        = "control_panel.advanced_settings.show_ime_input_mode"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.advanced_settings.show_keyboard_controls" = {
      description = "Display show keyboard controls on Kasm session control panel"
      name        = "control_panel.advanced_settings.show_keyboard_controls"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.advanced_settings.show_pointer_lock" = {
      description = "Display pointer lock on Kasm session control panel"
      name        = "control_panel.advanced_settings.show_pointer_lock"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.advanced_settings.show_prefer_local_cursor" = {
      description = "Display prefer local cursor option on Kasm session control panel"
      name        = "control_panel.advanced_settings.show_prefer_local_cursor"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.pwa_install_option" = {
      description = "Show the option to install individual Workspaces as a standalone PWA in the control panel."
      name        = "control_panel.pwa_install_option"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.show_delete_session" = {
      description = "Display delete Kasm session option on the Kasm session control panel"
      name        = "control_panel.show_delete_session"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.show_display_manager" = {
      description = "Show the display manager, allowing users to add/remove multiple displays"
      name        = "control_panel.show_display_manager"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.show_fullscreen" = {
      description = "Display fullscreen option on Kasm session control panel"
      name        = "control_panel.show_fullscreen"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.show_logout" = {
      description = "Display logout option on Kasm session control panel"
      name        = "control_panel.show_logout"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.show_return_to_workspaces" = {
      description = "Display return to workspaces option on the Kasm session  control panel"
      name        = "control_panel.show_return_to_workspaces"
      value       = "True"
      value_type  = "bool"
    }
    "control_panel.show_streaming_quality" = {
      description = "Display logout option on Kasm session control panel"
      name        = "control_panel.show_streaming_quality"
      value       = "True"
      value_type  = "bool"
    }
    dashboard_redirect = {
      description = "If configured, the user will be redirected to this URL instead of the main dashboard."
      name        = "dashboard_redirect"
      value       = ""
      value_type  = "string"
    }
    default_image = {
      description = "Sets the Default image for the /go route. Will automatically provision this kasm image."
      name        = "default_image"
      value       = ""
      value_type  = "image"
    }
    default_ui_language = {
      description = "Set the default language of the application user interface for users of this group."
      name        = "default_ui_language"
      value       = "none"
      value_type  = "language"
    }
    disabled_image_message = {
      description = "This message is displayed to the user when an images is currently disabled."
      name        = "disabled_image_message"
      value       = ""
      value_type  = "string"
    }
    display_ui_errors = {
      description = "Display detailed errors to the user if the UI experiences an unexpected error."
      name        = "display_ui_errors"
      value       = "False"
      value_type  = "bool"
    }
    enable_container_logging = {
      description = "If enabled, each workspace container will log to the database."
      name        = "enable_container_logging"
      value       = "True"
      value_type  = "bool"
    }
    enable_ui_server_logging = {
      description = "When enabled, the UI will send log messages to the server."
      name        = "enable_ui_server_logging"
      value       = "True"
      value_type  = "bool"
    }
    enable_webp = {
      description = "Enable webp image compression for compatible browsers. This will increase server side processing requirements but cut bandwidth by 30 percent."
      name        = "enable_webp"
      value       = "False"
      value_type  = "bool"
    }
    expose_user_environment_vars = {
      description = "Expose KASM_USER and KASM_USER_ID environment variables inside the Kasm."
      name        = "expose_user_environment_vars"
      value       = "False"
      value_type  = "bool"
    }
    idle_disconnect = {
      description = "Disconnect the Kasm connection if idle for this long. Time specified in minutes."
      name        = "idle_disconnect"
      value       = "20"
      value_type  = "float"
    }
    inject_ssh_keys = {
      description = "Automatically inject SSH public and private keys into Kasm sessions."
      name        = "inject_ssh_keys"
      value       = "False"
      value_type  = "bool"
    }
    kasm_audio_default_on = {
      description = "Default to audio enabled on Kasm start"
      name        = "kasm_audio_default_on"
      value       = "False"
      value_type  = "bool"
    }
    kasm_ime_mode_default_on = {
      description = "Enable IME mode by default."
      name        = "kasm_ime_mode_default_on"
      value       = "False"
      value_type  = "bool"
    }
    kasmvnc_mode_preference = {
      description = "Manage available and active KasmVNC streaming codecs."
      name        = "kasmvnc_mode_preference"
      value       = "{\"active\": [{\"id\": -1025, \"label\": \"JPEG/WEBP (Images)\"}, {\"id\": -1026, \"label\": \"H.264/AVC\"}, {\"id\": -1031, \"label\": \"H.265/HEVC\"}, {\"id\": -1036, \"label\": \"AV1\"}]}"
      value_type  = "json"
    }
    keepalive_expiration = {
      description = "The number of seconds a Kasm will stay alive unless a keeplive request is sent from the client."
      name        = "keepalive_expiration"
      value       = "3600"
      value_type  = "int"
    }
    keepalive_expiration_action = {
      description = "Specify what action to take when the session keepalive expires for container-based sessions. Valid options are delete, stop, and pause. The selection only applies to container-based sessions. The default for other types is delete."
      name        = "keepalive_expiration_action"
      value       = "delete"
      value_type  = "string"
    }
    keepalive_interval = {
      description = "When connected to a session, the client will send a keepalive request to the server at this interval (defined in seconds) to extend the expiration of the session."
      name        = "keepalive_interval"
      value       = "300"
      value_type  = "int"
    }
    lock_sharing_video_mode = {
      description = "Locks video quality to static resolution of 720p when sharing is enabled. Recomended for best performance."
      name        = "lock_sharing_video_mode"
      value       = "True"
      value_type  = "bool"
    }
    max_kasms_per_user = {
      description = "The maximum number of simultaneous Kasms a users is allowed to provision."
      name        = "max_kasms_per_user"
      value       = "5"
      value_type  = "int"
    }
    max_user_storage_mappings = {
      description = "The maximum number of user-based storage mappings allowed for each user."
      name        = "max_user_storage_mappings"
      value       = "2"
      value_type  = "int"
    }
    metadata = {
      description = "Arbitrary metadata for the group."
      name        = "metadata"
      value       = "{}"
      value_type  = "json"
    }
    password_expires = {
      description = "The number of days a password is valid for, after which the user will be required to change their password. A value of 0 disables password expiration."
      name        = "password_expires"
      value       = "0"
      value_type  = "int"
    }
    read_only_user_storage_mapping = {
      description = "Require that all user-based storage mappings are read-only."
      name        = "read_only_user_storage_mapping"
      value       = "True"
      value_type  = "bool"
    }
    record_sessions = {
      description = "Create a session recording for all sessions created by users in this group."
      name        = "record_sessions"
      value       = "False"
      value_type  = "bool"
    }
    "require_2fa" = {
      description = "Require two factor authentication for group. Users will be prompted to set Key on next log on."
      name        = "require_2fa"
      value       = "False"
      value_type  = "bool"
    }
    require_subscription = {
      description = "When enabled, a user must be subscribed to a plan to utilize the system."
      name        = "require_subscription"
      value       = "False"
      value_type  = "bool"
    }
    run_config = {
      description = "Specify arbitrary docker run params."
      name        = "run_config"
      value       = "{}"
      value_type  = "json"
    }
    session_banner = {
      description = "Show a banner on the session."
      name        = "session_banner"
      value       = ""
      value_type  = "border_value"
    }
    session_time_limit = {
      description = "If enabled, sessions are limited to the defined value in seconds."
      name        = "session_time_limit"
      value       = "0"
      value_type  = "int"
    }
    shared_session_full_control = {
      description = "When enabled, all users that join a shared session will have the ability to control the session."
      name        = "shared_session_full_control"
      value       = "False"
      value_type  = "bool"
    }
    show_disabled_images = {
      description = "When enabled, Images that have been disabled by the administrator will be visible to the user."
      name        = "show_disabled_images"
      value       = "False"
      value_type  = "bool"
    }
    staged_session_language_and_timezone_preference_override = {
      description = "Use a valid staged session that has a user/group timezone or language preference that does not match."
      name        = "staged_session_language_and_timezone_preference_override"
      value       = "False"
      value_type  = "bool"
    }
    usage_limit = {
      description = <<-EOT
      Enable usage limits for the group.
      Specify a Type, Interval and number of Hours to set limit.
      Type is either per_user or per_group.
      Interval is one of Daily, Weekly, Monthly, or Total.
      Hours is a positive number of hours for the limit cap.
      EOT
      name        = "usage_limit"
      value       = "{}"
      value_type  = "usage_limit"
    }
    volume_mapping = {
      description = <<-EOT
      Map a local server directory to kasm. The format is in json.
      Example: {"/data/departments/sales": {"bind": "/headless/documents/sales", "mode": "rw"}
      This example mounts a directory on the local server, /data/department/sales to the container
      at the location /shares/sales with read and write permissions.
      In order for the user in the Kasm to have write permissions on the mount the permissions
      on the server must allow read, write, execute for ALL users. This is because the
      user running inside the Kasm is not a valid user on the server.

      EOT
      name        = "volume_mapping"
      value       = "{}"
      value_type  = "json"
    }
    web_filter_policy = {
      description = "Sets the Web Filter Policy to be applied."
      name        = "web_filter_policy"
      value       = ""
      value_type  = "filter_policy"
    }
  }
}

variable "default_groups" {
  description = "Default Kasm groups for this deployment"
  type = map(object({
    name           = string
    description    = string
    permissions    = list(string)
    priority       = number
    group_id       = optional(string, null)
    group_metadata = optional(object({}), {})
    program_data   = optional(object({}), null)
    settings = optional(map(object({
      value      = optional(string)
      value_type = optional(string)
    })))
    is_system = optional(bool, false)
  }))

  default = {
    admins = {
      name        = "Administrators"
      description = "Default Kasm administrators group."
      priority    = 1
      is_system   = true
      permissions = [
        "global_admin"
      ]
      settings = {
        allow_kasm_pause = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_stop = {
          value      = "True"
          value_type = "bool"
        }
        allow_totp_2fa = {
          value      = "True"
          value_type = "bool"
        }
        disabled_image_message = {
          value      = "This image is currently disabled."
          value_type = "string"
        }
        require_2fa = {
          value      = "True"
          value_type = "bool"
        }
        show_disabled_images = {
          value      = "True"
          value_type = "bool"
        }
      }
    }
    all_users = {
      name        = "All Users"
      description = "Default Kasm users group."
      group_id    = "68d557ac-4cac-42cc-a9f3-1c7c853de0f3"
      priority    = 2
      is_system   = true
      permissions = [
        "user"
      ]
      settings = {
        allow_kasm_pause = {
          value      = "False"
          value_type = "bool"
        }
        allow_kasm_stop = {
          value      = "False"
          value_type = "bool"
        }
        keepalive_expiration_action = {
          value      = "delete"
          value_type = "string"
        }
        usage_limit = {
          value      = "{}"
          value_type = "usage_limit"
        }
      }
    }
    all_site_users = {
      name         = "All Site Users"
      description  = "Kasm All site users group."
      priority     = 1000
      program_data = {}
      permissions = [
        "user"
      ]
      settings = {
        allow_2fa_self_enrollment = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_audio = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_clipboard_down = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_clipboard_seamless = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_clipboard_up = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_delete = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_downloads = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_gamepad = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_microphone = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_printing = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_sharing = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_uploads = {
          value      = "True"
          value_type = "bool"
        }
        allow_kasm_webcam = {
          value      = "True"
          value_type = "bool"
        }
        allow_persistent_profile = {
          value      = "True"
          value_type = "bool"
        }
        allow_totp_2fa = {
          value      = "True"
          value_type = "bool"
        }
        allow_user_storage_mapping = {
          value      = "True"
          value_type = "bool"
        }
        allow_webauthn_2fa = {
          value      = "True"
          value_type = "bool"
        }
        auto_add_local_users = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.advanced_settings.show_game_mode" = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.advanced_settings.show_ime_input_mode" = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.advanced_settings.show_keyboard_controls" = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.advanced_settings.show_pointer_lock" = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.advanced_settings.show_prefer_local_cursor" = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.show_delete_session" = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.show_fullscreen" = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.show_logout" = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.show_return_to_workspaces" = {
          value      = "True"
          value_type = "bool"
        }
        "control_panel.show_streaming_quality" = {
          value      = "True"
          value_type = "bool"
        }
        idle_disconnect = {
          value      = "20"
          value_type = "float"
        }
        kasm_audio_default_on = {
          value      = "True"
          value_type = "bool"
        }
        keepalive_expiration = {
          value      = "3600"
          value_type = "int"
        }
        keepalive_expiration_action = {
          value      = "delete"
          value_type = "string"
        }
        max_kasms_per_user = {
          value      = "5"
          value_type = "int"
        }
        max_user_storage_mappings = {
          value      = "2"
          value_type = "int"
        }
        read_only_user_storage_mapping = {
          value      = "False"
          value_type = "bool"
        }
      }
    }
    site_admins = {
      name         = "Site Administrators"
      description  = "Kasm SaaS administrators group."
      priority     = 3
      program_data = {}
      permissions = [
        "user",
        "users_view",
        "users_modify",
        "users_create",
        "users_delete",
        "users_auth_session",
        "groups_view",
        "groups_modify",
        "groups_create",
        "groups_delete",
        "groups_view_ifmember",
        "groups_modify_ifmember",
        "agents_view",
        "staging_view",
        "casting_view",
        "casting_modify",
        "casting_create",
        "casting_delete",
        "sessions_view",
        "sessions_modify",
        "sessions_delete",
        "session_recordings_view",
        "images_view",
        "images_modify",
        "images_create",
        "images_delete",
        "images_modify_resources",
        "devapi_view",
        "webfilters_view",
        "webfilters_modify",
        "webfilters_create",
        "webfilters_delete",
        "brandings_view",
        "brandings_modify",
        "brandings_create",
        "brandings_delete",
        "settings_view",
        "settings_modify_auth",
        "settings_modify_storage",
        "auth_view",
        "auth_modify",
        "auth_create",
        "auth_delete",
        "licenses_view",
        "system_view",
        "system_export_schema",
        "reports_view",
        "zones_view",
        "connection_proxy_view",
        "physical_tokens_view",
        "physical_tokens_modify",
        "physical_tokens_create",
        "physical_tokens_delete",
        "servers_view",
        "autoscale_schedule_view",
        "registries_view",
        "registries_modify",
        "registries_create",
        "registries_delete",
        "storage_providers_view",
        "storage_providers_modify",
        "storage_providers_create",
        "storage_providers_delete",
        "egress_gateways_view",
        "egress_gateways_modify",
        "egress_gateways_create",
        "egress_gateways_delete",
        "egress_credentials_view",
        "egress_credentials_modify",
        "egress_credentials_create",
        "egress_credentials_delete",
        "egress_providers_view",
        "egress_providers_modify",
        "egress_providers_create",
        "egress_providers_delete",
        "ad_user_management_view",
        "ad_user_management_modify",
        "ad_user_management_create",
        "ad_user_management_delete",
        "banners_view",
        "banners_modify",
        "banners_create",
        "banners_delete",
        "labels_view"
      ]
    }
    workspace_admins = {
      name         = "Workspace Administrators"
      description  = "Kasm Workspace administrators group."
      priority     = 4
      program_data = {}
      permissions = [
        "user",
        "users_view",
        "groups_view",
        "agents_view",
        "staging_view",
        "casting_view",
        "casting_modify",
        "casting_create",
        "casting_delete",
        "sessions_view",
        "sessions_modify",
        "sessions_delete",
        "images_view",
        "images_modify",
        "images_create",
        "images_delete",
        "images_modify_resources",
        "webfilters_view",
        "system_view",
        "reports_view",
        "zones_view",
        "servers_view",
        "server_pools_view",
        "registries_view",
        "registries_modify",
        "registries_create",
        "registries_delete",
        "storage_providers_view"
      ]
    }
  }
}

variable "default_users" {
  description = "Default users for this Kasm deployment"
  type = map(object({
    username          = string
    groups            = list(string)
    index             = number
    created           = optional(string, "$${datetime:utcnow}")
    password_set_date = optional(string, "$${datetime:utcnow}")
    pw_hash           = optional(string, null)
    realm             = optional(string, "local")
  }))

  default = {
    # admin = {
    #   username = "admin@kasm.local"
    #   pw_hash  = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    #   index    = 1
    #   groups = [
    #     "admins"
    #   ]
    # }
    user = {
      username = "user@kasm.local"
      pw_hash  = "ef812e6cd523e95742921d31bd61856c62a14d76b03d422bc528f0fe37c8187d"
      index    = 2
      groups = [
        "all_users",
        "all_site_users"
      ]
    }
    system_admin = {
      username = "system@kasm.local"
      index    = 3
      groups = [
        "admins",
        "all_site_users",
        "all_users"
      ]
    }
    site_admin = {
      username = "siteadmin@kasm.local"
      index    = 4
      groups = [
        "site_admins",
        "all_site_users",
        "all_users"
      ]
    }
    workspace_admin = {
      username = "workspaceadmin@kasm.local"
      index    = 5
      groups = [
        "workspace_admins",
        "all_site_users",
        "all_users"
      ]
    }
  }
}

variable "registries" {
  description = "Kasm docker registry default configuration"
  type = list(object({
    registry_url   = string
    schema_version = string
    do_auto_update = bool
  }))

  default = [{
    do_auto_update = true
    registry_url   = "https://registry.kasmweb.com/"
    schema_version = "1.1"
  }]
}

variable "branding_configs" {
  description = "Kasm environment branding configuration"
  type = list(object({
    hostname                = string
    is_default              = bool
    name                    = string
    destroying_session_text = optional(string, "Destroying session...")
    favicon_logo_url        = optional(string)
    header_logo_url         = optional(string)
    html_title              = optional(string, "Kasm Workspaces")
    joining_session_text    = optional(string, "Creating a secure connection...")
    launcher_background_url = optional(string)
    loading_session_text    = optional(string, "Creating a secure connection...")
    login_caption           = optional(string, "The Container Streaming Platform®")
    login_logo_url          = optional(string)
    login_splash_url        = optional(string)
  }))

  default = null
}

variable "saml_configs" {
  description = "SAML configurations for DB pre-seed"
  type = list(object({
    adfs                      = bool
    authn_request_signed      = bool
    auto_login                = bool
    display_name              = string
    enabled                   = bool
    group_attribute           = string
    hostname                  = string
    idp_entity_id             = string
    idp_slo_url               = string
    idp_sso_url               = string
    idp_x509_cert             = string
    is_default                = bool
    name_id_encrypted         = bool
    sign_metadata             = bool
    sp_acs_url                = string
    sp_entity_id              = string
    sp_name_id                = string
    sp_slo_url                = string
    sp_x509_cert              = string
    strict                    = bool
    want_assertions_encrypted = bool
    want_assertions_signed    = bool
    want_attribute_statement  = bool
    want_messages_signed      = bool
    want_name_id              = bool
    want_name_id_encrypted    = bool
    debug                     = optional(bool, false)
    digest_algorithm          = optional(string, "http://www.w3.org/2000/09/xmldsig#sha1")
    logo_url                  = optional(string, null)
    logout_request_signed     = optional(bool, false)
    logout_response_signed    = optional(bool, false)
    signature_algorithm       = optional(string, "http://www.w3.org/2000/09/xmldsig#rsa-sha1")
    sp_private_key            = optional(string, "")
    sso_attribute_mapping = optional(list(object({
      attribute_name   = string
      sso_attribute_id = string
      user_field       = string
    })), [])
  }))

  default = null
}

variable "provider_types" {
  description = "Storage provider type to ensure only valid providers are used"
  type        = list(string)
  default = [
    "Custom",
    "Dropbox",
    "Google Drive",
    "NextCloud",
    "OneDrive",
    "S3"
  ]
}

variable "storage_providers" {
  description = "Storage provider configuration for DB pre-seed"
  type = list(object({
    auth_url              = string
    client_id             = string
    client_secret         = string
    default_target        = string
    enabled               = bool
    name                  = string
    redirect_url          = string
    scope                 = list(string)
    token_url             = string
    storage_provider_type = string
    auth_url_options      = optional(map(string), {})
    mount_config          = optional(map(string), {})
    root_drive_url        = optional(string, null)
    webdav_url            = optional(string, null)
    volume_config = optional(object({
      driver      = string
      driver_opts = map(string)
      }), {
      driver = "rclone"
      driver_opts = {
        type        = "drive"
        uid         = 1000
        gid         = 1000
        allow_other = true
      }
    })
  }))

  default = null
}

variable "server_pools" {
  description = "Provide settings for server pools if you want to pre-configure autoscaling"
  type = map(object({
    type = string
  }))
  default = {
    "Docker Agents" = {
      type = "Docker Agent"
    }
  }
}

variable "zone_config" {
  description = "Provide settings to automatically configure Zones and Zone settings"
  type = map(object({
    proxy_hostname               = string
    proxy_rdp_hostname           = string
    upstream_auth_address        = string
    zone_name                    = string
    allow_origin_domain          = optional(string, "$request_host$")
    enable_rdp_direct_login      = optional(bool, false)
    enable_rdp_https_gw          = optional(bool, true)
    enable_rdp_https_gw_dlp      = optional(bool, true)
    load_strategy                = optional(string, "most_kasms")
    prioritize_static_agents     = optional(bool, true)
    proxy_connections            = optional(bool, true)
    proxy_path                   = optional(string, "desktop")
    proxy_port                   = optional(number, 443)
    proxy_rdp_client_connections = optional(bool, true)
    proxy_rdp_port               = optional(number, 443)
    search_alternate_zones       = optional(bool, true)
    verify_rdp_client_ip         = optional(bool, true)
  }))
  default = {}
}

variable "autoscale_configs" {
  description = "Provide settings for Kasm autoscale initial setup"
  type = map(object({
    agent_cores_override                 = number
    agent_memory_override_gb             = number
    autoscale_type                       = string
    standby_cores                        = number
    standby_gpus                         = number
    standby_memory_mb                    = number
    connection_type                      = optional(string, "KasmVNC")
    agent_gpus_override                  = optional(number, 0)
    ad_computer_container_dn             = optional(string)
    ad_create_machine_record             = optional(bool, false)
    ad_recursive_machine_record_cleanup  = optional(bool, false)
    agent_installed                      = optional(bool, false)
    aggressive_scaling                   = optional(bool, true)
    aws_config_id                        = optional(string)
    aws_dns_config_id                    = optional(string)
    azure_config_id                      = optional(string)
    azure_dns_config_id                  = optional(string)
    base_domain_name                     = optional(string)
    connection_credential_type           = optional(string)
    connection_info                      = optional(map(any))
    connection_passphrase                = optional(string)
    connection_password                  = optional(string)
    connection_port                      = optional(number)
    connection_private_key               = optional(string)
    connection_sso_username_domain       = optional(string)
    connection_username                  = optional(string)
    digital_ocean_dns_config_id          = optional(string)
    digital_ocean_vm_config_id           = optional(string)
    downscale_backoff                    = optional(number, 3600)
    enabled                              = optional(bool, true)
    gcp_dns_config_id                    = optional(string)
    gcp_vm_config_id                     = optional(string)
    harvester_vm_config_id               = optional(string)
    hooks                                = optional(map(any))
    kubevirt_vm_config_id                = optional(string)
    last_provision                       = optional(string, "$${datetime:utcnow}")
    ldap_id                              = optional(string)
    max_simultaneous_sessions_per_server = optional(number, 1)
    max_simultaneous_users               = optional(number, 1)
    minimum_pool_standby_sessions        = optional(number, 0)
    oci_dns_config_id                    = optional(string)
    oci_vm_config_id                     = optional(string)
    openstack_vm_config_id               = optional(string)
    register_dns                         = optional(bool, false)
    request_downscale_at                 = optional(string, "$${datetime:utcnow}")
    require_checkin                      = optional(bool, false)
    reusable                             = optional(bool, false)
    use_user_private_key                 = optional(bool, true)
    vsphere_vm_config_id                 = optional(string)
    rotate_servers_in_days               = optional(number, 14)
    rotate_servers_pre_warm_minutes      = optional(number, 30)
    server_pool_id                       = optional(string, "Docker Agents")
    zone_id                              = string
  }))
  default = {}
}

variable "oci_vm_configs" {
  description = "Provide settings for OCI VM Provider configuration"
  type = map(object({
    oci_flex_cpus                 = optional(number, 13)
    oci_flex_memory_gb            = optional(number, 26)
    oci_boot_volume_gb            = optional(number, 200)
    max_instances                 = optional(number, 10)
    oci_image_ocid                = string
    oci_region                    = string
    oci_storage_vpus_per_gb       = optional(number, 120)
    oci_subnet_ocid               = string
    oci_nsg_ocids                 = list(string)
    oci_availability_domains      = list(string)
    oci_ssh_public_key            = string
    oci_user_ocid                 = string
    oci_fingerprint               = string
    oci_tenancy_ocid              = string
    oci_compartment_ocid          = string
    oci_private_key               = string
    startup_script                = string
    oci_shape                     = optional(string, "VM.Standard.E4.Flex")
    oci_baseline_ocpu_utilization = optional(string, "BASELINE_1_8")
    oci_config_override           = optional(map(any))
    oci_custom_tags               = optional(map(any))
  }))
  default = {}
}