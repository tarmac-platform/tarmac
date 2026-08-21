# Demo Script — Tarmac Platform (~90 seconds)

Record this as a single continuous screen capture. Use a fresh service name
each take (e.g. `demo-svc-1`, `demo-svc-2`). Pre-warm: have the portal open
in a browser tab and the kind cluster running.

## Pre-flight checklist

- [ ] EC2 running, portal up at `http://localhost:3000` via SSH tunnel
- [ ] Kind cluster up, `kubectl get apps -n argocd` all Healthy
- [ ] Docker Desktop running (kind nodes need it)
- [ ] Terminal open with `curl` ready
- [ ] GitHub open in a tab (for the PR/CI view)
- [ ] ArgoCD UI forwarded (`kubectl port-forward svc/argocd-server -n argocd 8080:443`)

## Shots

### 1. Scaffold a new service (~15s)

- Portal > Create... > Node.js Express API
- Fill: name=`demo-run`, description="demo service", costCenter=`eng`, team=`platform`
- Repo URL: `github.com / tarmac-platform / demo-run`
- Click **Create**
- Wait for all steps to complete (green checkmarks)
- Show output links: Repository + Open in catalog

### 2. Show CI already running (~10s)

- Click the Repository link → GitHub repo page
- Click **Actions** tab → CI workflow running (triggered by initial commit)
- Wait for green ✓ (or cut to a pre-recorded green run if timing is tight)
- Show the jobs: test → build → scan → policy-check → deploy (all green)

### 3. Show the policy rejection (~20s)

This is the money shot for the guardrails story. Pre-stage:

```bash
# In the demo-run repo, create a branch with a :latest violation
git clone https://github.com/tarmac-platform/demo-run.git /tmp/demo-run
cd /tmp/demo-run
git checkout -b feat/bad-image
# Edit k8s/deployment.yaml: change image to nginx:latest
sed -i 's|rajvasoya06/demo-run:init|nginx:latest|' k8s/deployment.yaml
git add . && git commit -m "use nginx:latest"
git push -u origin feat/bad-image
gh pr create --title "feat: use nginx" --body "test" --head feat/bad-image
```

- Show the PR page → CI running
- policy-check fails in ~15s (runs parallel to build now)
- Click the failed check → **Summary** tab shows the rejection:
  ```
  ### Policy Check Failed
  disallow-latest-tag: image tags must be pinned to a version or digest, not `latest`.
  ```
- This is visible directly on the PR summary, no log diving needed

### 4. Fix and pass (~10s)

```bash
sed -i 's|nginx:latest|nginx:1.25|' k8s/deployment.yaml
git add . && git commit -m "fix: pin image tag"
git push
```

- Show PR checks turn green
- (Don't merge — this is just demonstrating the guardrail)

### 5. Preview environment (~20s)

The PR from step 3 already triggered a preview. Show it:

```bash
curl -H "Host: demo-run-pr-1.127.0.0.1.sslip.io" http://localhost
```

- Expected: service response from the PR branch
- Show the Ingress in the cluster:
  ```bash
  kubectl get ingress -n demo-run-pr-1
  ```

### 6. Teardown (~10s)

- Close the PR on GitHub (click "Close pull request")
- Wait ~30s (requeueAfterSeconds: 30)
- Show namespace gone:
  ```bash
  kubectl get ns demo-run-pr-1
  # NotFound
  ```
- Show the preview URL returns 404:
  ```bash
  curl -H "Host: demo-run-pr-1.127.0.0.1.sslip.io" http://localhost
  # 404
  ```

## Timing budget

| Step | Target | Notes |
|------|--------|-------|
| 1. Scaffold | 15s | Portal form is fast; scaffolder completes in ~10s |
| 2. CI green | 10s | Can cut to a pre-recorded run to save time |
| 3. Policy rejection | 20s | policy-check now runs in ~15s (parallel to build) |
| 4. Fix | 10s | Single commit + push |
| 5. Preview | 20s | curl + kubectl |
| 6. Teardown | 10s | Close PR + verify |
| **Total** | **~85s** | |

## Notes for recording

- If Docker Hub image pull is slow on first run, pre-warm with:
  `docker pull rajvasoya06/demo-run:<sha>` won't help since the kind node
  does the pull. Just ensure a previous scaffold has already pulled
  `node:22-alpine` into the kind node cache.

- The ArgoCD ApplicationSet polls every 30s. Preview env appears within one
  poll cycle after PR creation. If timing is tight, show the Application
  being created in the ArgoCD UI rather than waiting for the pod.

- Speed up the recording with 1.5x playback in post. The 90s target is
  final playback time, not wall-clock recording time.

## What's NOT in this recording (deliberate)

- Crossplane provisioning real AWS resources (weeks 8-9)
- Slack notifications (dropped — in-portal notification fires; demo never
  shows a chat window)
- cosign image signing / verifyImages (week 11)
- Real DNS/TLS with `*.preview.kwikflo.in` (week 13)
