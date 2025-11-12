cat > README.md <<'MD'
# Bus Alerts — Serverless ETLA (Deliverables 1–4 + Docs)


[![CI Smoke Test](https://github.com/aamerkhanus/bus-alert-pipeline/actions/workflows/ci-smoke-test.yml/badge.svg)](https://github.com/aamerkhanus/bus-alert-pipeline/actions/workflows/ci-smoke-test.yml)
[![Deploy Prod](https://github.com/aamerkhanus/bus-alert-pipeline/actions/workflows/deploy-prod.yml/badge.svg)](https://github.com/aamerkhanus/bus-alert-pipeline/actions/workflows/deploy-prod.yml)

A serverless pipeline that ingests school bus breakdown/delay events via a protected HTTP API, validates/enriches them in Lambda, stores raw payloads in S3, writes transformed records to DynamoDB, and emits a custom CloudWatch metric for high-priority incidents. Alarms notify via SNS.

---

## Architecture Diagram / Flow

**Text diagram:**
- Client authenticates with **Cognito** and calls **API Gateway** `POST /bus-event`
- **API Gateway** (Cognito **JWT Authorizer** enforced) invokes **Lambda (ingest)**
- **Lambda**:
  - Validates required fields (Busbreakdown_ID, Route_Number, Reason, Occurred_On)
  - Derives `alert_priority` (high/medium/low)
  - Parses `How_Long_Delayed` → `average_delay_minutes`
  - Writes **raw** payload to **S3**
  - Writes **transformed** record to **DynamoDB** (PK: Route_Number, SK: Occurred_On)
  - Emits **HighPriorityAlerts** custom metric when applicable
- **CloudWatch Alarms** watch HighPriorityAlerts (custom) and Lambda Errors (managed)
- **SNS** sends alert notifications (e.g., email)

**Why serverless?** Pay-per-use, automatic scaling, minimal ops, built-in metrics/logging.

---

## Live Outputs (from Terraform)

- **API URL**: `https://asyvv68pzj.execute-api.us-east-1.amazonaws.com/prod/bus-event`
- **Cognito User Pool ID**: `us-east-1_29BnJY5Us`
- **Cognito App Client ID**: `7qdpt4q4d6hmkl3ufuhsvhjbae`
- **Lambda**: `bus-alerts-ingest`
- **DynamoDB table**: `bus-alerts` (PK: `Route_Number`, SK: `Occurred_On`)
- **Raw S3 bucket**: `bus-alerts-raw-amar-ny-12345`
- **Metric namespace**: `BusAlerts`

---

## Setup Instructions

### Prerequisites
- **Terraform** >= 1.5
- **AWS CLI** configured to your account/role (`aws configure`)
- **Python 3.x** (for local tooling/tests)

### Deploy
```bash
cd infra
terraform init
terraform apply -auto-approve
terraform output

//Note the printed api_url, cognito_pool_id, cognito_client_id.

//Create a Cognito test user (one-time)

REGION="us-east-1"
POOL_ID="us-east-1_29BnJY5Us"
USER_EMAIL="you@example.com"

aws cognito-idp admin-create-user \
  --region "$REGION" --user-pool-id "$POOL_ID" --username "$USER_EMAIL" \
  --user-attributes Name=email,Value="$USER_EMAIL" Name=email_verified,Value=true \
  --message-action SUPPRESS

aws cognito-idp admin-set-user-password \
  --region "$REGION" --user-pool-id "$POOL_ID" --username "$USER_EMAIL" \
  --password 'P@ssw0rd123!' --permanent

//Get a JWT and call the API

CLIENT_ID="7qdpt4q4d6hmkl3ufuhsvhjbae"
API_URL="https://asyvv68pzj.execute-api.us-east-1.amazonaws.com/prod/bus-event"

JWT=$(aws cognito-idp initiate-auth \
  --region us-east-1 \
  --client-id "$CLIENT_ID" \
  --auth-flow USER_PASSWORD_AUTH \
  --auth-parameters USERNAME="$USER_EMAIL",PASSWORD='P@ssw0rd123!' \
  --query 'AuthenticationResult.IdToken' --output text)

# Unauthorized (no token) → 401
curl -s -o /dev/null -w "%{http_code}\n" -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d '{"x":1}'

# Authorized (with token) → 200
curl -s -X POST "$API_URL" \
  -H "Authorization: Bearer $JWT" \
  -H "Content-Type: application/json" \
  -d '{
        "Busbreakdown_ID": 990001,
        "Route_Number": "Q12",
        "Reason": "Mechanical Problem",
        "Occurred_On": "2025-11-09T17:05:00Z",
        "How_Long_Delayed": "25-35 Mins"
      }'


//Design Decisions

DynamoDB

Access pattern: fast lookups by route and time range → (PK: Route_Number, SK: Occurred_On) is ideal.

Scales automatically, pay-per-request, no servers to manage.

S3

Immutable audit log for the exact JSON received; ideal for compliance and replays.

Lambda

Event-driven, no idle cost; integrates natively with API Gateway, DynamoDB, CloudWatch.

Custom Metric HighPriorityAlerts

Lets ops see surge conditions (spikes in severe incidents) and alarm appropriately.

Cognito + API Gateway Authorizer

Only authenticated clients can submit; prevents spam/abuse of public endpoint.

Assumptions

Reason → priority mapping covers known values; default = low.

Delay strings are parseable to minutes (handles “30 Min”, “25-35 Mins”, “1-2 Hours”, etc.).

Occurred_On is ISO-8601 UTC (...Z).

CI/CD Plan (GitHub Actions)

Stage 1: Lint & Test

Run flake8/ruff + (optional) pytest for Lambda.

terraform fmt -check and terraform validate.

Stage 2: Plan

On PRs, run terraform plan against a dev workspace and post the plan as a PR comment.

Stage 3: Deploy to Dev

On merge to main, run terraform apply to dev.

Package Lambda (or use archive_file) and update the function code.

Stage 4: Promote to Prod

Manual approval step.

terraform apply to prod workspace/account.

Secrets & Credentials

Prefer AWS OIDC (GitHub → IAM role) for short-lived creds.

Alternative: repository secrets for Access Key/Secret (less secure).

Rollback

Revert to a previous Terraform state (or git commit) and apply.

Lambda versions/aliases support quick function code rollbacks.

Operations (Alarms & Notifications)

Lambda Errors alarm: triggers on any error (> 0 in 5 minutes).

HighPriorityAlerts burst alarm: triggers when sum ≥ 3 in 5 minutes.

SNS topic delivers notifications (email/SMS). Confirm subscription after deploy.

Security Hardening (Optional Enhancements)

S3 bucket encryption (SSE-S3 or SSE-KMS) + block public access.

DynamoDB table encryption (default is enabled).

CloudWatch Logs retention (e.g., 14–30 days).

Least-privilege IAM role for Lambda (narrow S3/DDB actions to exact ARNs).

WAF or throttling/rate-limits on API Gateway (if exposed to the public internet).

//Teardown (to avoid charges during pauses)

cd infra
terraform destroy -auto-approve

//Re-apply later to recreate everything; your source code remains in the repo.

//MD


That’s it — your README is created and complete.

---

## Step 3 — (Optional) View it in VS Code
- Click **README.md** in the Explorer panel.
- Press **Preview** (Open Preview button) if you want the rendered view.

## Step 4 — Commit it
```bash
git add README.md
git commit -m "Add Deliverable #5 README with architecture, setup, design, CI/CD"
git push
