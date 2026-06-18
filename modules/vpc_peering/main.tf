data "aws_caller_identity" "accepter" {
  provider = aws.accepter
}

resource "aws_vpc_peering_connection" "requester" {
  vpc_id        = var.requester_vpc_id
  peer_vpc_id   = var.accepter_vpc_id
  peer_owner_id = data.aws_caller_identity.accepter.account_id
  peer_region   = var.accepter_region
  auto_accept   = false
  provider      = aws.requester
}

resource "aws_vpc_peering_connection_accepter" "accepter" {
  vpc_peering_connection_id = aws_vpc_peering_connection.requester.id
  auto_accept               = true
  provider                  = aws.accepter
}

resource "aws_route" "requester" {
  count                     = length(var.requester_routes)
  route_table_id            = var.requester_routes[count.index].route_table_id
  destination_cidr_block    = var.requester_routes[count.index].destination_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.requester.id
  provider                  = aws.requester
}

resource "aws_route" "accepter" {
  count                     = length(var.accepter_routes)
  route_table_id            = var.accepter_routes[count.index].route_table_id
  destination_cidr_block    = var.accepter_routes[count.index].destination_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.requester.id
  provider                  = aws.accepter
}

