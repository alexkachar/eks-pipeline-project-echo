variable "repositories" {
  type        = list(string)
  description = "List of ECR repository names to create"
}

variable "image_tag_mutability" {
  type        = string
  description = "Tag mutability setting: MUTABLE or IMMUTABLE"
  default     = "MUTABLE"
}

variable "lifecycle_keep_count" {
  type        = number
  description = "Number of images to keep per repository"
  default     = 10
}
