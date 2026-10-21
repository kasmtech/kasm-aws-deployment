output "default_properties_yaml" {
  description = "Rendered default_properties.yaml content. The caller is responsible for writing this to its destination (S3, local file, etc.)."
  value       = local.default_properties_yaml
  sensitive   = true
}
