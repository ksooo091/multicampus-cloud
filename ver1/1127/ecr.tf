
resource "aws_ecr_repository" "front" {
  name                 = "front"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

}

