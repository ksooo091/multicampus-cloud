resource "aws_instance" "monitoring" {
  ami           = data.aws_ami.al-recent.id
  instance_type = "t3.large"
  key_name      = data.hcp_vault_secrets_app.aws_app.secrets.study_key_piar
  subnet_id     = aws_subnet.private[0].id

  tags = {
    Name = "monitoring Server"
  }

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