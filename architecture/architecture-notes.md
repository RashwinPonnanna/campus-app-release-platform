# Architecture: Campus Application Release Platform

## Flow
Developer -> Git (dev/staging/main branches) -> Jenkins on EC2 -> Maven build & test
-> Docker image (non-root) -> Amazon ECR -> k3s on EC2 (dev/staging/production namespaces)
-> Smoke test -> Manual approval -> Production -> CloudWatch logs/alerts

## Why this architecture
- **k3s over full EKS**: single small EC2 instance is enough for a portfolio-scale
  demo and avoids EKS control-plane cost, while still using real Kubernetes objects
  (Deployments, Services, namespaces, probes) that map directly to production concepts.
- **ECR over Docker Hub**: keeps everything inside AWS IAM boundaries, avoids
  public image exposure, and matches what most companies use in a real pipeline.
- **Separate namespaces per environment** instead of separate clusters: realistic
  for a small team/college budget, while still demonstrating isolation via
  resource quotas, secrets, and configs scoped per namespace.
- **Manual approval gate before production**: mirrors real change-control
  processes; nothing reaches production without a human decision recorded in
  the Jenkins build history.

## Failure handling
- Failed tests: pipeline stops at the test stage, nothing is built or pushed.
- Failed staging smoke test: pipeline stops before the approval gate.
- Failed/unhealthy production rollout: Jenkins `post { failure { ... } }` block
  runs `kubectl rollout undo` automatically.

## Security decisions
- Docker image runs as a non-root user (`appuser`), enforced by `securityContext.runAsNonRoot`.
- Secrets are never stored in Git; applied directly via `kubectl create secret`
  and referenced with `envFrom.secretRef` in the deployment.
- Image tags are always `<build-number>-<git-commit>` - never `latest` - so
  every running pod is traceable back to an exact commit.

## What would change at real production scale
- Move from k3s single-node to managed EKS with multiple worker nodes across AZs.
- Add a service mesh or ingress controller with TLS instead of raw ClusterIP services.
- Replace `kubectl set image` with GitOps (ArgoCD/Flux) driven by the same
  image-tag-per-commit convention.
- Externalize secrets to AWS Secrets Manager or Parameter Store instead of
  plain Kubernetes Secrets.
