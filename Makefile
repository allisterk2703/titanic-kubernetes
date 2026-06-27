# Makefile
.PHONY: print-env help create-env activate install-pip install-requirements install-requirements-dev install-all run-training run-api run-mlflow-ui clean isort black ruff install-pre-commit pre-commit build-training-arm64 build-inference-arm64 run-training-arm64 run-inference-arm64 stop-training stop-inference test-inference-local test-inference-docker pipeline-local-training pipeline-local-inference k8s-set-context k8s-create-namespace k8s-get-pods k8s-get-all k8s-run-training k8s-wait-training k8s-logs-training k8s-status-training k8s-delete-training k8s-deploy-inference k8s-status-inference k8s-url-inference k8s-logs-inference k8s-delete-inference k8s-delete-namespace pipeline-k8s-training pipeline-k8s-inference

MAKEFLAGS += --silent

SRC_DIR := src
API_DIR := api
PROJECT_NAME := $(shell basename $(PWD))
IMAGE_NAME := $(PROJECT_NAME)-image
CONTAINER_NAME := $(PROJECT_NAME)-container

TRAINING_IMAGE_NAME := $(IMAGE_NAME)-training-arm64
INFERENCE_IMAGE_NAME := $(IMAGE_NAME)-inference-arm64

K8S_CONTEXT := orbstack
K8S_NAMESPACE := $(PROJECT_NAME)-namespace
K8S_MANIFESTS_DIR := k8s
K8S_EXPORT = IMAGE_NAME=$(IMAGE_NAME) PROJECT_NAME=$(PROJECT_NAME) PROJECT_DIR=$(PWD) K8S_NAMESPACE=$(K8S_NAMESPACE)

BLUE := \033[34m
RESET := \033[0m

# ======================================

help:  ## Show the list of available commands
	echo "→ List of available commands:"
	grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  🔹 %-35s %s\n", $$1, $$2}'

print-env:  ## Print environment variables
	echo "PROJECT_NAME=$(PROJECT_NAME)"
	echo "IMAGE_NAME=$(IMAGE_NAME)"
	echo "CONTAINER_NAME=$(CONTAINER_NAME)"
	echo "K8S_CONTEXT=$(K8S_CONTEXT)"
	echo "K8S_NAMESPACE=$(K8S_NAMESPACE)"


# ======================================
#  Library installation
# ======================================

create-env:  ## Create local virtual environment with uv and install dependencies
	uv sync
	echo "✅ Virtual environment created and dependencies installed (.venv)"

install-pip:  ## Upgrade pip, setuptools and wheel via uv
	@test -d .venv || (echo "❌ .venv not found — run 'make create-env' first" && exit 1)
	uv pip install --upgrade pip setuptools wheel
	echo "✅ pip, setuptools and wheel upgraded"

install-requirements:  ## Install libraries from requirements.txt
	@test -d .venv || (echo "❌ .venv not found — run 'make create-env' first" && exit 1)
	uv pip install -r requirements.txt
	echo "✅ Libraries from requirements.txt installed successfully"

install-requirements-dev: install-pip  ## Install libraries from requirements-dev.txt
	@test -d .venv || (echo "❌ .venv not found — run 'make create-env' first" && exit 1)
	uv pip install -r requirements-dev.txt
	echo "✅ Libraries from requirements-dev.txt installed successfully"

install-all: install-pip install-requirements-dev install-requirements  ## Install all libraries
	echo "✅ All libraries installed successfully"


# ======================================
#  Training & API
# ======================================

run-training:  ## Run the training locally
	echo "⏳ Training locally...\n"
	python train.py

run-api:  ## Run the API locally
	echo "⏳ FastAPI should be running at http://localhost:8080...\n"
	uvicorn $(API_DIR).main:app --host localhost --port 8080

run-mlflow-ui:  ## Run the MLflow UI locally
	echo "⏳ MLflow UI should be running at http://localhost:5001...\n"
	mlflow ui --backend-store-uri "sqlite:///mlflow.db" --host 127.0.0.1 --port 5001


# ======================================
#  Cleaning & Formatting
# ======================================

clean:  ## Remove temporary files
	find . -type d \( -name ".venv" -prune \) -o -type d \( -name "__pycache__" -o -name ".pytest_cache" \) -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	echo "✅ Temporary files removed"

isort:  ## Sort Python imports
	echo "👷 Sorting imports with isort..."
	isort $(SRC_DIR) $(API_DIR) train.py
	echo "✅ Imports sorted with isort"

black:  ## Format Python code with Black
	echo "🎨 Formatting code with Black..."
	black $(SRC_DIR) $(API_DIR) train.py
	echo "✅ Code formatted with Black"

ruff:  ## Check and fix Python code with Ruff
	echo "👷 Checking and fixing code with Ruff..."
	ruff check $(SRC_DIR) $(API_DIR) train.py --fix
	ruff format $(SRC_DIR) $(API_DIR)
	echo "✅ Code checked and fixed with Ruff"

install-pre-commit:  ## Install pre-commit, only if the project is a Git repository
	if [ -d ".git" ]; then \
		echo "📦 Installing pre-commit..."; \
		uv pip install pre-commit && pre-commit install && echo "✅ Pre-commit installed"; \
	else \
		echo "ℹ️  Not a Git repository, skipping pre-commit installation"; \
	fi

pre-commit: isort black # ruff  ## Run all pre-commit checks without Git
	echo "✅ Pre-commit executed"


# ======================================
#  Docker
# ======================================

build-training-arm64:  ## Build the training Docker image for arm64
	docker build --platform linux/arm64 -t $(TRAINING_IMAGE_NAME) -f Dockerfile.training .
	echo "✅ Training Docker image built for arm64: '$(TRAINING_IMAGE_NAME)'"

build-inference-arm64:  ## Build the inference Docker image for arm64
	docker build --platform linux/arm64 -t $(INFERENCE_IMAGE_NAME) -f Dockerfile.inference .
	echo "✅ Inference Docker image built for arm64: '$(INFERENCE_IMAGE_NAME)'"

run-training-arm64: build-training-arm64  ## Build and run the training Docker container locally
	docker run --platform linux/arm64 --rm \
		-e TRAINING_DATA_DIR=/opt/ml/input/data/training \
		-e MODEL_DIR=/opt/ml/model \
		-e OUTPUT_DIR=/opt/ml/output \
		-v $(PWD)/input/data/training:/opt/ml/input/data/training \
		-v $(PWD)/models:/opt/ml/model \
		-v $(PWD)/predictions:/opt/ml/output \
		$(TRAINING_IMAGE_NAME) \
		python /opt/ml/code/train
	echo "✅ Training Docker container executed"

run-inference-arm64: build-inference-arm64  ## Build and run the inference Docker container locally
	echo "⏳ Running inference Docker container..."
	echo "🔗 http://localhost:8080/docs#/"
	docker run --rm -p 8080:8080 --name $(CONTAINER_NAME)-inference-arm64 $(INFERENCE_IMAGE_NAME)

stop-training:  ## Stop the training Docker container
	docker stop $(CONTAINER_NAME)-training-arm64 || true
	echo "✅ Training Docker container stopped"

stop-inference:  ## Stop the inference Docker container
	docker stop $(CONTAINER_NAME)-inference-arm64 || true
	echo "✅ Inference Docker container stopped"

test-inference-local:  ## Test inference server running locally via uvicorn (make run-api)
	curl -sf http://127.0.0.1:8080/openapi.json > /dev/null \
		&& echo "✅ Local inference server is up (http://localhost:8080)" \
		|| (echo "❌ Local inference server is not responding — run 'make run-api' first" && exit 1)

test-inference-docker:  ## Test inference server running in Docker container
	@docker ps --filter "name=$(CONTAINER_NAME)-inference-arm64" --filter "status=running" | grep -q "$(CONTAINER_NAME)-inference-arm64" \
		|| (echo "❌ Container '$(CONTAINER_NAME)-inference-arm64' is not running" && exit 1)
	curl -sf http://127.0.0.1:8080/openapi.json > /dev/null \
		&& echo "✅ Docker inference server is up (http://localhost:8080)" \
		|| (echo "❌ Docker inference server is not responding" && docker logs --tail 20 $(CONTAINER_NAME)-inference-arm64 && exit 1)


# ======================================
#  Local Pipelines
# ======================================

pipeline-local-training: build-training-arm64 run-training-arm64  ## Build arm64 image + run training locally

pipeline-local-inference: build-inference-arm64 run-inference-arm64  ## Build arm64 image + run inference locally


# ======================================
#  Kubernetes (OrbStack)
#
#  Images are read directly from the local Docker daemon (imagePullPolicy: Never).
#  k8s/ YAML files use envsubst for variable injection.
# ======================================

k8s-set-context:  ## Switch kubectl context to OrbStack
	kubectl config use-context $(K8S_CONTEXT)
	echo "✅ kubectl context: $(K8S_CONTEXT)"

k8s-get-pods:  ## List all pods in the namespace
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) get pods

k8s-get-all:  ## List all resources in the namespace (pods, jobs, deployments, services)
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) get all

k8s-create-namespace:  ## Create the Kubernetes namespace (idempotent)
	$(K8S_EXPORT) envsubst '$$K8S_NAMESPACE' < $(K8S_MANIFESTS_DIR)/namespace.yaml | kubectl --context $(K8S_CONTEXT) apply -f -
	echo "✅ Namespace $(K8S_NAMESPACE) ready"

# ======================================
#  Training
# ======================================

k8s-run-training: k8s-create-namespace  ## Run the training Job on Kubernetes (deletes previous job if any)
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) delete job $(PROJECT_NAME)-training-job --ignore-not-found
	$(K8S_EXPORT) envsubst '$$IMAGE_NAME $$PROJECT_NAME $$PROJECT_DIR $$K8S_NAMESPACE' < $(K8S_MANIFESTS_DIR)/training-job.yaml | kubectl --context $(K8S_CONTEXT) apply -f -
	echo "✅ Training job started"

k8s-wait-training:  ## Wait for the training Job to complete
	echo "⏳ Waiting for training job to complete..."
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) wait job/$(PROJECT_NAME)-training-job --for=condition=complete --timeout=3600s
	echo "✅ Training job completed"

k8s-logs-training:  ## Stream logs from the training Job
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) logs job/$(PROJECT_NAME)-training-job --follow

k8s-status-training:  ## Show status of the training Job and its pods
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) get job $(PROJECT_NAME)-training-job
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) get pods -l app=$(PROJECT_NAME)-training

k8s-delete-training:  ## Delete the training Job and its pods
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) delete job $(PROJECT_NAME)-training-job --ignore-not-found
	echo "✅ Training job deleted"

# ======================================
#  Inference
# ======================================

k8s-deploy-inference: k8s-create-namespace  ## Deploy the inference API (Deployment + LoadBalancer Service)
	$(K8S_EXPORT) envsubst '$$IMAGE_NAME $$PROJECT_NAME $$K8S_NAMESPACE' < $(K8S_MANIFESTS_DIR)/inference-deployment.yaml | kubectl --context $(K8S_CONTEXT) apply -f -
	$(K8S_EXPORT) envsubst '$$PROJECT_NAME $$K8S_NAMESPACE' < $(K8S_MANIFESTS_DIR)/inference-service.yaml | kubectl --context $(K8S_CONTEXT) apply -f -
	echo "✅ Inference Deployment and Service applied"
	echo "⏳ Waiting for rollout..."
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) rollout status deployment/$(PROJECT_NAME)-inference

k8s-url-inference:  ## Show the inference service URL (LoadBalancer)
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) get svc $(PROJECT_NAME)-inference-svc

k8s-status-inference:  ## Show status of inference pods and service
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) get deployment $(PROJECT_NAME)-inference
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) get pods -l app=$(PROJECT_NAME)-inference
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) get svc $(PROJECT_NAME)-inference-svc

k8s-logs-inference:  ## Stream logs from the inference pod
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) logs deployment/$(PROJECT_NAME)-inference --follow

k8s-delete-inference:  ## Delete the inference Deployment and Service
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) delete deployment $(PROJECT_NAME)-inference --ignore-not-found
	kubectl --context $(K8S_CONTEXT) -n $(K8S_NAMESPACE) delete svc $(PROJECT_NAME)-inference-svc --ignore-not-found
	echo "✅ Inference Deployment and Service deleted"

k8s-delete-namespace:  ## Delete the namespace and all its resources
	kubectl --context $(K8S_CONTEXT) delete namespace $(K8S_NAMESPACE) --ignore-not-found
	echo "✅ Namespace $(K8S_NAMESPACE) deleted"

# ======================================
#  Kubernetes Pipelines
# ======================================

pipeline-k8s-training: build-training-arm64 k8s-run-training  ## Build arm64 image + run training Job on Kubernetes

pipeline-k8s-inference: build-inference-arm64 k8s-deploy-inference  ## Build arm64 image + deploy inference on Kubernetes
