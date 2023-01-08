## IAM user who can manage the infrastructure definition
data "aws_iam_policy" "admin_access" {
  name = "AdministratorAccess"
}

# Usar able to manga the infrastructure.
resource "aws_iam_user" "strapi" {
  name = "Strapi"
}

resource "aws_iam_access_key" "strapi" {
  user = aws_iam_user.strapi.name
}


resource "aws_iam_policy" "upload_image" {
  name        = "S3UploadImages"
  path        = "/"
  description = "Policy to allow to manage files in S3 bucket"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:GetObjectAttributes",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Effect   = "Allow"
        Resource = format("%s/*", aws_s3_bucket.cms_media.arn)
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "strapi-policy" {
  name       = "strapi-policy"
  users      = [aws_iam_user.strapi.name]
  policy_arn = aws_iam_policy.upload_image.arn
}

## Deploy role
resource "aws_iam_role" "deploy_ecs" {
  name        = "GitHubActionDeployECS"
  description = "Role to assume to deploy on ECS."


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          "Federated" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" : "repo:${var.cms_github_repository}:*"
          },
          "ForAllValues:StringEquals" = {
            "token.actions.githubusercontent.com:iss" : "https://token.actions.githubusercontent.com",
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "deploy_ecs" {
  name        = "PagoPaECSDeploy"
  description = "Policy to allow deploy on ECS."

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "ecs:DescribeTaskDefinition",
            "ecs:DescribeTaskDefinition",
            "ecs:RegisterTaskDefinition",
            "ecs:DescribeServices",
            "ecs:UpdateService"
          ],
          "Effect" : "Allow",
          "Resource" : [
            "*"
          ],
          "Sid" : "ECSDeploy"
        },
        {
          "Action" : [
            "iam:PassRole"
          ],
          "Effect" : "Allow",
          "Resource" : [
            "${aws_iam_role.task_cms_execution.arn}"
          ]
        }
      ],
    }
  )
}

resource "aws_iam_role_policy_attachment" "deploy_ecs" {
  role       = aws_iam_role.deploy_ecs.name
  policy_arn = aws_iam_policy.deploy_ecs.arn
}



## Publish static website
resource "aws_iam_role" "deploy_website" {
  name        = "GitHubActionDeployS3"
  description = "Role to assume to publish static content."


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          "Federated" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" : "repo:${var.fe_github_repository}:*"
          },
          "ForAllValues:StringEquals" = {
            "token.actions.githubusercontent.com:iss" : "https://token.actions.githubusercontent.com",
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "publish_s3" {
  name        = "PublishWebSite"
  path        = "/"
  description = "Policy to allow to publish website."

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject"
        ]
        Effect = "Allow"
        Resource = [
          format("%s/*", module.website_bucket.arn),
          format("%s/*", module.preview_bucket.arn),
        ]
      },
      {
        Action = [
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          module.website_bucket.arn,
          module.preview_bucket.arn,
        ]
      },
      {
        Action = [
          "cloudfront:CreateInvalidation"
        ]
        Effect = "Allow"
        Resource = [
          aws_cloudfront_distribution.website.arn,
          aws_cloudfront_distribution.preview.arn,
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "deploy_website" {
  role       = aws_iam_role.deploy_website.name
  policy_arn = aws_iam_policy.publish_s3.arn
}


# Rds stop and start

resource "aws_iam_role" "lambdastopstartrds" {
  name = "LambdaStopStartRds"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "rdsstopstart" {
  name        = "RdsStopStart"
  path        = "/"
  description = "Policy that allows to stop and start RSD"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "rds:DescribeDBClusterParameters",
          "rds:StartDBCluster",
          "rds:StopDBCluster",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeGlobalClusters",
          "rds:DescribePendingMaintenanceActions",
          "rds:DescribeDBLogFiles",
          "rds:StopDBInstance",
          "rds:StartDBInstance",
          "rds:DescribeReservedDBInstancesOfferings",
          "rds:DescribeReservedDBInstances",
          "rds:ListTagsForResource",
          "rds:DescribeValidDBInstanceModifications",
          "rds:DescribeDBInstances",
          "rds:DescribeSourceRegions",
          "rds:DescribeDBClusterEndpoints",
          "rds:DescribeDBClusters",
          "rds:DescribeDBClusterParameterGroups",
          "rds:DescribeOptionGroups"
        ]
        Effect = "Allow"
        Resource = [
          module.aurora_postgresql.cluster_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambdastopstartrds" {
  role       = aws_iam_role.lambdastopstartrds.name
  policy_arn = aws_iam_policy.rdsstopstart.arn
}