# Runbook: Failed Build or Failed Deployment

## 1. Jenkins build fails at "Build & Unit Test"
- Open the Jenkins console log for the failed build.
- Check `application/target/surefire-reports/` for the failing test class.
- Fix the code or test on a feature branch, re-run the pipeline. Production is
  never touched, since the pipeline stops before the Docker stage.

## 2. Docker build fails
- Usually a Dockerfile path issue or a missing dependency in the JAR.
- Run `docker build -f docker/Dockerfile -t test-local .` locally to reproduce.

## 3. Push to ECR fails
- Check the EC2 instance's IAM role has `ecr:GetAuthorizationToken`,
  `ecr:BatchCheckLayerAvailability`, `ecr:PutImage`, `ecr:InitiateLayerUpload`,
  `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`.
- Confirm the region matches the ECR repo region (ap-south-1).

## 4. Deployment to staging/production fails or times out
- Run `kubectl describe pod <pod-name> -n <namespace>` to see the failure reason
  (ImagePullBackOff, CrashLoopBackOff, failed readiness probe, etc).
- `kubectl logs <pod-name> -n <namespace>` for application-level errors.
- If the rollout does not stabilize within the timeout, Jenkins marks the stage
  failed and the `post { failure { ... } }` block automatically runs
  `kubectl rollout undo` against production.

## 5. Smoke test fails in staging
- Pipeline stops before reaching the manual approval gate - production is
  never touched.
- Reproduce locally: `curl -v http://<staging-service-ip>/health`

## 6. Manual rollback (if automatic rollback doesn't trigger)
```bash
kubectl rollout undo deployment/campus-app -n production
kubectl rollout status deployment/campus-app -n production
```

## 7. Verifying which version is live after any incident
```bash
curl http://<service-ip>/version
kubectl rollout history deployment/campus-app -n production
```
