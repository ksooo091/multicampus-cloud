
resource "aws_ecr_repository" "front" {
  name                 = "front"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

}

resource "aws_ecr_repository" "app" {
  name                 = "app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

}

resource "aws_ecr_repository" "job" {
  name                 = "job"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

}

