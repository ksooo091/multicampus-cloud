data "external" "thumbprint" {
  program = ["sh", "${path.module}/get_thumbprint.sh"]
}


resource "aws_iam_openid_connect_provider" "iamoidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.thumbprint.result.thumbprint]
  url             = "https://token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}
resource "aws_iam_role" "github_role" {
  name = "github-actions2"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
                },
                "StringLike": {
                    "token.actions.githubusercontent.com:sub": "repo:ksooo091/*"
                }
            }
        }
    ]
})


}

resource "aws_iam_role_policy_attachment" "github" {
    role       = aws_iam_role.github_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy_attachment" "github_ecs" {
    role       = aws_iam_role.github_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}


output "role_arn" {
  value = aws_iam_role.github_role.arn
}