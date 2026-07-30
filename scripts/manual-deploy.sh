#!/bin/bash
# Use this to apply namespaces + manifests by hand before automating via Jenkins.
set -e

echo "Applying namespaces..."
kubectl apply -f kubernetes/namespaces.yaml

echo "Applying dev manifests..."
kubectl apply -f kubernetes/dev/

echo "Applying staging manifests..."
kubectl apply -f kubernetes/staging/

echo "Applying production manifests (excluding secrets)..."
kubectl apply -f kubernetes/production/deployment.yaml
kubectl apply -f kubernetes/production/service.yaml

echo "Done. Remember to create real secrets manually:"
echo "  kubectl create secret generic campus-app-secrets --from-literal=DB_PASSWORD=<value> -n production"
