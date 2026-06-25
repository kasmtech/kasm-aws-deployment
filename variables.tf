#######################################
##                                   ##
##    AWS Authentication Variables   ##
##                                   ##
#######################################

variable "aws_profile" {
  description = "The AWS profile to use to be used to authenticate against AWS with."
  type        = string
  default     = "prod"
}

variable "dns_aws_profile" {
  description = "The AWS profile to use to be used to authenticate against AWS with."
  type        = string
  default     = "prod"
}

variable "dns_aws_region" {
  description = "The AWS region to use to be used to authenticate against AWS with."
  type        = string
  default     = "us-east-1"
}

variable "backend_bucket" {
  description = "The name of the backend bucket that contains the state file"
  type        = string
}

#######################################
##                                   ##
##   Customer Deployment Variables   ##
##                                   ##
#######################################

variable "customer_name" {
  description = "The full name of the new Kasm Customer"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9.-_ ]{1,256}?", var.customer_name))
    error_message = "The customer_name variable can only consist of a maximum of 256 characters including letters, numbers, dash (-), underscore (_), period (.), and space ( )."
  }
}

variable "deployment_type" {
  description = "Type of Kasm deployment"
  type        = string
  default     = "Multi-Region"

  validation {
    condition     = contains(["Multi-Cloud", "Multi-Region", "Multi-Server", "Single-Server"], var.deployment_type)
    error_message = "The deployment_type variable can only be one of Multi-Cloud, Multi-Region, Multi-Server, or Single-Server."
  }
}

variable "primary_region" {
  description = "The primary region you want to deploy Kasm into"
  type        = string

  validation {
    condition     = can(regex("^([a-z]{2}-[a-z]{4,}-[\\d]{1})$", var.primary_region))
    error_message = "The aws_region must be a valid Amazon Web Services (AWS) Region name, e.g. us-east-1"
  }
}

variable "secondary_regions" {
  description = "Extra AWS regions where you want to depoy Kasm to"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for region in var.secondary_regions : can(regex("^([a-z]{2}-[a-z]{4,}-[\\d]{1})$", region))])
    error_message = "The aws_region must be a valid Amazon Web Services (AWS) Region name, e.g. us-east-1"
  }
}

variable "windows_excluded_regions" {
  description = "Subset of regions where Windows Autoscale Config should be skipped. Use for newer AWS regions where Amazon (owner 801119661308) has not yet published Windows Server AMIs (e.g. ap-east-2, mx-central-1)."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for region in var.windows_excluded_regions : can(regex("^([a-z]{2}-[a-z]{4,}-[\\d]{1})$", region))])
    error_message = "Each entry in windows_excluded_regions must be a valid AWS region name, e.g. ap-east-2"
  }
}

variable "compute_excluded_regions" {
  description = "Subset of regions where only base networking (VPC, subnets) and security groups are deployed. Public/private ALBs, WAF, the kasm_zone module (webapp/cpx/proxy ASGs), per-region ACM certs, and per-region public DNS records are skipped. Use when an AWS region is in a degraded state (e.g. ALB creation failing in me-central-1) and you want to keep the VPC plumbing in place while skipping compute-tier resources. The primary_region cannot appear in this list."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for region in var.compute_excluded_regions : can(regex("^([a-z]{2}-[a-z]{4,}-[\\d]{1})$", region))])
    error_message = "Each entry in compute_excluded_regions must be a valid AWS region name, e.g. me-central-1"
  }

  validation {
    condition     = !contains(var.compute_excluded_regions, var.primary_region)
    error_message = "primary_region cannot appear in compute_excluded_regions — the primary region hosts the private LB, primary webapp, and DB and is required for any deployment."
  }
}

#######################################
##                                   ##
##         AWS DNS Variables         ##
##                                   ##
#######################################

variable "create_route53_zone" {
  description = "Whether or not to create a public route53 zone"
  type        = bool
  default     = true
}

variable "parent_dns_zone_name" {
  description = "The Parent (or root) domain name to use for your Kasm deployment - used when adding DNS zone NS records to the Parent zone"
  type        = string
  default     = ""

  validation {
    condition     = var.parent_dns_zone_name == "" ? true : can(regex("^[a-z0-9]+([\\-\\.]{1}[a-z0-9]+)*\\.[a-z]{2,6}", var.parent_dns_zone_name))
    error_message = "There are invalid characters in the parent_dns_zone_name - it must be a valid domain name."
  }
}

variable "kasm_domain_name" {
  description = "The domain name to use for your Kasm deployment - used when creating a new DNS zone"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]+([\\-\\.]{1}[a-z0-9]+)*\\.[a-z]{2,6}", var.kasm_domain_name))
    error_message = "There are invalid characters in the kasm_domain_name - it must be a valid domain name."
  }
}

#######################################
##                                   ##
##         Kasm VPC Variables        ##
##                                   ##
#######################################

variable "vpc_name" {
  description = "The display name to use for the Management VPC"
  type        = string
  default     = null
}

variable "base_vpc_cidr" {
  description = "Top level CIDR to use for Management VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrsubnet(var.base_vpc_cidr, 0, 0))
    error_message = "The management_vpc_cidr variable must be a valid IPv4 subnet in CIDR notation; e.g., 10.0.0.0/16."
  }
}

variable "number_of_availability_zones" {
  description = "Number of availability zones to create subnets in for autoscaled and load balancer subnets to ensure availability and redudency within the VPC or region."
  type        = number
}

variable "availability_zone_exclusions" {
  description = "Map of region to list of AZ names or zone IDs to exclude from subnet creation. Use when AWS reports an AZ as 'available' but rejects new subnet creation due to capacity or account restrictions (e.g. {\"me-central-1\" = [\"mec1-az2\"]})."
  type        = map(list(string))
  default     = {}
}

variable "single_nat_gateway" {
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
  type        = bool
  default     = false
}

#######################################
##                                   ##
##         Security Variables        ##
##                                   ##
#######################################

variable "mgmt_ssh_key" {
  description = "The managment SSH Key name"
  type        = string
  default     = "mgmt"
}

variable "ssh_key" {
  description = "The name of SSH key to attach to the instances"
  type        = string
  default     = "mgmt"
}

variable "public_ssh_ingress_ips" {
  description = "SSH ingress for the Bastion host"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for subnet in var.public_ssh_ingress_ips : can(cidrhost(subnet, 0))])
    error_message = "One of the public_ssh_ingress_ips values in invalid. This variable should be a list of valid Subnet CIDRs. Default is [0.0.0.0/0]."
  }
}

variable "public_web_access_ips" {
  description = "List of Public IP addresses in CIDR notation to allow access to this Kasm deployment. Default value is [0.0.0.0/0], but can be set to a client's public addresses to restrict access to Kasm by specific addresses."
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for subnet in var.public_web_access_ips : can(cidrhost(subnet, 0))])
    error_message = "One of the public_web_access_ips values in invalid. This variable should be a list of valid Subnet CIDRs. Default is [0.0.0.0/0]."
  }
}

#######################################
##                                   ##
##      Load Balancer Variables      ##
##                                   ##
#######################################

variable "lb_zone_config_file" {
  description = "The filepath to the file containing the Kasm Zone configuration details"
  type        = string
  default     = "lb_zone_config.json"
}

variable "http_redirect_rule_action" {
  description = "Public Load Balancer HTTP redirect rule action"
  type = object({
    type        = string
    status_code = string
    protocol    = string
  })
  default = {
    type        = "redirect"
    status_code = "HTTP_301"
    protocol    = "HTTPS"
  }
}

variable "http_listener_redirect" {
  description = "Public Load Balancer HTTP redirect settings"
  type = object({
    port        = number
    protocol    = string
    action_type = string
    redirect = object({
      port        = number
      protocol    = string
      status_code = string
    })
  })
  default = {
    port        = 80
    protocol    = "HTTP"
    action_type = "redirect"
    redirect = {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

variable "proxy_health_check" {
  description = "Kasm Proxy-only Load Balancer healthcheck"
  type = object({
    enabled             = bool
    path                = string
    matcher             = number
    protocol            = string
    timeout_in_sec      = number
    interval_in_sec     = number
    healthy_threshold   = number
    unhealthy_threshold = number
    port                = number
  })
  default = {
    enabled             = true
    path                = "/desktop"
    matcher             = 301
    protocol            = "HTTPS"
    timeout_in_sec      = 10
    interval_in_sec     = 30
    healthy_threshold   = 3
    port                = 443
    unhealthy_threshold = 3
  }
}

variable "webapp_health_check" {
  description = "Kasm API Webapp Load Balancer healthcheck"
  type = object({
    enabled             = bool
    path                = string
    matcher             = number
    protocol            = string
    timeout_in_sec      = number
    interval_in_sec     = number
    healthy_threshold   = number
    unhealthy_threshold = number
    port                = number
  })
  default = {
    enabled             = true
    path                = "/api/__healthcheck"
    matcher             = 200
    protocol            = "HTTPS"
    timeout_in_sec      = 10
    interval_in_sec     = 30
    healthy_threshold   = 3
    port                = 443
    unhealthy_threshold = 3
  }
}

#######################################
##                                   ##
##   Optional Deployment Variables   ##
##                                   ##
#######################################

variable "freeform_tags" {
  description = "Additional tags to add to Terraform-deployed Kasm services (beyond those in locals.tf file)"
  type        = map(any)
  default     = null
}

variable "generate_db_preseed" {
  description = "Generate a custom `default_properties.yaml` to create Site Admin and Workspace Admin groups and permissions"
  type        = bool
  default     = true
}

variable "generate_passwords" {
  description = "Automatically generate Kasm passwords"
  type        = bool
  default     = false
}

variable "deploy_nfs" {
  description = "Whether or not to deploy NFS services"
  type        = bool
  default     = false
}

variable "nfs_profile_path" {
  description = "The NFS export mount path for persistent profiles"
  type        = string
  default     = "/kasm/profiles"
}

variable "s3_persistent_profiles" {
  description = "Used to create VPC endpoints for private S3 access by resources"
  type        = bool
  default     = false
}

variable "s3_storage_provider" {
  description = "Used to create an AWS IAM user/group/policy for S3 bucket access with Storage Provider"
  type        = bool
  default     = false
}

variable "db_backup_bucket_name" {
  description = "Backup directory to use for automated Kasm DB backups and upload to s3 bucket. Different folders are used to separate DB backups from one another."
  type        = string
  default     = "kasm-aws-db-backup-bucket"
}

variable "s3_profile_bucket_base_name" {
  description = "AWS S3 Persistent Profile user name"
  type        = string
  default     = ""

  validation {
    condition     = var.s3_profile_bucket_base_name == "" ? true : can(regex("^[a-zA-Z-0-9-]{1,50}", var.s3_profile_bucket_base_name))
    error_message = "Variable s3_profile_policy_name_prefix must be unique across the AWS account, and can only consist of a maximum of 50 characters including letters, numbers, or dash (-)."
  }
}

variable "aws_s3_persistent_profile_policy_name" {
  description = "AWS S3 Persistent Profile policy name"
  type        = string
  default     = ""

  validation {
    condition     = var.aws_s3_persistent_profile_policy_name == "" ? true : can(regex("^[a-zA-Z-0-9-=.@,]{1,50}", var.aws_s3_persistent_profile_policy_name))
    error_message = "The aws_s3_persistent_profile_policy_name variable must be unique across the AWS account, and can only consist of a maximum of 50 characters including letters, numbers, dash (-), period (.), equal (=), comma (,), or at (@)."
  }
}

variable "s3_storage_provider_bucket_base_name" {
  description = "AWS S3 Storage Provider Bucket Base name"
  type        = string
  default     = ""

  validation {
    condition     = var.s3_storage_provider_bucket_base_name == "" ? true : can(regex("^[a-zA-Z-0-9-]{1,50}", var.s3_storage_provider_bucket_base_name))
    error_message = "Variable s3_storage_provider_bucket_base_name must be unique across the AWS account, and can only consist of a maximum of 50 characters including letters, numbers, or dash (-)."
  }
}

variable "aws_s3_storage_provider_policy_name" {
  description = "AWS S3 Persistent Profile policy name"
  type        = string
  default     = ""

  validation {
    condition     = var.aws_s3_storage_provider_policy_name == "" ? true : can(regex("^[a-zA-Z-0-9-=.@,]{1,50}", var.aws_s3_storage_provider_policy_name))
    error_message = "The aws_s3_storage_provider_policy_name variable must be unique across the AWS account, and can only consist of a maximum of 50 characters including letters, numbers, dash (-), period (.), equal (=), comma (,), or at (@)."
  }
}

variable "enable_s3_logging" {
  description = "Whether or not to enable S3 logging"
  type        = bool
  default     = false
}

variable "use_rds" {
  description = "Whether or not to use RDS (Aurora) for the database in place of the VM-based DB"
  type        = bool
  default     = false
}

variable "aws_sm_recovery_window_in_days" {
  description = "Recovery window (in days) applied to every AWS Secrets Manager secret managed by this repo. Use 0 only for tear-down workflows that destroy + reapply inside the window."
  type        = number
  default     = 7

  validation {
    condition     = var.aws_sm_recovery_window_in_days == 0 || (var.aws_sm_recovery_window_in_days >= 7 && var.aws_sm_recovery_window_in_days <= 30)
    error_message = "aws_sm_recovery_window_in_days must be 0 (immediate delete) or between 7 and 30 (AWS-allowed range)."
  }
}

#######################################
##                                   ##
##           RDS Variables           ##
##                                   ##
#######################################

variable "rds_dr_regions" {
  description = "Subset of secondary_regions in which to deploy Aurora Global Database secondary (read-only) clusters. Empty list = no DR clusters; only the primary writer in primary_region. Each entry must also be in secondary_regions."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for region in var.rds_dr_regions : can(regex("^([a-z]{2}-[a-z]{4,}-[\\d]{1})$", region))])
    error_message = "Each entry in rds_dr_regions must be a valid AWS Region name, e.g. us-west-2."
  }

  validation {
    condition     = length(var.rds_dr_regions) == length(distinct(var.rds_dr_regions))
    error_message = "rds_dr_regions must not contain duplicates."
  }

  validation {
    condition     = alltrue([for region in var.rds_dr_regions : contains(var.secondary_regions, region)])
    error_message = "Every rds_dr_regions entry must also appear in secondary_regions, since the regional VPC and subnet group only exist in regions listed there."
  }

  validation {
    condition     = !contains(var.rds_dr_regions, var.primary_region)
    error_message = "primary_region cannot appear in rds_dr_regions — the primary region is the Aurora writer, not a DR target."
  }
}

variable "rds_engine" {
  description = "Aurora engine. Valid values: aurora-mysql, aurora-postgresql."
  type        = string
  default     = "aurora-postgresql"

  validation {
    condition     = contains(["aurora-mysql", "aurora-postgresql"], var.rds_engine)
    error_message = "rds_engine must be aurora-mysql or aurora-postgresql."
  }
}

variable "rds_engine_version" {
  description = "Aurora engine version. Must be a globally-supported Aurora version."
  type        = string
  default     = "15.4"
}

variable "rds_database_name" {
  description = "Initial database name created on cluster bootstrap. Set to empty string to skip creating an initial database."
  type        = string
  default     = "kasm"
}

variable "rds_master_username" {
  description = "Master (admin) username for the Aurora cluster"
  type        = string
  default     = "kasmadmin"
}

variable "rds_instance_class" {
  description = "Instance class for cluster instances"
  type        = string
  default     = "db.r6g.large"
}

variable "rds_instances" {
  description = "Map of cluster instances to create in each regional cluster. Defaults to one writer (per cluster, the writer for the primary cluster, readers for the rest)."
  type        = any
  default = {
    one = {}
  }
}

variable "rds_backup_retention_period" {
  description = "Days to retain Aurora automated backups"
  type        = number
  default     = 7
}

variable "rds_deletion_protection" {
  description = "Whether to enable deletion protection on Aurora clusters"
  type        = bool
  default     = true
}

variable "rds_skip_final_snapshot" {
  description = "Whether to skip the final snapshot when destroying Aurora clusters"
  type        = bool
  default     = false
}

variable "rds_serverlessv2_scaling_configuration" {
  description = "Aurora Serverless v2 ACU bounds. Leave empty to use provisioned (non-serverless) instances. When set, must contain min_capacity and max_capacity."
  type        = map(number)
  default     = {}
}

variable "rds_enable_write_forwarding" {
  description = "Enable write-forwarding on Aurora Global Database secondary clusters. When true, app traffic against a secondary cluster endpoint writes by transparently forwarding to the global writer. Requires var.use_rds = true."
  type        = bool
  default     = true
}

variable "rds_failover_enabled" {
  description = "Deploy the automated cross-region failover Lambda for the Aurora Global Database. When false, failover is operator-only via the documented runbook. Requires var.use_rds = true and at least one entry in var.rds_dr_regions."
  type        = bool
  default     = true
}

variable "rds_failover_allow_data_loss" {
  description = "Whether the failover Lambda is permitted to call failover-global-cluster with AllowDataLoss=true. Set false for managed planned failovers only (requires healthy primary)."
  type        = bool
  default     = true
}

variable "rds_failover_alarm_evaluation_periods" {
  description = "Number of consecutive alarm periods the primary cluster must be unreachable before failover is triggered. Higher values reduce flapping but increase RTO."
  type        = number
  default     = 3

  validation {
    condition     = var.rds_failover_alarm_evaluation_periods >= 1 && var.rds_failover_alarm_evaluation_periods <= 10
    error_message = "rds_failover_alarm_evaluation_periods must be between 1 and 10."
  }
}

variable "rds_failover_alarm_period_seconds" {
  description = "CloudWatch alarm period in seconds. Combined with evaluation_periods determines effective detection window (default: 3 * 60 = 180s)."
  type        = number
  default     = 60

  validation {
    condition     = contains([10, 30, 60, 300], var.rds_failover_alarm_period_seconds)
    error_message = "rds_failover_alarm_period_seconds must be one of 10, 30, 60, or 300 (CloudWatch standard periods)."
  }
}

variable "rds_failover_sns_subscribers" {
  description = "Email addresses to subscribe to failover SNS notifications. Empty list = no email subscribers (topic still exists for external wiring)."
  type        = list(string)
  default     = []
}

variable "manager_db_target" {
  description = "Map from manager/webapp region to the RDS cluster region that group's writes should target. Defaults to region-affinity (manager region = cluster region) when a region is omitted; manager regions with no local cluster fall back to var.primary_region. Each value must be either var.primary_region or an entry in var.rds_dr_regions."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.manager_db_target : contains(concat([var.primary_region], var.rds_dr_regions), v)
    ])
    error_message = "Each manager_db_target value must equal var.primary_region or appear in var.rds_dr_regions."
  }
}

variable "run_remote_db_init" {
  description = "Operator gate for the one-shot Aurora preseed job. Set to true on the first apply that creates the RDS cluster; flip back to false immediately after success. Requires var.use_rds = true."
  type        = bool
  default     = false
}

variable "force_remote_db_init" {
  description = "Whether or not to force the DB to initilize "
  type        = bool
  default     = false
}

variable "remote_db_init_instance_type" {
  description = "EC2 instance type for the ephemeral Aurora init host. The init job is short-lived (under 15 min); the default is sufficient. Override only when the Kasm installer footprint outgrows it."
  type        = string
  default     = "t3.small"

  validation {
    condition     = can(regex("^[a-z0-9]+\\.[a-z0-9]+$", var.remote_db_init_instance_type))
    error_message = "remote_db_init_instance_type must be a valid EC2 instance type (e.g. t3.small, m6i.large)."
  }
}

variable "remote_db_init_ami_id" {
  description = "Optional override AMI ID for the ephemeral Aurora init host. Empty string = fall back to data.aws_ami.instance[var.primary_region] (same image as the rest of the deployment)."
  type        = string
  default     = ""

  validation {
    condition     = var.remote_db_init_ami_id == "" || can(regex("^ami-[a-f0-9]{8,17}$", var.remote_db_init_ami_id))
    error_message = "remote_db_init_ami_id must be empty or a valid AMI ID (e.g. ami-0123456789abcdef0)."
  }
}

variable "webapp_deployment_target" {
  description = "Per-zone webapp placement override. Maps zone-name (entries in primary_region + secondary_regions) to the AWS region where that zone's webapp ASG should physically deploy. Zones omitted from this map default to var.primary_region (today's centralized behavior). Used to co-locate a zone's webapps with its local Aurora secondary cluster (low-latency reads, writes forward to the global writer). Example: { eu-central-1 = eu-central-1 } places eu-central webapps in eu-central, leaving us-west webapps in primary."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for placement in values(var.webapp_deployment_target) :
      contains(concat([var.primary_region], var.secondary_regions), placement)
    ])
    error_message = "Every value in webapp_deployment_target must be either var.primary_region or one of var.secondary_regions. Placement regions must have a VPC available."
  }

  validation {
    condition = var.use_rds || alltrue([
      for placement in values(var.webapp_deployment_target) :
      placement == var.primary_region
    ])
    error_message = "Non-primary entries in webapp_deployment_target require use_rds = true. With the VM-based DB the only database lives in primary_region, so placing webapps elsewhere just adds LB cost and DRG traffic with no latency benefit. Either set use_rds = true (and provision a secondary Aurora cluster via var.rds_dr_regions) or remove the non-primary placement."
  }
}

#######################################
##                                   ##
##         Pre-Set Variables         ##
##                                   ##
#######################################

variable "aws_to_kasm_zone_map" {
  description = "AWS Region mapped to associated Kasm zone name"
  type        = map(string)
}

#######################################
##                                   ##
##           Kasm Variables          ##
##                                   ##
#######################################

variable "kasm_download_url" {
  description = "The URL for the Kasm Workspaces build"
  type        = string
}

variable "kasm_stig_url" {
  description = "The override url to use to download Kasm stigs. Leave as blank to use the default url."
  type        = string
  default     = ""
}

variable "kasm_version" {
  description = "The version of Kasm to install"
  type        = string
}

##############################
##                          ##
## Kasm Password Variables  ##
##                          ##
##############################

variable "kasm_database_password" {
  description = "The password for the database. No special characters"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.kasm_database_password == "" ? true : can(regex("^[a-zA-Z0-9]{12,40}", var.kasm_database_password))
    error_message = "The Kasm Database should be a string between 12 and 40 letters or numbers with no special characters."
  }
}

variable "kasm_manager_token" {
  description = "The manager token value for Agents to authenticate to webapps. No special characters"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.kasm_manager_token == "" ? true : can(regex("^[a-zA-Z0-9]{12,40}", var.kasm_manager_token))
    error_message = "The Manager Token should be a string between 12 and 40 letters or numbers with no special characters."
  }
}

variable "kasm_service_token" {
  description = "The service registration token value for Guac RDP servers to authenticate to webapps. No special characters"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.kasm_service_token == "" ? true : can(regex("^[a-zA-Z0-9]{12,40}", var.kasm_service_token))
    error_message = "The Service Registration Token should be a string between 12 and 40 letters or numbers with no special characters."
  }
}

variable "kasm_admin_password" {
  description = "The administrative user password. No special characters"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.kasm_admin_password == "" ? true : can(regex("^[a-zA-Z0-9]{12,40}", var.kasm_admin_password))
    error_message = "The Kasm Admin should be a string between 12 and 40 letters or numbers with no special characters."
  }
}

variable "kasm_siteadmin_password" {
  description = "The siteadmin user password. No special characters"
  type        = string
  default     = ""
}

variable "kasm_system_password" {
  description = "The kasm system user password. No special characters"
  type        = string
  default     = ""
}

variable "kasm_user_password" {
  description = "The standard (non administrator) user password. No special characters"
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = var.kasm_user_password == "" ? true : can(regex("^[a-zA-Z0-9]{12,40}", var.kasm_user_password))
    error_message = "The Kasm User should be a string between 12 and 40 letters or numbers with no special characters."
  }
}

variable "kasm_workspaceadmin_password" {
  description = "The workspaceadmin user password. No special characters"
  type        = string
  default     = ""
}

#######################################
##                                   ##
##         Compute Variables         ##
##                                   ##
#######################################

##############################
##                          ##
## Global Compute Variables ##
##                          ##
##############################

variable "image_type" {
  description = "DB Init base AMI type. Valid values are: ubuntu or al2."
  type        = string
  default     = "ubuntu"
}

variable "vm_instance_lookups" {
  description = "Per-image-type AMI lookup filters (owner account id + name regex) for AWS AMI data sources."
  type        = map(any)
  default = {
    ubuntu = {
      account_id  = "099720109477"
      image_regex = "ubuntu-minimal/images/hvm-ssd.*/ubuntu-noble-24.04-amd64-minimal.*"
    }
    al2 = {
      account_id  = "amazon"
      image_regex = "al2023-ami-2023.*-x86_64"
    }
    kasm_ubuntu = {
      account_id  = "037118362629"
      image_regex = "Kasm-Ubuntu 22.04 x86_64 - CIS Level 2 Hardened.*"
    }
    windows = {
      account_id  = "801119661308"
      image_regex = "Windows_Server-2019-English-Full-Base.*"
    }
  }
}

##############################
##                          ##
##      Agent Variables     ##
##                          ##
##############################

variable "agent_instance_type" {
  description = "The instance type to use for agents"
  type        = string
  default     = "t3.medium"
}

variable "agent_additional_install_arguments" {
  description = "Additional arguments to send to the Kasm agent for advanced installations"
  type        = string
  default     = "-O"

  validation {
    condition     = var.agent_additional_install_arguments == "" || can(regex("^[\\d\\w]*", var.agent_additional_install_arguments))
    error_message = "The agent_additional_install_arguments variable can only be valid Kasm arguments. Refer to the Kasm install documentation for additional details."
  }
}

## AWS Local Zones to opt into, keyed by parent region. Each Local Zone gets a
## public agent subnet (IGW-routed, like agent_public_subnets) and a Kasm
## Autoscale config row pointed at that subnet, so Kasm can launch agents into
## the Local Zone for users near it. Webapps/CPX/RDS/LBs remain in regular AZs.
##
## Local Zone names follow the form "<region>-<city>-<id><letter>", e.g.
## "us-east-1-bos-1a". The opt-in group name is derived by stripping the
## trailing letter ("us-east-1-bos-1"). Each key must be a region that appears
## in primary_region or secondary_regions; LZs in regions not present in this
## deployment are ignored.
variable "local_zones" {
  description = "Map of parent region to map of AWS Local Zone AZ name => CIDR slot index. Each LZ gets a public agent subnet at cidrsubnet offset `64 + index`; explicit indexes prevent CIDR shifts when adding or removing LZs. E.g. { \"us-east-1\" = { \"us-east-1-bos-1a\" = 0, \"us-east-1-mia-1a\" = 1 } }."
  type        = map(map(number))
  default     = {}

  validation {
    condition = alltrue([
      for lz_map in values(var.local_zones) : alltrue([
        for lz in keys(lz_map) : can(regex("^[a-z]{2}-[a-z]+-[0-9]+-[a-z]+-[0-9]+[a-z]$", lz))
      ])
    ])
    error_message = "Each Local Zone name must match the AWS Local Zone pattern, e.g. us-east-1-bos-1a."
  }

  validation {
    condition = alltrue([
      for lz_map in values(var.local_zones) : alltrue([
        for index in values(lz_map) : index >= 0 && index <= 191
      ])
    ])
    error_message = "Each Local Zone index must be between 0 and 191 (cidrsubnet offset = 64 + index, capped by the 8-bit subnet block)."
  }

  validation {
    condition = alltrue([
      for lz_map in values(var.local_zones) :
      length(values(lz_map)) == length(distinct(values(lz_map)))
    ])
    error_message = "Local Zone indexes must be unique within each parent region."
  }
}

##############################
##                          ##
##   CPX (Guac) Variables   ##
##                          ##
##############################

variable "deploy_cpx" {
  description = "Whether or not to deploy CPX resources"
  type        = bool
  default     = false
}

variable "cpx_instance_type" {
  description = ""
  type        = string
  default     = "t3.medium"
}

variable "cpx_additional_install_arguments" {
  description = "Additional arguments to send to the Kasm Connection Proxy (CPX) for advanced installations"
  type        = string
  default     = "-O"

  validation {
    condition     = var.cpx_additional_install_arguments == "" || can(regex("^[\\d\\w]*", var.cpx_additional_install_arguments))
    error_message = "The cpx_additional_install_arguments variable can only be valid Kasm arguments. Refer to the Kasm install documentation for additional details."
  }
}

##############################
##                          ##
##    Database Variables    ##
##                          ##
##############################

variable "db_block_volume_size" {
  description = "The size of the extra block volume for the database instacne"
  type        = number
  default     = 100
}

variable "db_instance_type" {
  description = "The instance size for the DB instance"
  type        = string
  default     = "t3.medium"
}

variable "number_of_allowed_db_connections" {
  description = "Number of Kasm DB connections to allow for DB Optimization"
  type        = number
  default     = null
}

variable "database_additional_install_arguments" {
  description = "Additional arguments to send to the Kasm Database for advanced installations"
  type        = string
  default     = "-O"

  validation {
    condition     = var.database_additional_install_arguments == "" ? true : can(regex("^[\\d\\w]*", var.database_additional_install_arguments))
    error_message = "The database_additional_install_arguments variable can only be valid Kasm arguments. Refer to the Kasm install documentation for additional details."
  }
}

##############################
##                          ##
##      Proxy Variables     ##
##                          ##
##############################

variable "proxy_instance_type" {
  description = ""
  type        = string
  default     = "t3.medium"
}

variable "proxy_additional_install_arguments" {
  description = "Additional arguments to send to the Kasm Proxy-only nodes for advanced installations"
  type        = string
  default     = "-O"

  validation {
    condition     = var.proxy_additional_install_arguments == "" || can(regex("^[\\d\\w]*", var.proxy_additional_install_arguments))
    error_message = "The proxy_additional_install_arguments variable can only be valid Kasm arguments. Refer to the Kasm install documentation for additional details."
  }
}

##############################
##                          ##
##     Webapp Variables     ##
##                          ##
##############################

variable "webapp_instance_type" {
  description = ""
  type        = string
  default     = "t3.medium"
}

variable "webapp_additional_install_arguments" {
  description = "Additional arguments to send to the Kasm WebApp for advanced installations"
  type        = string
  default     = "-O"

  validation {
    condition     = var.webapp_additional_install_arguments == "" ? true : can(regex("^[\\d\\w]*", var.webapp_additional_install_arguments))
    error_message = "The webapp_additional_install_arguments variable can only be valid Kasm arguments. Refer to the Kasm install documentation for additional details."
  }
}

##############################
##                          ##
## Teleport/Wazuh Variables ##
##                          ##
##############################

variable "teleport_version" {
  description = "The teleport release version to install on the node"
  type        = string
  default     = "15.4.19"
}

variable "wazuh_group" {
  description = "The Wazuh group to join the instance to for administration"
  type        = string
  default     = ""
}

variable "wazuh_url" {
  description = "The Wazuh agent join URL. Empty by default (public-safe); the parent wrapper injects the internal endpoint."
  type        = string
  default     = ""
}

#######################################
##                                   ##
##           WAF Variables           ##
##                                   ##
#######################################

variable "deploy_waf" {
  description = "Used to deploy WAF in front of public load balancers"
  type        = bool
}

variable "waf_bypass_ips" {
  description = "List of Public IPs to allow WAF bypass for Kasm administrative access."
  type        = list(string)

  validation {
    condition     = alltrue([for subnet in var.waf_bypass_ips : can(cidrhost(subnet, 0))])
    error_message = "One of the waf_bypass_ips values in invalid. This variable should be a list of valid Subnet CIDRs."
  }
}

## Per-role userdata template script paths, relative to var.userdata_dir.
## Standalone child deployments default var.userdata_dir to this module's
## userdata directory and default these filenames to the bundled standalone
## scripts. Parent-wrapper deployments pass the parent repo's userdata directory
## and parent-owned filenames explicitly.

variable "userdata_dir" {
  description = "Directory containing userdata templates. Empty string defaults to this module's ./userdata directory for standalone child deployments."
  type        = string
  default     = ""
}

variable "agent_userdata_file" {
  description = "Path under ./userdata/ for the autoscale agent userdata template."
  type        = string
  default     = "autoscale_agent_userdata.sh"
}

variable "bastion_userdata_file" {
  description = "Path under ./userdata/ for the bastion userdata template."
  type        = string
  default     = "bastion_userdata.sh"
}

variable "cpx_userdata_file" {
  description = "Path under ./userdata/ for the CPX (guac) userdata template."
  type        = string
  default     = "cpx_userdata.sh"
}

variable "db_userdata_file" {
  description = "Path under ./userdata/ for the database userdata template."
  type        = string
  default     = "database_userdata.sh"
}

variable "db_init_userdata_file" {
  description = "Path under ./userdata/ for the remote DB init userdata template."
  type        = string
  default     = "db_init_userdata.sh"
}

variable "proxy_userdata_file" {
  description = "Path under ./userdata/ for the proxy userdata template."
  type        = string
  default     = "proxy_userdata.sh"
}

variable "webapp_userdata_file" {
  description = "Path under ./userdata/ for the webapp/manager userdata template."
  type        = string
  default     = "webapp_userdata.sh"
}

variable "windows_userdata_file" {
  description = "Path under ./userdata/ for the Windows agent userdata template."
  type        = string
  default     = "windows_userdata.ps1"
}

#######################################
##                                   ##
##   Preseed / OTP (split-relocated) ##
##                                   ##
#######################################
## Relocated from the former kasm_internal.tf during the parent/child split.
## Public-safe defaults; the parent wrapper overrides with internal values.

variable "alembic_version" {
  description = "The Alembic version of the database schema to use for this configuration. Must match the Kasm version being installed."
  type        = string
  default     = "e3900d8a4fee"

  validation {
    condition     = can(regex("^[a-z0-9]{12}$", var.alembic_version))
    error_message = "The alembic_version variable must be a 12-character string of lower-case letters and numbers matching the target Kasm version."
  }
}

variable "api_preseeds" {
  description = "Extra Kasm API accounts to seed into default_properties.yaml, mapped api_key => account name. One generated password is created per entry. Empty by default (public-safe); the parent populates internal API accounts."
  type        = map(string)
  default     = {}
}

variable "kasm_system_otp_code" {
  description = "Optional one-time-password seed for the Kasm system user. Empty disables the OTP section in generated credentials."
  type        = string
  default     = ""
}
