# Tarmac platform Makefile
# Works on any POSIX make (Git Bash / WSL / CI). On Windows PowerShell,
# run the underlying commands directly (see each target comment).

SHELL := /bin/bash
KIND_CLUSTER := tarmac
KIND_CONFIG := bootstrap/kind/cluster.yaml
TARMAC_CONFIG_DIR := ../tarmac-config
ROOT_APP := $(TARMAC_CONFIG_DIR)/clusters/local/root-app.yaml

.PHONY: up down recreate bootstrap verify tf-apply tf-destroy dev-up dev-down dev-ip dev-ssh demo policy-test

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

## EC2 dev box (Backstage). STOP not destroy to keep the EBS state.
dev-up:
	cd bootstrap/terraform && terraform apply

dev-down:
	aws ec2 stop-instances --instance-ids $$(cd bootstrap/terraform && terraform output -raw dev_instance_id)

dev-ip:
	cd bootstrap/terraform && terraform output -raw dev_public_ip

dev-ssh:
	ssh -i $$HOME/Downloads/devops-raj362.pem ubuntu@$$(cd bootstrap/terraform && terraform output -raw dev_public_ip)

## Run the Kyverno policy test suite (CI gate). Pass fixtures must pass,
## fail fixtures must fail. Exit nonzero on any mismatch.
policy-test:
	@./scripts/policy-test.sh

demo:
	@echo "See docs/demo-script.md (added week 7)."
