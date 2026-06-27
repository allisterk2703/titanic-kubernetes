<p align="center">
  <img src=".github/titanic-ship.png" alt="Titanic" width="400">
</p>

# titanic-kubernetes

Prediction of Titanic survival: training a classification model locally or on Kubernetes via OrbStack, experiment tracking with MLflow, and serving predictions through a FastAPI inference API.

## Features

- Load and preprocess Titanic data; train a classifier (sklearn pipeline).
- Run training locally or as a Kubernetes Job on OrbStack.
- Deploy inference as a Kubernetes Deployment with a LoadBalancer Service, or run the API locally with uvicorn.
- Track runs and artifacts with MLflow.

## Project structure

- `src/` — data loading, preprocessing, training, evaluation, prediction.
- `api/` — FastAPI app for inference.
- `input/` — sample data and example JSON input.
- `output/` — trained model artifacts and metrics.
- `k8s/` — Kubernetes manifests (namespace, training Job, inference Deployment and Service).
- `Dockerfile.training`, `Dockerfile.inference` — Docker images for training and inference.

## Usage

### Local

```bash
make run-training       # train locally
make run-api            # start the FastAPI server at http://localhost:8080
make run-mlflow-ui      # start the MLflow UI at http://localhost:5001
```

### Docker (arm64)

```bash
make run-training-arm64   # build + run training container
make run-inference-arm64  # build + run inference container at http://localhost:8080
```

### Kubernetes (OrbStack)

```bash
make pipeline-k8s-training   # build arm64 image + run training Job
make k8s-logs-training       # stream training logs
make k8s-get-pods            # check pod status

make pipeline-k8s-inference  # build arm64 image + deploy inference API
make k8s-url-inference       # get the LoadBalancer IP and port
```

Invoke the inference API:

```bash
curl -X POST http://<EXTERNAL-IP>:8080/predict \
  -H "Content-Type: application/json" \
  -d @input/example_input.json
```

## Author

Allister K.

## License

MIT License — see [LICENSE](LICENSE) for details.
