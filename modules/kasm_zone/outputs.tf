output "webapp_asg_name" {
  description = "The name of the webapp Autoscale group"
  value       = module.webapp.asg_name
}

output "webapp_asg_arn" {
  description = "The ARN of the webapp Autoscale group"
  value       = module.webapp.asg_arn
}

output "webapp_instance_template_arn" {
  description = "The ARN of the webapp Instance template"
  value       = module.webapp.instance_template_arn
}

output "cpx_asg_name" {
  description = "The name of the cpx Autoscale group, or null when deploy_cpx is false"
  value       = try(module.cpx[0].asg_name, null)
}

output "cpx_asg_arn" {
  description = "The ARN of the cpx Autoscale group, or null when deploy_cpx is false"
  value       = try(module.cpx[0].asg_arn, null)
}

output "cpx_instance_template_arn" {
  description = "The ARN of the cpx Instance template, or null when deploy_cpx is false"
  value       = try(module.cpx[0].instance_template_arn, null)
}

output "proxy_asg_name" {
  description = "The name of the proxy Autoscale group, or null when deploy_proxy is false"
  value       = try(module.proxy[0].asg_name, null)
}

output "proxy_asg_arn" {
  description = "The ARN of the proxy Autoscale group, or null when deploy_proxy is false"
  value       = try(module.proxy[0].asg_arn, null)
}

output "proxy_instance_template_arn" {
  description = "The ARN of the proxy Instance template, or null when deploy_proxy is false"
  value       = try(module.proxy[0].instance_template_arn, null)
}

output "webapp_private_tg_arn" {
  description = "ARN of the zone's owned private webapp target group (named '<zone_key>-webapp-priv-tg')."
  value       = aws_lb_target_group.webapp_private.arn
}
