resource "aws_ecr_repository" "web" {
  name                 = "web"
  image_tag_mutability = "MUTABLE"


  }

resource "aws_ecr_repository" "job" {
  name                 = "job"
  image_tag_mutability = "MUTABLE"


}

resource "aws_ecr_repository" "app" {
  name                 = "app"
  image_tag_mutability = "MUTABLE"


}