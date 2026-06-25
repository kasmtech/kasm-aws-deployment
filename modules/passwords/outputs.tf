output "password" {
  description = "Auto-generated passwords for use in Kasm deployment"
  value       = random_password.password.result
  sensitive   = true
}
