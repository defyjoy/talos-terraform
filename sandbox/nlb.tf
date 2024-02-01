module "sg_loadbalancer" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "talos-security-group"
  description = "Security group for user-service with custom ports open within VPC, and PostgreSQL publicly open"
  vpc_id      = data.aws_vpc.vpc.id
  # ingress_cidr_blocks = [data.aws_vpc.vpc.cidr_block]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 80
      to_port     = 84
      protocol    = "tcp"
      description = "TCP traffic"
      cidr_blocks = "0.0.0.0/0"
    },
    {
      from_port   = 80
      to_port     = 84
      protocol    = "udp"
      description = "UDP traffic"
      cidr_blocks = "0.0.0.0/0"
    },
  ]

  egress_with_cidr_blocks = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      description = "egress traffic"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_lb_target_group" "talos_tg" {
  name            = "talos-lb-tg"
  port            = 6443
  protocol        = "TCP"
  target_type     = "ip"
  ip_address_type = "ipv4"
  vpc_id          = data.aws_vpc.vpc.id

  health_check {
    port                = 6443
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 2
    interval            = 5
    protocol            = "TCP"
    # matcher             = "200" # has to be HTTP 200 or fails
  }
}

resource "aws_lb" "talos" {
  name               = "talos-cluster-network-lb"
  internal           = true
  load_balancer_type = "network"
  security_groups    = [module.sg_loadbalancer.security_group_id]
  subnets            = [for subnet in data.aws_subnets.private_subnets.ids : subnet]

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true


  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "talos" {
  load_balancer_arn = aws_lb.talos.arn
  port              = "6443"
  protocol          = "TCP"
  # certificate_arn   = "arn:aws:iam::187416307283:server-certificate/test_cert_rab3wuqwgja25ct3n4jdj2tzu4"
  # alpn_policy = "HTTP2Preferred"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.talos_tg.arn
  }

  depends_on = [
    aws_lb_target_group.talos_tg
  ]
}


resource "aws_lb_target_group_attachment" "talos" {
  count            = length(module.talos_control_plane_nodes)
  target_group_arn = aws_lb_target_group.talos_tg.arn
  target_id        = module.talos_control_plane_nodes[count.index].private_ip
  port             = 6443
}
