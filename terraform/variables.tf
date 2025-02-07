# variables.tf
variable "worker_count" {
  description = "Nombre de nœuds Spark workers"
  type        = number
}

variable "master_name" {
  description = "Nom du nœud master"
  type        = string
}

variable "image" {
  description = "Image utilisée pour les instances LXD"
  type        = string
}

variable "user" {
  description = "Nom de l'utilisateur à créer"
  type        = string
}

variable "user_password" {
  description = "Mot de passe de l'utilisateur"
  type        = string
  sensitive   = true
}
