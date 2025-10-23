<!-- dacf1593-044b-4d0c-b51e-9504d8e8f48e deb326d8-56cc-404c-ba18-eada2c2879cf -->
# Serverless RAG Chatbot (MVP) — S3 + in‑Lambda FAISS (us-east-1)

## Scope

- No auth (public demo). Single namespace `default` for all uploads.
- Small/medium doc sets (tens of MBs total). Index is loaded in Lambda memory on cold start.
- Minimal web UI: static HTML/JS served locally (or S3 website) using presigned upload, then ingest, then chat.

## Architecture

- Storage: `S3` bucket `rag-docs` (documents, chunk json, index artifacts under prefixes)
- Compute: `Lambda` (Python) with FAISS in a Lambda Layer; 3 functions:
- `get_upload_url`: returns presigned PUT URL to upload files to S3
- `ingest`: lists documents in `s3://rag-docs/default/`, parses, chunks, embeds via OpenAI, builds FAISS, uploads index artifacts to S3
- `query`: loads FAISS index from S3 to /tmp, retrieves top-k chunks for a query, composes prompt, calls OpenAI Chat, returns answer + citations
- API: `API Gateway HTTP API` with routes: `POST /upload-url`, `POST /ingest`, `POST /query`
- Secrets: `AWS Secrets Manager` secret `openai/api_key`; Lambdas read it at init
- IaC: `Terraform` (region `us-east-1`), least-privileged IAM roles/policies

## Data layout (S3)

- `s3://rag-docs/default/uploads/{filename}` — raw user uploads
- `s3://rag-docs/default/chunks/{docId}.jsonl` — chunk metadata (optional)
- `s3://rag-docs/default/index/faiss.index` — FAISS index file
- `s3://rag-docs/default/index/meta.json` — mapping chunk ids → source, text, page

## Endpoints (contracts)

- `POST /upload-url` → `{ filename: string, contentType?: string }` → `{ url, putHeaders, key }`
- `POST /ingest` → `{ namespace?: "default" }` → `{ ok: true, stats }`
- `POST /query` → `{ question: string, k?: number, namespace?: "default" }` → `{ answer, sources: [{source, page?, score}] }`

## Backend Implementation (Python)

- Embeddings: OpenAI `text-embedding-3-small` (cheap, 1536-d)
- Chat model: `gpt-4o-mini` (or `gpt-4o` configurable via env)
- Chunking: `pypdf` for PDFs, plain text for `.txt`; 1–2K token chunks with 10–15% overlap
- Indexing: FAISS `IndexFlatIP` over normalized vectors; persist via `faiss.write_index`
- Retrieval: cosine similarity via inner-product on normalized embeddings; top-k=5 default
- Prompting: system message with brief instructions, user message with question + concatenated context blocks (trim to context window)

## Terraform Layout

- `infra/terraform/main.tf` — providers, region, remote state (optional)
- `infra/terraform/variables.tf` — inputs (e.g., project name, region)
- `infra/terraform/outputs.tf` — API URL, bucket name, secret ARN
- `infra/terraform/s3.tf` — buckets and basic lifecycle
- `infra/terraform/secrets.tf` — Secrets Manager `openai/api_key` (takes value via TF var)
- `infra/terraform/iam.tf` — IAM roles/policies for Lambdas and logs
- `infra/terraform/lambda.tf` — 3 Lambda functions, their env vars, layers, and permissions
- `infra/terraform/apigw.tf` — HTTP API, routes, integrations, stage
- `infra/terraform/layer.tf` — Lambda Layer packaging for Python deps incl. `faiss-cpu`

## Code Layout

- `backend/lambdas/get_upload_url/main.py`
- `backend/lambdas/ingest/main.py`
- `backend/lambdas/query/main.py`
- `backend/shared/s3_utils.py`, `openai_utils.py`, `chunking.py`, `faiss_utils.py`
- `layers/python/requirements.txt` (for layer build: `faiss-cpu`, `pypdf`, `tiktoken`, `requests`, `boto3`, `pydantic`)
- `frontend/index.html`, `frontend/app.js`, `frontend/styles.css` (optional S3 website hosting)

## Minimal Frontend Flow

- `Upload` → call `/upload-url` → PUT file to S3 using returned `url`
- `Build Index` → call `/ingest` (wait for OK)
- `Ask` → call `/query` with question → render answer + citations

## Security/Cost Notes

- No auth initially; later add Cognito and prefix `namespace` per user sub
- Lambda memory 2048–4096 MB recommended; 10–15 min timeout for ingest
- Keep index small to avoid cold-start latency; batch/prune chunks if large

## Local Dev and Deployment

- Fill TF var with OpenAI API key to create Secrets Manager secret
- `terraform init/plan/apply` → outputs HTTP API Base URL and S3 bucket
- Serve `frontend/index.html` locally or upload to S3 static website

## Future Enhancements (not in MVP)

- Cognito auth, per-user namespaces
- Background ingestion via S3 Event → SQS → Ingest Lambda
- Streaming responses via SSE/WebSocket
- Persistent vector DB (OpenSearch Serverless) if index grows

## Module-by-Module Steps

### 1) Terraform bootstrap (providers and project wiring)

- Create `infra/terraform/{main.tf, variables.tf, outputs.tf}`
- Configure AWS provider for `us-east-1`
- Define variables: `project_name`, `region`, `openai_api_key` (sensitive)
- Output placeholders for API URL, bucket name, secret ARN

### 2) Secrets and storage

- In `secrets.tf`, create Secrets Manager secret `openai/api_key`
- Set value from TF var `openai_api_key`
- In `s3.tf`, create bucket `rag-docs-<project_name>`
- Add prefixes: `default/uploads/`, `default/index/`
- Block public access; minimal lifecycle rule for `uploads/` (optional)

### 3) IAM roles and policies

- In `iam.tf`, create an execution role for Lambdas
- Trust policy: `lambda.amazonaws.com`
- Attach inline policy with permissions:
  - `s3:GetObject`, `s3:PutObject`, `s3:ListBucket` on the bucket
  - `secretsmanager:GetSecretValue` on the OpenAI secret
  - `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`

### 4) Lambda Layer (dependencies)

- Create `layers/python/requirements.txt` with: `faiss-cpu`, `pypdf`, `boto3`, `requests`, `tiktoken`, `pydantic`
- In `layer.tf`, define a LayerVersion that zips `layers/python` into `/python` root
- Set compatible runtimes: `python3.11` and arch `x86_64`

### 5) Shared Python utilities

- Create `backend/shared/` modules:
- `s3_utils.py`: S3 client, `get_presigned_put_url`, `download_prefix_to_tmp`, `upload_file`
- `openai_utils.py`: read OpenAI key from Secrets Manager at init; simple `embed_texts`, `chat(messages)` wrappers
- `chunking.py`: parse `.txt` and `.pdf` (using `pypdf`), chunk into ~1000–1500 token segments, 10–15% overlap
- `faiss_utils.py`: build normalized embedding matrix, create `IndexFlatIP`, save/load index, search top-k

### 6) Lambda: get_upload_url

- Path: `backend/lambdas/get_upload_url/main.py`
- Handler accepts `{ filename, contentType }`
- Generates presigned PUT to `s3://bucket/default/uploads/{filename}` with 15 min expiry
- Returns `{ url, putHeaders, key }`

### 7) Lambda: ingest

- Path: `backend/lambdas/ingest/main.py`
- Flow:

1. List `default/uploads/` objects
2. For each new file: download to `/tmp`, parse text, chunk
3. Embed chunks with OpenAI embeddings
4. Build/merge FAISS index (IndexFlatIP, normalized)
5. Save `faiss.index` and `meta.json` to S3 `default/index/`

- Env: `OPENAI_SECRET_ARN`, `BUCKET`, `NAMESPACE=default`
- Timeout: 10–15 min; Memory: 2048–4096 MB

### 8) Lambda: query

- Path: `backend/lambdas/query/main.py`
- Flow:

1. Download `default/index/faiss.index` and `meta.json` to `/tmp`
2. Embed incoming question
3. Search top-k (default 5)
4. Compose prompt: system + user with context blocks truncated to model window
5. Call OpenAI Chat, return `{ answer, sources }`

- Cache index in global scope to reduce cold-start reloads

### 9) API Gateway HTTP API

- In `apigw.tf`, create an HTTP API with routes:
- `POST /upload-url` → get_upload_url
- `POST /ingest` → ingest
- `POST /query` → query
- Configure stage `$default` with auto-deploy; output the base URL

### 10) Wire Lambdas in Terraform

- In `lambda.tf`, define three Lambda functions
- Runtime `python3.11`, architecture `x86_64` (for faiss-cpu)
- Attach the shared Layer and IAM role
- Set env vars: `BUCKET`, `NAMESPACE`, `OPENAI_SECRET_ARN`, `EMBED_MODEL`, `CHAT_MODEL`
- Create permissions for API Gateway to invoke each Lambda

### 11) Minimal frontend (static)

- Files: `frontend/index.html`, `frontend/app.js`, `frontend/styles.css`
- Implement three actions:
- Upload: call `/upload-url`, then `PUT` file to returned URL
- Ingest: call `/ingest` and show progress
- Ask: call `/query` and display answer + citations
- Optionally host on S3 static website; otherwise open via local file server

### 12) Local dev and deploy

- Export AWS creds for `us-east-1`
- `terraform init && terraform apply -auto-approve` (passing `-var openai_api_key=...`)
- Note outputs: API base URL, bucket name
- Open `frontend/index.html` and test end-to-end

### 13) Testing and limits

- Start with small `.txt` docs (<5 MB total) to validate flow
- Verify ingest duration, memory usage; reduce chunk size if OOM
- If index becomes large, consider splitting namespaces or moving to OpenSearch Serverless

### To-dos

- [ ] Write minimal Terraform for S3, IAM, Lambdas, API Gateway, SSM
- [ ] Create OpenAI Vector Store and set env var
- [ ] Implement OpenAI client and chunking utility
- [ ] Build ingest Lambda for .txt files and vector-store upload
- [ ] Build chat Lambda that queries vector store with gpt-4o
- [ ] Add upload-url endpoint for S3 pre-signed PUT
- [ ] Create minimal React UI for upload and chat
- [ ] Run end-to-end test with a sample .txt
- [ ] Add PDF parsing and re-run e2e tests