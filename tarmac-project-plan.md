# Tarmac — Self-Service Internal Developer Platform

**One-line pitch:** Tarmac lets a developer request a fully provisioned, policy-compliant, monitored microservice through a simple form — turning a 2-3 day manual infra request into a self-service action that takes minutes, with automatic per-PR preview environments and guardrails enforced underneath.

**Owner:** Raj Vasoya · **Type:** Solo portfolio build · **Revised:** 2026-08-11

---

## 1. The Problem

At most companies past a certain size, getting a new service into production means:
1. File a ticket with the platform/DevOps team
2. Wait for someone to manually create the repo, write Terraform, set up CI/CD, configure Kubernetes manifests
3. Hope it follows org standards (resource limits, security policies, labeling) — often it doesn't, because enforcement is manual/review-based
4. Wait 2-3 days minimum, tying up a DevOps engineer the whole time

This is exactly the problem **Platform Engineering** exists to solve, and it's one of the most in-demand DevOps specializations right now — because it's about developer experience and self-service, not just infrastructure automation.

The core insight Tarmac is built around: the value isn't automation, it's that **the paved road is easier than the dirt road**. Compliance then happens by default instead of by review.

## 2. What Tarmac Does

Tarmac is a self-service platform with four pillars:

1. **Golden path scaffolding** — a developer picks a service template from a catalog and gets a working repo instantly (boilerplate, Dockerfile, CI pipeline, health checks — all pre-wired)
2. **Self-service infra provisioning** — the platform provisions real cloud infra (namespace, database, IAM role) via Crossplane compositions, without the developer touching Terraform directly
3. **Policy-as-code guardrails** — every deploy is checked against org rules (no `:latest` tags, mandatory resource limits, non-root containers, required labels, signed images) via Kyverno, *before* it reaches the cluster
4. **Ephemeral preview environments** — every PR automatically gets a live, isolated environment with a real URL, auto-destroyed when the PR closes/merges

### Worked example: "Priya needs a new microservice"

| Step | Without Tarmac | With Tarmac |
|---|---|---|
| Request | Files a Jira ticket | Fills a form in the Tarmac portal |
| Scaffolding | DevOps eng manually copies boilerplate | Backstage template auto-generates repo, CI, Dockerfile |
| Infra | DevOps eng hand-writes Terraform for RDS/IAM/VPC | Crossplane claim auto-provisions infra from a pre-approved composition |
| Compliance | Caught (or missed) in manual review | Kyverno rejects non-compliant manifests automatically, before deploy |
| CI/CD | Hand-configured pipeline | Reusable GitHub Actions workflow, already wired into the scaffolded repo |
| PR review | Reviewer reads a diff | ArgoCD ApplicationSet spins up `pr-42.preview.kwikflo.in` — a real, clickable environment |
| Cleanup | Manual, often forgotten (cost leakage) | Auto-teardown on PR close/merge |
| Time | 2-3 days | Minutes |

---

## 3. Locked Decisions

| # | Decision | Choice | Why |
|---|---|---|---|
| 1 | Orchestrator | GitOps — scaffolder opens PR to config repo, ArgoCD reconciles | Auditable, drift-correcting; deletes a component instead of building one |
| 2 | IaC split | Terraform builds the platform cluster; Crossplane provisions tenant infra | Split by lifecycle, not by tool preference |
| 3 | Dev environment | kind for weeks 0-6, real EKS only for the final demo | $50/mo cap makes a persistent EKS cluster arithmetically impossible |
| 4 | Budget | Under $50/mo, hard AWS Budget + SNS alert | Forces local-first and scripted teardown |
| 5 | DNS | `preview.kwikflo.in` delegated to Route53 | Domain already owned; no MX record, so subdomain delegation is email-risk-free |
| 6 | Portal | Backstage | Heaviest dependency, but the catalog is a real pillar and the resume keyword |
| 7 | Schedule | Milestone A ~wk 6-7 (recordable), Milestone B ~wk 14 | Something showable halfway through |
| 8 | Capacity | 15-20 hrs/week, evenings + weekends | 8 weeks was ~half of what this needs solo |
| 9 | Cloud | AWS, `ap-south-1`, account `360999005486` | Reuses CloudSentry Terraform; account is a clean slate |
| 10 | Golden path | Node.js/Express only | Deliberately narrow at launch |

## 4. Architecture

```
Developer
   │
   ▼
[Backstage Portal] ── scaffolder action: publish:github:pull-request
   │
   ├──► creates service repo from golden-path template
   │
   └──► opens PR on tarmac-config/ with the Crossplane Claim + K8s manifests
              │
              │  ◄── PR-time gate: kyverno CLI in GitHub Actions
              │      (fail fast — error visible in the PR, not in a cluster log)
              ▼
        merge to main
              │
              ▼
      [ArgoCD] watches tarmac-config/
              │
              ├──► Claim ──► [Crossplane] ──► real AWS: RDS, IAM role, namespace
              │
              └──► Deployment ──► [Kyverno admission] ──► cluster
                                      reject ──► sync error, surfaced in Backstage

[ArgoCD ApplicationSet + PR generator] ──► pr-42.preview.kwikflo.in
                                            auto-teardown on PR close

[Prometheus + Grafana] — provisioning latency, policy violation rate,
                          active preview envs, cost per env
```

Two things this resolves beyond deleting the undefined `[Orchestrator]` box:

- **Kyverno runs twice, deliberately.** CLI in CI for fast developer feedback; admission controller in-cluster as the actual enforcement boundary. CI-only is bypassable. Admission-only means the developer discovers the error minutes later in a sync log. Being able to explain that distinction is an interview asset.
- **Drift self-corrects.** Nothing reaches the cluster except through git.

## 5. Tech Stack

| Layer | Tool | Purpose |
|---|---|---|
| Portal / catalog | Backstage | Service catalog + self-service UI |
| Golden path | Node.js/Express template | The one opinionated stack Tarmac supports well |
| GitOps engine | ArgoCD (+ app-of-apps) | Reconciles `tarmac-config`; also bootstraps the platform's own components |
| Tenant provisioning | Crossplane + `provider-aws` | Per-service RDS, IAM role, namespace from a pre-approved composition |
| Platform cluster | Terraform | One-time EKS/VPC build (reused from CloudSentry) |
| Policy | Kyverno (CLI + admission) | Policy-as-code, enforced twice |
| Supply chain | Trivy + cosign + Kyverno `verifyImages` | Scan, sign, reject unsigned images |
| CI/CD | GitHub Actions reusable workflows | Build/test/scan/deploy |
| Preview envs | ArgoCD ApplicationSet (PR generator) | Per-PR ephemeral environments, auto-teardown |
| Local runtime | kind | Weeks 0-6; free, identical on camera |
| Demo runtime | AWS EKS | Weeks 12-14 burst only |
| Ingress / DNS / TLS | ingress-nginx, external-dns, cert-manager | `*.preview.kwikflo.in` with real TLS |
| Observability | Prometheus + Grafana | Platform health, not app health |
| Secrets | GitHub OIDC + AWS Secrets Manager | No long-lived keys in CI |

## 6. Cost Model

The $50/mo cap is the binding constraint on the whole design. EKS control plane alone is **$73/mo** at $0.10/hr, so a persistent cluster is out — decision 3 is arithmetic, not preference.

**No NAT gateway.** NAT is $0.056/hr in `ap-south-1` ≈ **$41/mo** plus data processing, and buys nothing a demo can see. Nodes go in public subnets, guarded by security groups. CloudSentry's `eks.tf` already does this (`subnet_ids = module.vpc.public_subnets`), so the reuse holds. **State this tradeoff in the README rather than hiding it** — production would use private subnets + NAT.

**EKS as a burst, not a resident** (weeks 12-14 record-and-verify window):

| Resource | Rate (ap-south-1) | 40-hr burst |
|---|---|---|
| EKS control plane | $0.100/hr | $4.00 |
| 2× t3.medium spot | ~$0.025/hr | $1.00 |
| ALB | $0.0225/hr | $0.90 |
| RDS db.t4g.micro | ~$0.016/hr | $0.64 |
| Route53 hosted zone | $0.50/mo | $0.50 |
| **Total** | | **~$7** |

Everything else runs on kind for $0. Leaves headroom for a second burst if the first recording goes badly.

Guardrails, built week 0 — not week 14:
- AWS Budget at $50 with SNS alerts at 50/80/100%
- `make down` destroys the whole platform; week 14 ends with a Cost Explorer screenshot showing $0
- The plan previously sold cleanup automation while having none of its own. Fixed.

## 7. Repo Structure

```
tarmac/                        # platform monorepo
├── bootstrap/                 # week 0
│   ├── terraform/             # OIDC provider, scoped CI role, budget+SNS, Route53 zone
│   └── kind/                  # kind config + app-of-apps seed
├── portal/                    # Backstage app + custom plugins
├── templates/
│   └── node-express-api/      # the one golden path
├── compositions/              # Crossplane XRDs + Compositions (tenant infra)
├── terraform/                 # platform cluster only (from CloudSentry vpc.tf/eks.tf)
├── policies/
│   ├── *.yaml                 # Kyverno policies
│   └── tests/                 # policy tests run in CI, not just demo fixtures
├── workflows/                 # reusable GitHub Actions workflows
├── argocd/
│   ├── app-of-apps.yaml       # bootstraps ArgoCD's own children
│   └── applicationsets/       # preview-environment ApplicationSet
├── observability/
│   └── grafana-dashboards/
├── docs/
│   ├── architecture.md
│   └── demo-script.md
├── Makefile                   # make up / make down
└── README.md

tarmac-config/                 # GitOps target — scaffolder PRs land here
└── clusters/
    ├── local/
    └── eks/
```

> **Noted alternative:** `clusters/` could live inside `tarmac` as a directory — ArgoCD watches a path just as happily, saving one repo. Two repos better mirror real platform/tenant separation and cost one `gh repo create`. Going with two.

## 8. Milestone A — Recordable Core (weeks 0-7)

| Wk | Work | Done when |
|---|---|---|
| **0** | AWS Budget $50 + SNS at 50/80/100%. GitHub OIDC provider + scoped CI role (retires the admin static keys). Install `kind`, `argocd`, `kyverno`, `chainsaw`, `yarn`. `kind create cluster` + ArgoCD + app-of-apps. Route53 zone for `preview.kwikflo.in`, NS delegated at Hostinger. | Local cluster reconciling from git; billing alarm armed |
| **1-2** | Backstage app running, catalog wired, `node-express-api` template scaffolds a real repo. Two weeks budgeted — Backstage is a Node monorepo with a real learning curve and upgrade treadmill. | Form submit → repo exists on GitHub |
| **3** | Scaffolder `publish:github:pull-request` action → PR against `tarmac-config`. ArgoCD syncs on merge. | End-to-end form → PR → deployed on kind |
| **4** | Kyverno: the 5 policies from §10, deployed via app-of-apps. CI gate with `kyverno apply`. Violation + pass fixtures. | `:latest` tag rejected with a legible error |
| **5** | ApplicationSet PR generator + ingress-nginx. `*.sslip.io` hostnames locally (free, zero DNS config). **Configure the GitHub webhook** — the default 30-min poll interval will stall the demo on camera. | PR open → live URL in <2 min; PR close → gone |
| **6** | Reusable GHA workflow: test → build → scan → policy check → PR to config repo. Golden-path repo consumes it via `workflow_call`. | Scaffolded repo has green CI on first commit |
| **7** | Slack, buffer, record the local demo. | 90-second GIF exists |

**Checkpoint:** three of four pillars demoable, ~$0.50 spent, and a recordable artifact for recruiters. Crossplane is the deliberate gap.

## 9. Milestone B — Depth and Real Cloud (weeks 8-14)

| Wk | Work |
|---|---|
| **8-9** | Crossplane on kind, `provider-aws`. XRD + Composition for `ServiceInfra` (namespace + RDS + IAM role). Two weeks budgeted; composition authoring is genuinely fiddly. **Set `deletionPolicy` explicitly** — the default deletes the real RDS when a claim disappears. |
| **10** | Claim wired into the Backstage template. Kyverno policy blocking public S3 / oversized instance classes at *claim* admission — guardrails on provisioning, not just deploys. |
| **11** | Supply chain: Trivy scan, cosign signing, Kyverno `verifyImages` rejecting unsigned images. Cheap to add, currently the hottest area, and it completes the policy story. |
| **12** | Terraform platform cluster from CloudSentry's `vpc.tf`/`eks.tf` (public subnets, spot, IRSA, no NAT). S3 + DynamoDB state backend. `make up` / `make down`. **Burst starts.** |
| **13** | Migrate app-of-apps to EKS. external-dns + cert-manager for `*.preview.kwikflo.in` with real TLS. Grafana: provisioning latency, policy violation rate, active preview envs, cost per env. |
| **14** | Record on real infra. `make down`. Verify $0 in Cost Explorer. Docs, diagram, README, MIT license, Show HN. |

## 10. Guardrail Policy Examples (Kyverno)

Deploy-time:
- Block any deployment without CPU/memory requests and limits
- Block `:latest` image tags — require pinned digest or semver
- Block containers running as root (`runAsNonRoot: true` required)
- Require `cost-center` and `team` labels on every resource
- Reject unsigned images (`verifyImages` + cosign) — week 11

Provision-time (on Crossplane claims, week 10):
- Block public S3 bucket creation
- Block instance classes above an approved size

Each policy ships with test cases in `policies/tests/` run in CI. Policies are code; they need tests, not just demo fixtures.

## 11. Interview Demo Script (~90 seconds)

1. Open Tarmac portal, fill form for a new service, hit submit (~10s)
2. Show generated GitHub repo appearing live, with CI already green (~15s)
3. Show the auto-opened PR on `tarmac-config` → merge → Crossplane claim → real AWS resources appearing (~15s)
4. Push a deliberately non-compliant manifest (`:latest` tag) → Kyverno rejection with a clear error in the PR (~15s)
5. Fix it, push again → passes, deploys (~10s)
6. Open a PR → live preview URL appears (~15s)
7. Close the PR → environment auto-destroyed (~10s)

## 12. Resume Bullet

> Built Tarmac, a self-service internal developer platform (Backstage + Crossplane + ArgoCD) with GitOps-based provisioning, policy-as-code guardrails (Kyverno, enforced at both CI and admission), signed-image supply-chain checks, and automated per-PR preview environments — reducing service provisioning from a manual multi-day Terraform process to a single self-service request completed in minutes, on a sub-$50/month infrastructure budget.

## 13. Open Source Launch Plan

- MIT license, clean README with architecture diagram + demo GIF up top
- Submit to Backstage's community plugin/template directory if the template is generic enough to share
- Post to r/devops, r/kubernetes, Hacker News ("Show HN") once the demo is polished
- Add to relevant "Awesome" lists (awesome-backstage, awesome-platform-engineering)
- Companion blog post walking through the Priya example — successful OSS launches lead with a story, not a feature list

## 14. Stretch Goals (post week 14)

- Second golden path (Python/FastAPI) to prove the platform isn't single-stack
- Cost estimation shown to the developer before they submit
- Self-service "tear down my service" flow, not just PR-level teardown
- Slack notifications for provisioning status
- Real multi-tenancy: per-team RBAC on who can claim what

## 15. Known Gaps and Defaults

Deliberate, documented, not accidental:

- **Crossplane AWS credentials on kind (weeks 8-11):** IRSA doesn't exist locally, so a scoped IAM user key lives in a k8s Secret. Least-privilege, and it dies at week 12 when IRSA takes over on EKS. The only static credential in the design.
- **Public subnets, no NAT:** cost-driven. Called out in the README with the production alternative.
- **Single tenant:** one `team` label, no per-team RBAC. Stretch goal, not week 14.
- **Local preview URLs use sslip.io** through week 11; real DNS/TLS only lands at week 13. Alternative: skip the Route53 zone entirely and use sslip.io throughout, saving $0.50/mo and the external-dns/cert-manager work, at the cost of a less polished demo URL.

## 16. Environment Baseline (verified 2026-08-11)

| Item | State |
|---|---|
| AWS account | `360999005486`, `ap-south-1` — clean slate: 0 EKS clusters, 0 NAT gateways, 0 RDS, 0 hosted zones, no budgets |
| AWS auth | IAM user `rajvasoya` with `AdministratorAccess` + static keys — **week 0 replaces this for CI with OIDC** |
| OIDC provider | None registered. CloudSentry's `iam/trust-policy.json` points at old account `081382613682` |
| GitHub | `raxj06`, scopes `repo`, `workflow`, `read:org`, `gist` |
| Domain | `kwikflo.in` at Hostinger (`ns1.dns-parking.com`), A → `2.57.91.91`, **no MX** → subdomain delegation is email-risk-free |
| Installed | `aws` 2.34.29, `terraform` 1.14.8, `docker` 29.5.3, `node` 22.16.0, `npm` 11.7.0, `gh` 2.97.0, `helm`, `kubectl`, `git` |
| Missing | `kind`, `k3d`, `argocd`, `kyverno`, `chainsaw`, `yarn` — week 0 installs |
| Reusable | CloudSentry `infra/vpc.tf` + `eks.tf` (EKS module v20.31.0, spot, IRSA, access entries) → Tarmac `terraform/` at week 12 |
