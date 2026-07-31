# Runbook: Failed Build or Failed Deployment

## 1. Jenkins build fails at "Build & Unit Test"
Check the Jenkins console log and `application/target/surefire-reports/`.
Production is never touched, since the pipeline stops before the Docker stage.

## 2. Docker build fails
Reproduce locally: `docker build -f docker/Dockerfile -t test-local .`

## 3. Push to ECR fails
Confirm the EC2 instance's IAM role (or configured credentials) has
`ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`,
`ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`.

## 4. Pods stuck in ImagePullBackOff / ErrImagePull
Almost always one of:
- The ECR pull secret (`ecr-secret`) doesn't exist in that namespace, or its
  token expired (tokens last 12 hours - recreate with a fresh
  `aws ecr get-login-password`).
- The image tag referenced doesn't actually exist in ECR yet - check with
  `aws ecr describe-images --repository-name campus-app --region ap-south-1`.

## 5. Pods stuck in CreateContainerConfigError
Usually means `campus-app-secrets` doesn't exist in that namespace. Check:
`kubectl get secret campus-app-secrets -n <namespace>`

## 6. "container has runAsNonRoot and image has non-numeric user" error
The image was built from an old Dockerfile using a named user instead of a
numeric UID. Confirm the Dockerfile uses `USER 1001` (numeric), not
`USER appuser` (named), then rebuild and push a fresh image.

## 7. Rollout hangs / times out
Check pod status and events:
```bash
kubectl get pods -n <namespace>
kubectl describe pod -n <namespace> -l app=campus-app
```
Common causes: stale ReplicaSets left over from earlier manual edits, or the
node being out of allocatable memory/CPU (check with
`kubectl describe node | grep -A5 "Allocated resources"`). If overcommitted,
reduce `resources.requests`/`limits` in the deployment YAMLs or use a larger
instance.

## 8. Manual rollback (if automatic rollback doesn't trigger)
```bash
kubectl rollout undo deployment/campus-app -n production
kubectl rollout status deployment/campus-app -n production
```

## 9. Verifying which version is live after any incident
```bash
curl http://<service-ip>/version
kubectl rollout history deployment/campus-app -n production
```
