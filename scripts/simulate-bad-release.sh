#!/bin/bash
# Simulates a broken release by pointing production at a non-existent image tag,
# then shows the rollout failing and rolling back. Use this to record your
# rollback demonstration evidence for the project deliverables.
set -e

NAMESPACE=production
ECR_REPO="395671099988.dkr.ecr.ap-south-1.amazonaws.com/campus-app"
BAD_TAG="does-not-exist"

echo "Deploying broken image tag to ${NAMESPACE}..."
kubectl set image deployment/campus-app campus-app=${ECR_REPO}:${BAD_TAG} -n ${NAMESPACE}

echo "Watching rollout (expect this to fail / timeout)..."
kubectl rollout status deployment/campus-app -n ${NAMESPACE} --timeout=60s || true

echo "Rolling back to last good revision..."
kubectl rollout undo deployment/campus-app -n ${NAMESPACE}

echo "Rollout history:"
kubectl rollout history deployment/campus-app -n ${NAMESPACE}
