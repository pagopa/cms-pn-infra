data "aws_rds_engine_version" "postgresql" {
  engine  = "aurora-postgresql"
  version = "14.3"
}

resource "aws_db_parameter_group" "postgresql14" {
  name        = format("%s-aurora-db-postgres13-parameter-group", local.project)
  family      = "aurora-postgresql14"
  description = "Postgresql database parameters group."
}

resource "aws_rds_cluster_parameter_group" "postgresql14" {
  name        = format("%s-aurora-postgres14-cluster-parameter-group", local.project)
  family      = "aurora-postgresql14"
  description = "Aurora cluster parameters group."
}


module "aurora_postgresql" {
  source  = "terraform-aws-modules/rds-aurora/aws"
  version = "7.3.0"

  name              = format("%s-postgresql", local.project)
  engine            = data.aws_rds_engine_version.postgresql.engine
  engine_mode       = "provisioned"
  engine_version    = data.aws_rds_engine_version.postgresql.version
  storage_encrypted = true

  vpc_id                = module.vpc.vpc_id
  subnets               = module.vpc.database_subnets
  create_security_group = true
  allowed_cidr_blocks   = module.vpc.private_subnets_cidr_blocks

  monitoring_interval = 60

  apply_immediately   = true
  skip_final_snapshot = true

  db_parameter_group_name         = aws_db_parameter_group.postgresql14.id
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.postgresql14.id

  serverlessv2_scaling_configuration = {
    min_capacity = 1
    max_capacity = 2
  }

  instance_class = "db.serverless"
  instances = {
    one = {}
    two = {}
  }
}