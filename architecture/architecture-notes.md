# Architecture: Campus Application Release Platform

## Flow
Developer -> Git (dev/staging/main branches) -> Jenkins on EC2 -> Maven build & test
-> Docker image (non-root, numeric UID) -> Amazon ECR -> k3s on EC2 (dev/staging/production namespaces)
-> Smoke test -> Manual approval -> Production -> health check -> automatic rollback on failure

## Why this architecture
- **k3s over full EKS**: single EC2 instance is enough for a portfolio-scale
  demo and avoids EKS control-plane cost, while still using real Kubernetes
  objects (Deployments, Services, namespaces, probes) that map directly to
  production concepts.
- **ECR over Docker Hub**: keeps everything inside AWS IAM boundaries, avoids
  public image exposure.
- **Separate namespaces per environment** instead of separate clusters:
  realistic for a small team/college budget, while still demonstrating
  isolation via secrets and configs scoped per namespace.
- **Manual approval gate before production**: mirrors real change-control
  processes; nothing reaches production without a human decision recorded in
  the Jenkins build history.
- **Numeric UID in the Dockerfile**: Kubernetes' `runAsNonRoot: true` check
  cannot verify a named user (e.g. `appuser`) against `/etc/passwd` inside the
  image at admission time - it requires a numeric UID to guarantee the
  container isn't running as root without inspecting the filesystem.

## Failure handling
- Failed tests: pipeline stops at the test stage, nothing is built or pushed.
- Failed staging smoke test: pipeline stops before the approval gate.
- Failed/unhealthy production rollout: Jenkins `post { failure { ... } }`
  block runs `kubectl rollout undo` automatically.

## Security decisions
- Docker image runs as a non-root, numeric UID (1001).
- Secrets are never stored in Git; applied directly via `kubectl create
  secret` and referenced with `envFrom.secretRef` in the deployment.
- Image tags are always `<build-number>-<git-commit>` for traceability. A
  `:latest` tag is also pushed for convenience when manually applying
  manifests before Jenkins takes over, but Jenkins itself always deploys the
  specific versioned tag via `kubectl set image`.

## Resource sizing
Requests/limits are set conservatively (256Mi/512Mi per pod) to run
comfortably on a mid-sized EC2 instance (t3.medium or larger recommended)
across three namespaces simultaneously plus k3s/Jenkins system overhead. On
free-tier-sized instances (t2/t3.micro, 1GB RAM), reduce limits further or
run fewer replicas to avoid overcommitting node memory during rolling
updates.

## What would change at real production scale
- Move from k3s single-node to managed EKS with multiple worker nodes across AZs.
- Add an ingress controller with TLS instead of raw ClusterIP services.
- Replace `kubectl set image` with GitOps (ArgoCD/Flux).
- Externalize secrets to AWS Secrets Manager or Parameter Store.
