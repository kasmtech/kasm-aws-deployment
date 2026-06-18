locals {
  ## Convenience predicate. The EC2 + IAM stack only exists when both gates are true:
  ## the deployment must be using RDS AND the operator must explicitly flip the flag.
  run_remote_db_init = var.use_rds && var.run_remote_db_init

  ## SM secret IDs the init script reads at boot. Lookups are stable since both
  ## the caller's aws_sm_* modules and these names derive from standard_customer_name.
  sm_system_id = "${var.standard_customer_name}/other-credential"
  sm_user_id   = "${var.standard_customer_name}/user-credential"
  sm_admin_id  = "${var.standard_customer_name}/admin-credential"

  ## S3 path the init job pulls the rendered default_properties.yaml from.
  ## Empty when generate_db_preseed = false (installer falls back to its default seed).
  preseed_s3_key = var.generate_db_preseed ? "aws/${var.standard_customer_name}/${var.kasm_version}-default_properties.yaml" : ""

  ## Stable SSM parameter name for the success signal. Prefix mirrors the SM
  ## naming scheme (`<customer>/<region>/<slug>`) so operators can find it
  ## alongside the rest of the Kasm secrets/config.
  ssm_status_param_name = "/kasm/${var.standard_customer_name}/${var.primary_region}/remote_db_init_status"

  ## VPC's built-in DNS resolver — the second address in the VPC CIDR. AWS also
  ## exposes the same resolver at link-local 169.254.169.253, but link-local
  ## doesn't reliably traverse Docker bridge NAT, so containers spawned by the
  ## Kasm installer can't use it. The CIDR-based address is a regular routed
  ## IP and works from inside containers.
  vpc_dns_ip = cidrhost(var.vpc_cidr, 2)

  ## gzip + base64: the rendered script is ~12KB raw / ~17KB base64 — over EC2's
  ## 16KB user_data limit. cloud-init auto-detects gzip on the user-data blob,
  ## decompresses, and runs as normal. Compressed size is ~6KB. Use the
  ## aws_instance.user_data_base64 field, which accepts non-UTF8 bytes.
  ##
  ## The script lives in the root module's userdata/ directory alongside other
  ## VM bootstrap scripts, so we reference it via path.root rather than copying
  ## it into the module.
  userdata = base64gzip(
    templatefile("${path.root}/userdata/db_init_userdata.sh", {
      AWS_REGION            = var.primary_region
      DB_HOSTNAME           = "database-${var.primary_region}.${var.private_domain}"
      DB_PORT               = 5432
      DB_NAME               = var.rds_database_name
      FORCE_DB_INIT         = "${var.force_init}"
      IMAGE_TYPE            = var.image_type
      KASM_DOWNLOAD_URL     = var.kasm_download_url
      PRESEED_S3_BUCKET     = var.db_backup_bucket_name
      PRESEED_S3_KEY        = local.preseed_s3_key
      RDS_MASTER_USER       = var.rds_master_username
      SM_SYSTEM_CRED_ID     = local.sm_system_id
      SM_USER_CRED_ID       = local.sm_user_id
      SM_ADMIN_CRED_ID      = local.sm_admin_id
      SSM_STATUS_PARAM_NAME = local.ssm_status_param_name
      VPC_DNS_IP            = local.vpc_dns_ip
    })
  )
}
