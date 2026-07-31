# Campus Application Release Platform

Project 1 of the 10-project AWS Cloud & DevOps portfolio series.
End-to-end CI/CD: Git commit -> Jenkins -> Maven build/test -> Docker
(non-root) -> Amazon ECR -> k3s (dev/staging/production namespaces) ->
smoke test -> manual approval -> production, with automatic rollback.

## Repo structure
```
application/    Spring Boot app (health + version endpoints, unit tests, pom.xml)
docker/         Multi-stage, non-root (numeric UID) Dockerfile
kubernetes/     Namespaces + per-environment Deployment/Service manifests
jenkins/        Jenkinsfile (full pipeline)
scripts/        Manual deploy + rollback simulation scripts
runbooks/       Failed build/deployment runbook
architecture/   Architecture decisions and rationale
```

---

## Step 0: Launch the EC2 instance

Recommended: **t3.medium** (2 vCPU, 4GB RAM) or larger, Ubuntu 24.04, region
`ap-south-1`. A t2/t3.micro (1GB RAM) works but gets tight running Jenkins +
k3s + three app namespaces simultaneously - expect to reduce resource
requests/limits if you stay on free tier.

Security group: open **22** (SSH) and **8080** (Jenkins UI) to your IP. Ports
80/443 are only needed if you later expose the app publicly - not required
for this project.

## Step 1: Base packages

```bash
sudo apt update
sudo apt install -y openjdk-21-jdk maven unzip
java -version   # confirm 21.x
```

## Step 2: Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
docker --version
```
(Log out/in or run `newgrp docker` for the group change to apply to your shell.)

## Step 3: k3s (Kubernetes)

```bash
curl -sfL https://get.k3s.io | sh -
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
source ~/.bashrc
kubectl get nodes   # should show Ready after ~10s
```

## Step 4: Jenkins

```bash
sudo mkdir -p /etc/apt/keyrings
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list

sudo apt update
sudo apt install -y jenkins
sudo systemctl enable --now jenkins
sudo systemctl status jenkins   # confirm active (running)
```

Give Jenkins access to Docker and kubectl:
```bash
sudo usermod -aG docker jenkins
sudo mkdir -p /var/lib/jenkins/.kube
sudo cp /etc/rancher/k3s/k3s.yaml /var/lib/jenkins/.kube/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.kube
sudo systemctl restart jenkins
```

Get the initial admin password and open `http://<ec2-public-ip>:8080`:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
Install suggested plugins during setup.

## Step 5: AWS CLI

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
aws configure   # access key, secret key, region ap-south-1, output json
```
Better long-term: skip static keys entirely and attach an IAM role with ECR
permissions directly to the EC2 instance (EC2 Console -> instance -> Actions
-> Security -> Modify IAM role).

Give Jenkins access to the same AWS credentials:
```bash
sudo mkdir -p /var/lib/jenkins/.aws
sudo cp ~/.aws/credentials /var/lib/jenkins/.aws/credentials
sudo cp ~/.aws/config /var/lib/jenkins/.aws/config
sudo chown -R jenkins:jenkins /var/lib/jenkins/.aws
```

## Step 6: Create the ECR repository (skip if it already exists)

```bash
aws ecr create-repository --repository-name campus-app --region ap-south-1
aws sts get-caller-identity --query Account --output text   # note your account ID
```
If your account ID differs from `395671099988`, update it in
`jenkins/Jenkinsfile` and all three `kubernetes/*/deployment.yaml` files
before proceeding.

## Step 7: Clone this repo onto the EC2 instance

```bash
git clone https://github.com/RashwinPonnanna/campus-app-release-platform.git
cd campus-app-release-platform
```

## Step 8: Apply namespaces and manifests

```bash
chmod +x scripts/*.sh
./scripts/manual-deploy.sh
```
Pods will show `ImagePullBackOff` at this point - expected, no image has
been pushed to ECR yet.

## Step 9: Create secrets in every namespace

ECR pull secret (needed so Kubernetes can pull from your private registry):
```bash
for ns in dev staging production; do
  kubectl create secret docker-registry ecr-secret \
    --docker-server=395671099988.dkr.ecr.ap-south-1.amazonaws.com \
    --docker-username=AWS \
    --docker-password=$(aws ecr get-login-password --region ap-south-1) \
    -n $ns
done
```
Note: this token expires after 12 hours. For a long-running lab, re-run this
block periodically, or set up a CronJob to refresh it automatically.

App secret (placeholder values are fine for this lab project):
```bash
for ns in dev staging production; do
  kubectl create secret generic campus-app-secrets \
    --from-literal=DB_PASSWORD=temp123 \
    --from-literal=API_KEY=temp123 \
    -n $ns
done
```

## Step 10: Create the Jenkins pipeline job

- New Item -> name it `campus-app-release-platform` -> Pipeline -> OK
- Pipeline section -> Definition: **Pipeline script from SCM**
- SCM: Git -> Repository URL: this repo's GitHub URL -> Branch: `*/main`
- Script Path: `jenkins/Jenkinsfile`
- Save

## Step 11: Run it

Click **Build Now**. Expected flow:
1. Checkout
2. Build & Unit Test (Maven)
3. Docker Build (multi-stage, non-root)
4. Push to ECR (versioned tag + `latest`)
5. Deploy to Dev (`kubectl set image` + rollout wait)
6. Deploy to Staging
7. Smoke Test - Staging (`curl /health`)
8. Manual Approval for Production - pauses here, click **Deploy** in the
   Jenkins UI to continue
9. Deploy to Production
10. Post-Deploy Health Check

If anything fails, check `runbooks/failed-build-and-deployment.md` first.

## Proving the rollback requirement

```bash
./scripts/simulate-bad-release.sh
```
Deploys a broken image tag to production, watches the rollout fail, then
runs `kubectl rollout undo` automatically. Record this for your project
deliverables.
