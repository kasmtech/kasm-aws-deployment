locals {
  api_creds_one_password = {
    for api, config in local.api_configs : api => {
      secret_name = "KasmApi - ${var.domain_name} - ${config.name} - (WARNING: Automation, do not modify)"
      username    = config.api_key
      password    = local.all_api_configs[api].password
    }
  }
}

output "api_creds_one_password" {
  value = local.api_creds_one_password
}

output "default_properties_yaml" {
  description = "Rendered default_properties.yaml content. The caller is responsible for writing this to its destination (S3, local file, etc.)."
  value       = local.default_properties_yaml
  sensitive   = true
}
