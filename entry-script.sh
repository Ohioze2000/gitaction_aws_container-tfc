#!/bin/bash
set -euo pipefail

# Manual deployment helper. The normal production path is GitHub Actions.
# Supply IMAGE_TAG with the Git commit SHA (or another tag that already exists).

REGION="${AWS_REGION:-us-east-1}"
IMAGE_TAG="${IMAGE_TAG:-}"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is not installed or not in PATH."
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: AWS CLI is not installed or not in PATH."
  exit 1
fi

if [ -z "$IMAGE_TAG" ]; then
  echo "ERROR: IMAGE_TAG is required. Use the Git commit SHA used for the ECR image."
  exit 1
fi

echo "Fetching deployment targets from Terraform outputs..."
REPO_URL="$(terraform output -raw ecr_repository_url)"
CLUSTER_NAME="$(terraform output -raw ecs_cluster_name)"
SERVICE_NAME="$(terraform output -raw ecs_service_name)"

for value in "$REPO_URL" "$CLUSTER_NAME" "$SERVICE_NAME"; do
  if [ -z "$value" ]; then
    echo "ERROR: Required Terraform output is empty."
    exit 1
  fi
done

echo "Authenticating Docker with ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REPO_URL"

echo "Building image..."
docker build --platform linux/amd64 -t "my-website-app:$IMAGE_TAG" ./app

echo "Tagging image for ECR..."
docker tag "my-website-app:$IMAGE_TAG" "$REPO_URL:$IMAGE_TAG"

echo "Pushing image to ECR..."
docker push "$REPO_URL:$IMAGE_TAG"

echo "Updating ECS service..."
aws ecs update-service \
  --cluster "$CLUSTER_NAME" \
  --service "$SERVICE_NAME" \
  --force-new-deployment \
  --region "$REGION" >/dev/null

aws ecs wait services-stable \
  --cluster "$CLUSTER_NAME" \
  --services "$SERVICE_NAME" \
  --region "$REGION"

echo "Deployment complete. Image: $REPO_URL:$IMAGE_TAG"
