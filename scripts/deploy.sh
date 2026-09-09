#!/usr/bin/env bash
# ====================================================================
# Projet certification - ShopBR - Deploiement manuel (secours / demo)
# ====================================================================
# Reproduit localement ce que fait .github/workflows/cd.yml, pour les
# cas ou GitHub Actions n'est pas disponible, ou pour une demonstration
# pas-a-pas devant le jury.
#
# Prerequis : aws cli, docker, kubectl configures ; variables ci-dessous.
# Usage : ./scripts/deploy.sh [ref]   (ref = SHA ou branche de shopbr-ia, defaut: main)
# ====================================================================
set -euo pipefail

# ── Configuration (adapter a votre compte) ──────────────────────────
AWS_REGION="${AWS_REGION:-sa-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:?Definir AWS_ACCOUNT_ID}"
ECR_REPO="${ECR_REPO:-shopbr-api}"
EKS_CLUSTER="${EKS_CLUSTER:-shopbr-cluster}"
SOURCE_REPO="${SOURCE_REPO:-https://github.com/Mckl77/shopbr-ia.git}"
REF="${1:-main}"

REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

echo "══ 1/5 Recuperation du code ($REF) ══"
WORKDIR=$(mktemp -d)
git clone --depth 1 --branch "$REF" "$SOURCE_REPO" "$WORKDIR" 2>/dev/null \
  || { git clone "$SOURCE_REPO" "$WORKDIR" && git -C "$WORKDIR" checkout "$REF"; }
SHORT_SHA=$(git -C "$WORKDIR" rev-parse --short HEAD)
IMAGE="$REGISTRY/$ECR_REPO:$SHORT_SHA"

echo "══ 2/5 Build de l'image ($IMAGE) ══"
docker build -t "$IMAGE" -t "$REGISTRY/$ECR_REPO:latest" "$WORKDIR"

echo "══ 3/5 Push vers ECR ══"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"
docker push "$IMAGE"
docker push "$REGISTRY/$ECR_REPO:latest"

echo "══ 4/5 Deploiement sur EKS ══"
aws eks update-kubeconfig --name "$EKS_CLUSTER" --region "$AWS_REGION"
kubectl apply -f "$(dirname "$0")/../k8s/service.yaml"
kubectl apply -f "$(dirname "$0")/../k8s/deployment.yaml"
kubectl -n shopbr set image deployment/shopbr-api       shopbr-api="$IMAGE"
kubectl -n shopbr set image deployment/shopbr-dashboard shopbr-dashboard="$IMAGE"

echo "══ 5/5 Verification (rollback auto si echec) ══"
if kubectl -n shopbr rollout status deployment/shopbr-api --timeout=300s \
   && kubectl -n shopbr rollout status deployment/shopbr-dashboard --timeout=300s; then
  echo "Deploiement reussi : $IMAGE"
  kubectl -n shopbr get pods -o wide
else
  echo "Echec - rollback vers la version precedente"
  kubectl -n shopbr rollout undo deployment/shopbr-api
  kubectl -n shopbr rollout undo deployment/shopbr-dashboard
  exit 1
fi
