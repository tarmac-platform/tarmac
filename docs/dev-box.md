# Backstage Dev Box (EC2)

The Backstage instance runs on EC2 (it needs a Unix-like OS + GNU toolchain;
Windows has neither). It never talks to the kind cluster: Backstage -> GitHub
API -> ArgoCD pulls -> kind. So no VPN/tunnel to the laptop is needed.

## 1. Apply (budget + EC2 together)

From `bootstrap/terraform`:

```powershell
terraform apply
```

Review the plan — it creates:

- `aws_budgets_budget.tarmac` ($50/mo alerts to rajvasoya06@gmail.com)
- `aws_security_group.backstage_dev` (SSH only from 152.59.54.112/32)
- `aws_instance.backstage_dev` (t3.large, Ubuntu 24.04, 30GB gp3 encrypted,
  user_data scripts Node 22/Docker/swap)

Type `yes`. Note: the old `budget.tfplan` is stale — ignore it, run a fresh
`apply`.

## 2. Get the box's info

```powershell
terraform output -raw dev_public_ip
terraform output dev_ssh
```

Public IP changes each start (no EIP on purpose — saves money while stopped).

## 3. First SSH + verify cloud-init finished

```powershell
ssh -i "$HOME\Downloads\devops-raj362.pem" ubuntu@<IP>
sudo tail -f /var/log/cloud-init-output.log
```

Wait until you see the `.cloud-init-done` marker / prompt returns. Verify:
`node -v` -> v22.x, `corepack --version`, `yarn --version` -> 4.4.1,
`docker ps` works.

## 4. Create Backstage (on the box)

```bash
cd /opt/tarmac
sudo -u ubuntu npx @backstage/create-app@latest
```

(2-4 min; the box has the CPU/RAM for it.)

## 5. Tunnel to your browser (on your PC)

```powershell
ssh -i "$HOME\Downloads\devops-raj362.pem" -N -L 3000:localhost:3000 -L 7007:localhost:7007 ubuntu@<IP>
```

Then `http://localhost:3000` (Backstage UI) in your browser.

## 6. Stop the box when done (keep EBS, stop billing)

```powershell
aws ec2 stop-instances --instance-ids <instance-id>
```
