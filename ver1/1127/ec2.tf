data "aws_iam_policy_document" "ssm" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_instance_profile" "ssm" {
  name = "ssm-role"
  role = aws_iam_role.ssm.name
}


resource "aws_iam_role" "ssm" {
  name               = "ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ssm.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.al-recent.id
  instance_type = "t3.large"
  key_name      = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id     = aws_subnet.private[0].id

  tags = {
    Name = "monitoring Server"
  }
  iam_instance_profile = aws_iam_instance_profile.ssm.name
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }
  vpc_security_group_ids = [aws_security_group.monitoring.id]

  root_block_device {
    volume_size = 20
  }

  user_data = <<EOF
#!/bin/bash

yum install -y docker
usermod -aG docker ec2-user
systemctl enable --now docker

mkdir -p /usr/local/lib/docker/cli-plugins/
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
EOF
}