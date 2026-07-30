# Campus Application Release Platform

Project 1 of the 10-project AWS Cloud & DevOps portfolio series.
End-to-end CI/CD platform: Git commit -> Jenkins -> Maven build/test -> Docker
(non-root) -> Amazon ECR -> k3s (dev/staging/production namespaces) ->
smoke test -> manual approval -> production, with automatic rollback on failure.

## Repo structure
```
application/    Spring Boot app (health + version endpoints, unit tests, pom.xml)
docker/         Multi-stage, non-root Dockerfile
kubernetes/     Namespaces + per-environment Deployment/Service manifests
jenkins/        Jenkinsfile (full pipeline)
scripts/        Manual deploy + rollback simulation scripts
runbooks/       Failed build/deployment runbook
architecture/   Architecture decisions and rationale
```

## Before running the pipeline
1. Push this repo to your own GitHub account (don't fork - write your own history).
2. Create an ECR repo:
   ```bash
   aws ecr create-repository --repository-name campus-app --region ap-south-1
   ```
3. Replace placeholders:
   - `<ACCOUNT_ID>` and `<ECR_REPO_URL>` in `jenkins/Jenkinsfile` and `scripts/simulate-bad-release.sh`
   - `<ECR_REPO_URL>` in `kubernetes/*/deployment.yaml`
4. On the Jenkins EC2 host: install Docker Pipeline + Amazon ECR / kubectl,
   add `jenkins` user to the `docker` group, and configure AWS credentials.
5. Apply namespaces + manifests once by hand (`scripts/manual-deploy.sh`) before
   wiring up Jenkins auto-deploy, so dev/staging/production Deployments exist
   for `kubectl set image` to target.
6. Create the real Kubernetes secret (never commit real values):
   ```bash
   kubectl create secret generic campus-app-secrets --from-literal=DB_PASSWORD=<value> -n production
   ```

## Jenkins job setup
- New Item -> Pipeline
- Pipeline script from SCM -> Git -> your repo URL -> branch `main`
- Script path: `jenkins/Jenkinsfile`

## Proving the rollback requirement
Run `scripts/simulate-bad-release.sh` to deploy a broken image tag to
production and watch the automatic `kubectl rollout undo`. Record this for
your deliverables.
