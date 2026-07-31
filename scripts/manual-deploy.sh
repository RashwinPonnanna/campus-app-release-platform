#!/bin/bash
# Applies namespaces + manifests by hand before Jenkins takes over via kubectl set image.
set -e

echo "Applying namespaces..."
kubectl apply -f kubernetes/namespaces.yaml

echo "Applying dev manifests..."
kubectl apply -f kubernetes/dev/

echo "Applying staging manifests..."
kubectl apply -f kubernetes/staging/

echo "Applying production manifests..."
kubectl apply -f kubernetes/production/

echo "Done. Remember to create the following before pods can start:"
echo "  1. ECR pull secret in each namespace:"
echo "     kubectl create secret docker-registry ecr-secret \\"
echo "       --docker-server=<account-id>.dkr.ecr.ap-south-1.amazonaws.com \\"
echo "       --docker-username=AWS \\"
echo "       --docker-password=\$(aws ecr get-login-password --region ap-south-1) \\"
echo "       -n <namespace>"
echo "  2. App secret in each namespace:"
echo "     kubectl create secret generic campus-app-secrets --from-literal=DB_PASSWORD=<value> --from-literal=API_KEY=<value> -n <namespace>"
