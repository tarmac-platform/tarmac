# Tarmac platform Makefile
# Works on any POSIX make (Git Bash / WSL / CI). On Windows PowerShell,
# run the underlying commands directly (see each target comment).

SHELL := /bin/bash
KIND_CLUSTER := tarmac
KIND_CONFIG := bootstrap/kind/cluster.yaml
TARMAC_CONFIG_DIR := ../tarmac-config
ROOT_APP := $(TARMAC_CONFIG_DIR)/clusters/local/root-app.yaml

.PHONY: up down recreate bootstrap verify tf-apply tf-destroy demo

## Create the kind cluster (free, local)
up:
	kind create cluster --name $(KIND_CLUSTER) --config $(KIND_CONFIG)

## Delete the kind cluster
down:
	kind delete cluster --name $(KIND_CLUSTER)

## Full teardown (weeks 12-14 real-cloud equivalent is terraform destroy + make down)
recreate: down up

## Helm-install ArgoCD + register tarmac-config repo + apply the root Application.
## The ONLY imperative kubectl apply in the project. Everything after this is git.
bootstrap:
	helm repo add argo https://argoproj.github.io/argo-helm --force-update
	helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace -f bootstrap/argocd/values.yaml
	kubectl apply -f $(ROOT_APP)

## GitOps smoke test: expect a ConfigMap to be reconciled from tarmac-config, no manual apply
verify:
	kubectl get cm -n argocd tarmac-config-smoke-test

## Provision the $50 AWS budget (run from bootstrap/terraform; requires tfvars)
tf-apply:
	cd bootstrap/terraform && terraform init && terraform apply

tf-destroy:
	cd bootstrap/terraform && terraform destroy

demo:
	@echo "See docs/demo-script.md (added week 7)."
