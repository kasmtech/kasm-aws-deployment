output "ssh_key_info" {
  description = "SSH Keys for use with Kasm Deployment"
  value = {
    public_key  = tls_private_key.ssh_key.public_key_openssh
    private_key = tls_private_key.ssh_key.private_key_openssh
  }
}

output "ssh_key_info_pem" {
  description = "SSH Keys for use with Kasm Deployment"
  value = {
    public_key  = tls_private_key.ssh_key.public_key_pem
    private_key = tls_private_key.ssh_key.private_key_pem
  }
}