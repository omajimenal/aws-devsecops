output "role_arn" {
  value       = aws_iam_role.github_ci_role.arn
  description = "ARN del Rol IAM asignado a GitHub Actions"
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.app_ecr.repository_url
  description = "URL del repositorio Amazon ECR"
}