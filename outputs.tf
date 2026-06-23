#########################################################################################
##                                                                                     ##
##  Child output contract (parent/child split — FR-5).                                 ##
##  The parent wrapper (kasm-aws-multi-region-tf) consumes these to drive the          ##
##  Kasm-internal side-effects it owns: 1Password uploads and the preseed S3 upload.   ##
##  Standalone deployments may ignore them. Credential-bearing outputs are sensitive.  ##
##                                                                                     ##
#########################################################################################

#######################################
##           Identity / sets         ##
#######################################

output "standard_customer_name" {
  description = "Normalized customer name used in resource naming."
  value       = local.standard_customer_name
}

output "all_regions" {
  description = "Active deployment regions."
  value       = local.all_regions
}

output "windows_regions" {
  description = "Regions with Windows agent support enabled."
  value       = local.windows_regions
}

output "local_zone_pairs" {
  description = "Resolved (region, local-zone) pairs for LZ agent placement."
  value       = local.local_zone_pairs
}

output "kasminit_role_name" {
  description = "IAM role name attached to autoscale-launched agents."
  value       = local.kasminit_role_name
}

#######################################
##           SSH key material        ##
#######################################

output "ssh_key_public_keys" {
  description = "Per-role SSH public keys (role => public_key)."
  value       = { for k, v in module.ssh_keys : k => v.ssh_key_info.public_key }
}

output "ssh_key_private_keys" {
  description = "Per-role SSH private keys (role => private_key)."
  value       = { for k, v in module.ssh_keys : k => v.ssh_key_info.private_key }
  sensitive   = true
}

output "agent_ssh_public_key" {
  description = "Agent SSH public key used by autoscale launch configs."
  value       = local.agent_ssh_public_key
}

output "agent_ssh_pem_public_key" {
  description = "Agent SSH public key in PEM format."
  value       = module.ssh_keys["agent"].ssh_key_info_pem.public_key
}

output "agent_ssh_pem_private_key" {
  description = "Agent SSH private key in PEM format."
  value       = module.ssh_keys["agent"].ssh_key_info_pem.private_key
  sensitive   = true
}

#######################################
##        Autoscale IAM user         ##
#######################################

output "autoscale_iam_access_key_id" {
  description = "Access key ID for the VM autoscale IAM user."
  value       = module.iam_users["${local.standard_customer_name}-vm-autoscale-user"].iam_access_key_id
}

output "autoscale_iam_access_key_secret" {
  description = "Secret access key for the VM autoscale IAM user."
  value       = module.iam_users["${local.standard_customer_name}-vm-autoscale-user"].iam_access_key_secret
  sensitive   = true
}

#######################################
##      Networking / compute IDs     ##
#######################################

output "vpc_security_group_ids" {
  description = "Per-region map of security-group-name => id."
  value       = { for r in local.all_regions : r => module.vpc[r].security_group_ids }
}

output "nat_public_ips" {
  description = "Per-region NAT gateway public IPs (used by add-on consumers to allow egress)."
  value       = { for r in local.all_regions : r => module.vpc[r].nat_public_ips }
}

output "agent_ami_ids" {
  description = "Per-region resolved agent AMI id."
  value       = { for r in local.all_regions : r => data.aws_ami.instance[r].id }
}

output "windows_ami_ids" {
  description = "Per-windows-region resolved Windows AMI id."
  value       = { for r in local.windows_regions : r => data.aws_ami.windows[r].id }
}

output "public_agent_subnet_ids" {
  description = "Per-region public agent subnet ids."
  value       = local.public_agent_subnet_ids
}

output "public_windows_subnet_ids" {
  description = "Per-region public Windows subnet ids."
  value       = local.public_windows_subnet_ids
}

output "private_windows_subnet_ids" {
  description = "Per-region private Windows subnet ids."
  value       = local.private_windows_subnet_ids
}

output "lz_agent_subnet_ids" {
  description = "Per-region per-local-zone agent subnet ids."
  value       = local.lz_agent_subnet_ids
}

#######################################
##            Userdata               ##
#######################################

output "autoscale_agent_userdata" {
  description = "Per-region rendered autoscale agent userdata."
  value       = local.autoscale_agent_userdata
}

output "windows_user_data" {
  description = "Rendered Windows agent userdata."
  value       = local.public_windows_user_data
}

#######################################
##           Credentials             ##
#######################################

output "kasm_credentials" {
  description = "Generated Kasm passwords/tokens consumed by parent 1Password uploads."
  value = {
    admin          = local.admin_password
    database       = local.database_password
    manager        = local.manager_token
    service        = local.service_token
    siteadmin      = local.siteadmin_password
    system         = local.system_password
    user           = local.user_password
    workspaceadmin = local.workspaceadmin_password
  }
  sensitive = true
}

output "system_credentials_to_upload" {
  description = "System credential grouping (database/service/manager)."
  value       = local.system_credentials_to_upload
  sensitive   = true
}

output "user_credentials_to_upload" {
  description = "User credential grouping (admin/siteadmin/system/user/workspaceadmin)."
  value       = local.user_credentials_to_upload
  sensitive   = true
}

#######################################
##          DB preseed               ##
#######################################

output "default_properties_yaml" {
  description = "Generated default_properties.yaml (null when generate_db_preseed = false). Parent uploads this to its internal bucket."
  value       = try(module.custom_properties[0].default_properties_yaml, null)
}

#########################################################################################
##                                                                                     ##
##  Add-on enablement surface. Lets a caller (e.g. the parent wrapper) deploy extra    ##
##  webapp zones into this deployment's load balancers and DNS: inject TGs/rules via   ##
##  the var.additional_* inputs, then read the resulting ARNs + placement + LB/DNS     ##
##  identifiers back from here to attach an ASG and create Route53 records.            ##
##                                                                                     ##
#########################################################################################

#######################################
##        Placement / naming         ##
#######################################

output "webapp_placement_resolved" {
  description = "Resolved placement region per zone (zone => region)."
  value       = local.webapp_placement_resolved
}

output "webapp_placement_regions" {
  description = "Set of AWS regions receiving webapp deployments."
  value       = local.webapp_placement_regions
}

output "webapp_subnet_ids_by_region" {
  description = "Per-region webapp subnet ids."
  value       = local.webapp_subnet_ids_by_region
}

output "resource_name_prefix" {
  description = "Common resource-name prefix used by this deployment."
  value       = local.resource_name_prefix
}

output "ssh_key_name" {
  description = "EC2 key-pair name used by launched instances."
  value       = local.ssh_key_name
}

output "webapp_instance_profile_name" {
  description = "IAM instance profile name for webapp/manager instances."
  value       = module.webapp_role.instance_profile_name
}

#######################################
##            DNS / domain           ##
#######################################

output "private_domain" {
  description = "Private DNS domain used for internal records."
  value       = local.private_domain
}

output "route53_public_zone_id" {
  description = "Public Route53 hosted zone id."
  value       = local.route53_public_zone_id
}

output "private_zone_id" {
  description = "Private Route53 hosted zone id."
  value       = aws_route53_zone.private_zone.zone_id
}

#######################################
##         Public load balancers     ##
#######################################

output "public_lb_dns_names" {
  description = "Per-region public ALB DNS name."
  value       = { for r in local.compute_regions : r => module.public_load_balancers[r].lb_dns_name }
}

output "public_lb_zone_ids" {
  description = "Per-region public ALB hosted zone id."
  value       = { for r in local.compute_regions : r => module.public_load_balancers[r].lb_zone_id }
}

output "public_lb_target_group_arns_by_name" {
  description = "Per-region public ALB target-group ARNs keyed by TG name."
  value       = local.public_target_group_arns_by_name
}

#######################################
##         Private load balancers    ##
#######################################

output "private_lb_dns_name" {
  description = "Primary private ALB DNS name."
  value       = module.private_load_balancer.lb_dns_name
}

output "private_lb_zone_id" {
  description = "Primary private ALB hosted zone id."
  value       = module.private_load_balancer.lb_zone_id
}

output "private_lb_target_group_arns_by_name" {
  description = "Primary private ALB target-group ARNs keyed by TG name."
  value       = local.private_target_group_arns_by_name
}

output "private_lb_regional_dns_names" {
  description = "Per-placement-region private ALB DNS names (non-primary placements only)."
  value       = { for r, m in module.private_load_balancers_regional : r => m.lb_dns_name }
}

output "private_lb_regional_zone_ids" {
  description = "Per-placement-region private ALB hosted zone ids (non-primary placements only)."
  value       = { for r, m in module.private_load_balancers_regional : r => m.lb_zone_id }
}

output "private_lb_regional_target_group_arns_by_name" {
  description = "Per-placement-region private ALB target-group ARNs keyed by TG name (non-primary placements only)."
  value       = { for r, m in module.private_load_balancers_regional : r => m.target_group_arns_by_name }
}
