#---------------
# In-memory Cache
#---------------

# Create a Redis cluster
# checkov:skip=CKV_AWS_134:The cache does not need backup as it is ephemeral data only
resource "aws_elasticache_cluster" "redis_cluster" {
  cluster_id           = "cbv-payroll-redis-cluster"
  engine               = "redis"
  node_type            = "cache.t2.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.1"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [aws_security_group.redis_security_group.id]
}

resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "redis-subnet-group"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "redis_security_group" {
  name        = "redis-security-group"
  description = "Security group for Redis cluster"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow redis"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
}

output "redis_cluster_address" {
  value = aws_elasticache_cluster.redis_cluster.cache_nodes[0].address
}

output "redis_cluster_port" {
  value = aws_elasticache_cluster.redis_cluster.port
}
