################################################################################
# VPC
################################################################################
resource "aws_vpc" "this" {
  count = var.create_vpc ? 1 : 0

  cidr_block                           = var.vpc_cidr
  instance_tenancy                     = var.instance_tenancy
  enable_dns_hostnames                 = var.enable_dns_hostnames
  enable_dns_support                   = var.enable_dns_support
  enable_network_address_usage_metrics = var.enable_network_address_usage_metrics

  tags = {
    Name = var.vpc_name
  }
}

################################################################################
# DHCP Options Set
################################################################################
# resource "aws_vpc_dhcp_options" "this" {
#   count = var.create_vpc && var.dhcp_options != {} ? 1 : 0

#   domain_name          = lookup(var.dhcp_options, "domain_name", "")
#   domain_name_servers  = lookup(var.dhcp_options, "domain_name_servers", [])
#   ntp_servers          = lookup(var.dhcp_options, "ntp_servers", [])
#   netbios_name_servers = lookup(var.dhcp_options, "netbios_name_servers", [])
#   netbios_node_type    = lookup(var.dhcp_options, "netbios_node_type", "")

#   tags = {
#     Name = "Default DHCP Option set for ${title(var.vpc_name)}"
#   }
# }

# resource "aws_vpc_dhcp_options_association" "this" {
#   count = var.create_vpc && var.dhcp_options != [] ? 1 : 0

#   vpc_id          = aws_vpc.this[count.index].id
#   dhcp_options_id = aws_vpc_dhcp_options.this[count.index].id
# }

################################################################################
#  Subnets
################################################################################
resource "aws_subnet" "this" {
  for_each = var.subnets

  availability_zone                           = each.value.availability_zone
  cidr_block                                  = each.value.cidr_block
  enable_resource_name_dns_a_record_on_launch = each.value.add_dns_record_on_launch
  map_public_ip_on_launch                     = each.value.is_public
  private_dns_hostname_type_on_launch         = "resource-name"
  vpc_id                                      = aws_vpc.this[0].id

  tags = {
    Name        = each.key
    Subnet_Type = each.value.is_public ? "Public" : "Private"
  }
}

################################################################################
#  Routes
################################################################################
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this[0].id

  tags = {
    Name = "Internet-Gateway-Route-Table"
  }
}

resource "aws_route_table_association" "public" {
  for_each = { for key, value in var.subnets : key => value if value.is_public }

  subnet_id      = aws_subnet.this[(each.key)].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id

  timeouts {
    create = "5m"
  }
}

# There are as many routing tables as the number of NAT gateways
resource "aws_route_table" "private" {
  count = var.single_nat_gateway ? 1 : length(var.azs)

  vpc_id = aws_vpc.this[0].id

  tags = {
    Name = var.single_nat_gateway ? "NAT-Gateway-Route-Table" : "NAT-Gateway-Route-Table-for-${var.azs[(count.index)]}"
  }
}

resource "aws_route_table_association" "private" {
  for_each = { for key, value in var.subnets : key => value if !value.is_public }

  subnet_id      = aws_subnet.this[(each.key)].id
  route_table_id = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[index(var.azs, each.value.availability_zone)].id
}

resource "aws_route" "private" {
  count = var.single_nat_gateway ? 1 : length(var.azs)

  route_table_id         = aws_route_table.private[(count.index)].id
  destination_cidr_block = var.nat_gateway_destination_cidr_block
  nat_gateway_id         = aws_nat_gateway.this[(count.index)].id

  timeouts {
    create = "5m"
  }
}

################################################################################
# Database Subnet Group
################################################################################
resource "aws_db_subnet_group" "database" {
  count = var.deploy_rds ? 1 : 0

  name        = "kasm-rds-aurora-subnet-group"
  description = "Kasm Database subnet group for ${var.vpc_name}"
  subnet_ids  = [for key, value in aws_subnet.this : value.id if can(regex("(?i:database)", key))]

  tags = {
    Name = "Kasm-RDS-Aurora-Subnet-Group"
  }
}

################################################################################
# Internet Gateway
################################################################################
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this[0].id

  tags = {
    Name = "Internet-Gateway"
  }
}

################################################################################
# NAT Gateway
################################################################################
resource "aws_eip" "nat" {
  count = var.single_nat_gateway ? 1 : length(var.azs)

  domain = "vpc"

  tags = {
    Name = var.single_nat_gateway ? "EIP-for-NAT-Gateway" : "EIP-for-NAT-Gateway-in-${var.azs[(count.index)]}"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.single_nat_gateway ? 1 : length(var.azs)

  allocation_id = aws_eip.nat[(count.index)].id
  subnet_id     = [for key, value in aws_subnet.this : value.id if can(regex("(?i:public.load.balancer)", key))][(count.index)]

  tags = {
    Name = var.single_nat_gateway ? "NAT-Gateway" : "NAT-Gateway-for-${var.azs[(count.index)]}"
  }

  depends_on = [aws_internet_gateway.this]
}

################################################################################
# Flow Log
################################################################################
resource "aws_flow_log" "this" {
  count = var.enable_flow_log ? 1 : 0

  log_destination_type     = var.flow_log_destination_type
  log_destination          = local.flow_log_destination_arn
  log_format               = var.flow_log_log_format
  iam_role_arn             = local.flow_log_iam_role_arn
  traffic_type             = var.flow_log_traffic_type
  vpc_id                   = aws_vpc.this[0].id
  max_aggregation_interval = var.flow_log_max_aggregation_interval

  dynamic "destination_options" {
    for_each = var.flow_log_destination_type == "s3" ? [true] : []

    content {
      file_format                = var.flow_log_file_format
      hive_compatible_partitions = var.flow_log_hive_compatible_partitions
      per_hour_partition         = var.flow_log_per_hour_partition
    }
  }

  tags = var.vpc_flow_log_tags
}

################################################################################
# Flow Log CloudWatch
################################################################################
resource "aws_cloudwatch_log_group" "flow_log" {
  count = local.create_flow_log_cloudwatch_log_group ? 1 : 0

  name              = "${var.flow_log_cloudwatch_log_group_name_prefix}${local.flow_log_cloudwatch_log_group_name_suffix}"
  retention_in_days = var.flow_log_cloudwatch_log_group_retention_in_days
  kms_key_id        = var.flow_log_cloudwatch_log_group_kms_key_id

  tags = var.vpc_flow_log_tags
}

resource "aws_iam_role" "vpc_flow_log_cloudwatch" {
  count = local.create_flow_log_cloudwatch_iam_role ? 1 : 0

  name_prefix          = "vpc-flow-log-role-"
  assume_role_policy   = data.aws_iam_policy_document.flow_log_cloudwatch_assume_role[0].json
  permissions_boundary = var.vpc_flow_log_permissions_boundary

  tags = var.vpc_flow_log_tags
}

data "aws_iam_policy_document" "flow_log_cloudwatch_assume_role" {
  count = local.create_flow_log_cloudwatch_iam_role ? 1 : 0

  statement {
    sid = "AWSVPCFlowLogsAssumeRole"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    effect = "Allow"

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "vpc_flow_log_cloudwatch" {
  count = local.create_flow_log_cloudwatch_iam_role ? 1 : 0

  role       = aws_iam_role.vpc_flow_log_cloudwatch[0].name
  policy_arn = aws_iam_policy.vpc_flow_log_cloudwatch[0].arn
}

resource "aws_iam_policy" "vpc_flow_log_cloudwatch" {
  count = local.create_flow_log_cloudwatch_iam_role ? 1 : 0

  name_prefix = "vpc-flow-log-to-cloudwatch-"
  policy      = data.aws_iam_policy_document.vpc_flow_log_cloudwatch[0].json
  tags        = var.vpc_flow_log_tags
}

data "aws_iam_policy_document" "vpc_flow_log_cloudwatch" {
  count = local.create_flow_log_cloudwatch_iam_role ? 1 : 0

  statement {
    sid = "AWSVPCFlowLogsPushToCloudWatch"

    effect = "Allow"

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

################################################################################
# Base Network ACLs
################################################################################
resource "aws_network_acl" "this" {
  for_each = toset(local.distinct_nacls)

  vpc_id     = aws_vpc.this[0].id
  subnet_ids = [for key, value in var.subnets : aws_subnet.this[(key)].id if value.network_acl == each.key]

  tags = {
    Name = each.key
  }
}

resource "aws_network_acl_rule" "inbound" {
  for_each = var.inbound_acl_rules

  network_acl_id = aws_network_acl.this[(each.key)].id

  egress          = false
  rule_number     = each.value.rule_number
  rule_action     = each.value.rule_action
  protocol        = each.value.protocol
  from_port       = lookup(each.value, "from_port", null)
  to_port         = lookup(each.value, "to_port", null)
  icmp_code       = lookup(each.value, "icmp_code", null)
  icmp_type       = lookup(each.value, "icmp_type", null)
  cidr_block      = lookup(each.value, "cidr_block", null)
  ipv6_cidr_block = lookup(each.value, "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "outbound" {
  for_each = var.outbound_acl_rules

  network_acl_id = aws_network_acl.this[(each.key)].id

  egress          = true
  rule_number     = each.value.rule_number
  rule_action     = each.value.rule_action
  protocol        = each.value.protocol
  from_port       = lookup(each.value, "from_port", null)
  to_port         = lookup(each.value, "to_port", null)
  icmp_code       = lookup(each.value, "icmp_code", null)
  icmp_type       = lookup(each.value, "icmp_type", null)
  cidr_block      = lookup(each.value, "cidr_block", null)
  ipv6_cidr_block = lookup(each.value, "ipv6_cidr_block", null)
}

################################################################################
# Base security groups
################################################################################
resource "aws_security_group" "this" {
  for_each = toset(var.security_groups)

  name   = each.key
  vpc_id = aws_vpc.this[0].id

  ## Suppress AWS's auto-injected 0.0.0.0/0-ALL egress at create time so
  ## module.sg_rules' standalone aws_security_group_rule resources own the
  ## default-egress without colliding on Authorize.
  egress = []

  tags = {
    Name = each.key
  }

  ## Standalone aws_security_group_rule resources (module.sg_rules) own every
  ## rule on this SG. Refreshing the SG resource re-reads all rules into its
  ## `egress` attribute, shadowing the standalone rules and producing endless
  ## revoke/recreate churn. ignore_changes severs that loop without affecting
  ## create-time behavior, which `egress = []` above still controls.
  lifecycle {
    ignore_changes = [egress, ingress]
  }
}

