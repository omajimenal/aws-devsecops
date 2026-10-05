terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. PROVEEDOR OIDC (Permite a GitHub Actions autenticarse sin Access Keys estáticas)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# 2. ROL IAM RESTRINGIDO (Mínimo privilegio mediante OIDC)
resource "aws_iam_role" "github_ci_role" {
  name = "github-actions-ci-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repo}:ref:refs/heads/main"
          }
        }
      }
    ]
  })
}

# 3. POLÍTICA IAM DE MÍNIMO PRIVILEGIO (Solo acceso estricto a ECR y SSM)
resource "aws_iam_policy" "ci_permissions" {
  name        = "github-actions-ci-policy"
  description = "Permisos de CI para publicacion en ECR y lectura de SSM"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPushOperations"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.app_ecr.arn
      },
      {
        Sid      = "SSMReadSecrets"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = aws_ssm_parameter.db_url.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_ci" {
  role       = aws_iam_role.github_ci_role.name
  policy_arn = aws_iam_policy.ci_permissions.arn
}

# 4. REPOSITORIO ECR SEGURO (Etiquetas Inmutables y Cifrado KMS)
resource "aws_ecr_repository" "app_ecr" {
  name                 = "enterprise-app"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

# 5. SECRETO CIFRADO EN PARAMETER STORE (Free Tier)
resource "aws_ssm_parameter" "db_url" {
  name        = "/enterprise-app/prod/DATABASE_URL"
  description = "Cadena de conexion cifrada a la base de datos"
  type        = "SecureString"
  value       = "postgres://db_admin:ComplexPassword2026!@localhost:5432/enterprise_db"
}