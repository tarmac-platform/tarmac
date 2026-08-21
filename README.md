# Tarmac

A self-service internal developer platform built for demonstration and learning. Backstage portal, ArgoCD GitOps, Kyverno policy guardrails, and per-PR preview environments — all running on a local kind cluster.

<!-- TODO: Replace with actual GIF once recorded -->
<!-- ![Demo](docs/demo.gif) -->

## What it does

A developer fills a form in the Backstage portal. Within 60 seconds:

1. A private GitHub repo is created with a Node.js Express API, Dockerfile, CI workflow, and Kubernetes manifests
2. A PR opens against the GitOps config repo — merge it and ArgoCD deploys the service
3. CI runs on every push: test, build, Trivy scan, Kyverno policy check, deploy
4. Open a PR on the service repo — a preview environment appears at `<service>-pr-<N>.127.0.0.1.sslip.io`
5. Close the PR — the preview is torn down automatically

Push a non-compliant manifest (`:latest` tag, missing resource limits, running as root, missing labels) and the policy check fails with a clear error directly on the PR summary.

## Architecture

```
Developer
    │
    ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────────┐
│  Backstage      │────►│  GitHub           │────►│  ArgoCD             │
│  (Portal + API) │     │  (Repos + Actions)│     │  (GitOps engine)    │
└─────────────────┘     └──────────────────┘     └─────────────────────┘
                                │                          │
                                │ CI: test/build/          │ Sync
                                │ scan/policy/deploy       │
                                ▼                          ▼
                        ┌──────────────────┐     ┌─────────────────────┐
                        │  Docker Hub      │     │  kind cluster       │
                        │  (Container      │     │  ┌─────────────┐   │
                        │   registry)      │     │  │ Kyverno     │   │
                        └──────────────────┘     │  │ (admission) │   │
                                                 │  └─────────────┘   │
                                                 │  ┌─────────────┐   │
                                                 │  │ingress-nginx│   │
                                                 │  └─────────────┘   │
                                                 └─────────────────────┘
```

## Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| Portal | Backstage | Service catalog + self-service UI |
| Golden path | Node.js/Express template | Opinionated service scaffold |
| GitOps | ArgoCD (app-of-apps) | Reconciles cluster state from git |
| Policy | Kyverno (CLI + admission) | Enforced twice: CI gate and admission webhook |
| CI/CD | GitHub Actions (reusable workflow) | test → build → scan → policy → deploy |
| Preview envs | ArgoCD ApplicationSet (PR generator) | Per-PR namespace + ingress, auto-teardown |
| Registry | Docker Hub | Public images, SHA-tagged |
| Ingress | ingress-nginx + sslip.io | Local hostnames without DNS config |
| Local runtime | kind | Free, identical everywhere |

## Quick Start

Prerequisites: Docker Desktop, kind, kubectl, helm, argocd CLI, gh CLI.

```bash
make up          # Create kind cluster
make bootstrap   # Install ArgoCD + app-of-apps (the only imperative step)
```

The app-of-apps reconciles everything else from git: Kyverno, policies, ingress-nginx.

For the Backstage portal, see [docs/dev-box.md](docs/dev-box.md) — it runs on an EC2 instance.

## Deliberate Tradeoffs

These are design decisions, not oversights:

- **Public subnets, no NAT** — saves $41/mo. Production would use private subnets + NAT.
- **sslip.io for local hostnames** — zero DNS config. Real DNS (`*.preview.kwikflo.in`) lands at week 13 on EKS.
- **Single tenant** — one `team` label, no per-team RBAC. Sufficient for the demo scope.
- **Docker Hub free tier** — 100 pulls/6h anonymous per IP. `imagePullPolicy: IfNotPresent` limits repeat pulls. Authenticated raises to 200/6h.
- **Slack dropped** — the in-portal notification fires; the demo never cuts to a chat window. Recorded as a deliberate scope cut.
- **kind for weeks 0-7** — free and identical on every machine. EKS is a week-12 burst for the final recording.

## Repo Structure

```
tarmac/                          # Platform monorepo (this repo)
├── .github/workflows/           # policy-tests.yml + service-ci.yml (reusable)
├── bootstrap/
│   ├── terraform/               # EC2 dev box
│   └── kind/                    # Cluster config
├── portal/                      # Backstage app
│   └── templates/
│       └── node-express-api/    # The golden-path template
├── policies/                    # Kyverno ClusterPolicies + test fixtures
├── scripts/                     # policy-test.sh
├── docs/                        # dev-box.md, demo-script.md
└── Makefile

tarmac-config/                   # GitOps target (separate repo)
└── clusters/local/              # ArgoCD Applications + ApplicationSets
```

## Security Notes

- `permission-backend-module-allow-all-policy` is the Backstage default — fine for localhost, must be replaced before network exposure (week 13).
- Secrets (`*.pem`, terraform state, GitHub App keys) exist on disk but are untracked. Verified not in git history.
- The GitHub App (`tarmac-backstage`) has write access to all org repos — this is intentional for the scaffolder to create repos and PRs.

## License

MIT (added week 14)
