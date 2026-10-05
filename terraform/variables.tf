variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Región principal de AWS"
}

variable "github_repo" {
  type        = string
  default     = "TU_USUARIO/TU_NUEVO_REPO"
  description = "Repositorio en GitHub en formato usuario/repositorio"
}