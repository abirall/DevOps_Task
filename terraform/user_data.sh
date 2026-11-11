
#!/bin/bash

set -euo pipefail

# --------------------------------------------------
# SYSTEM UPDATE AND INSTALLATION
# --------------------------------------------------

dnf update -y

dnf install -y docker awscli
dnf install -y curl

systemctl enable docker
systemctl start docker

# Start SSM agent (available on standard Amazon Linux 2023 AMIs)
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Ensure cloud-init failures are visible in the instance console and log.
exec > >(tee -a /var/log/python-app-bootstrap.log | logger -t user-data -s 2>/dev/console) 2>&1

# --------------------------------------------------
# APPLICATION CONFIGURATION
# --------------------------------------------------

AWS_REGION="${aws_region}"
IMAGE_URI="${image_uri}"
CONTAINER_PORT="${container_port}"
LOG_GROUP="${log_group}"
ENVIRONMENT="${environment}"

install -d -m 0750 /etc/python-app
cat > /etc/python-app/environment <<EOF
AWS_REGION="$AWS_REGION"
IMAGE_URI="$IMAGE_URI"
CONTAINER_PORT="$CONTAINER_PORT"
LOG_GROUP="$LOG_GROUP"
ENVIRONMENT="$ENVIRONMENT"
EOF
chmod 0640 /etc/python-app/environment
chown root:root /etc/python-app/environment

# --------------------------------------------------
# CREATE APPLICATION STARTUP SCRIPT
# --------------------------------------------------

cat > /usr/local/bin/run-python-app.sh <<'RUN_APP'
#!/bin/bash

set -euo pipefail

source /etc/python-app/environment
if [[ -z "${IMAGE_URI:-}" ]]; then
  echo "IMAGE_URI is not set; deploy an image through the CI pipeline first." >&2
  exit 1
fi
REGISTRY="$(printf '%s' "$IMAGE_URI" | cut -d '/' -f 1)"

# Authenticate with ECR
aws ecr get-login-password \
  --region "\$AWS_REGION" | \
  docker login \
    --username AWS \
    --password-stdin "\$REGISTRY"

# Pull application image
docker pull "\$IMAGE_URI"

# Start application
exec docker run \
  --rm \
  --name python-app \
  --publish "\$CONTAINER_PORT":"\$CONTAINER_PORT" \
  --log-driver=awslogs \
  --log-opt awslogs-region=\$AWS_REGION \
  --log-opt awslogs-group=\$LOG_GROUP \
  --log-opt awslogs-stream=python-app \
  "\$IMAGE_URI"
RUN_APP

chmod +x /usr/local/bin/run-python-app.sh

# --------------------------------------------------
# CREATE SYSTEMD SERVICE
# --------------------------------------------------

cat > /etc/systemd/system/python-app.service <<EOF
[Unit]
Description=Python DevOps Assessment Application
After=docker.service
Requires=docker.service

[Service]
Type=simple
EnvironmentFile=/etc/python-app/environment
Restart=always
RestartSec=10

ExecStart=/usr/local/bin/run-python-app.sh
ExecStop=-/usr/bin/docker stop --time 20 python-app
ExecStopPost=-/usr/bin/docker rm -f python-app

[Install]
WantedBy=multi-user.target
EOF

# --------------------------------------------------
# PREPARE THE SERVICE; CI STARTS IT AFTER PUBLISHING AN IMAGE
# --------------------------------------------------

systemctl daemon-reload

systemctl enable python-app

echo "Host bootstrap complete; CI deploys and starts the application after publishing an image."
