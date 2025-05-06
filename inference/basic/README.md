# Basic Inference Reference Architecture

This repository provides a Helm chart to deploy a basic inference setup on CoreWeave's infrastructure. Follow the steps below to set up the required dependencies in your cluster and install this chart.

## Prerequisites

Before installing this chart, ensure you have the following:
- A Kubernetes cluster on CoreWeave.
- `kubectl` and `helm` installed and configured to interact with your cluster.

## Setup

### 0. Add CoreWeave's Helm Repository
Add CoreWeave's Helm repository to your local Helm client:

```bash
helm repo add coreweave https://charts.core-services.ingress.coreweave.com
helm repo update
```

### 1. Ingress with Traefik

Usage of an ingress controller is recommended with this chart. The rest of this example will use CoreWeave's Traefik chart. Find more details about it [here](https://docs.coreweave.com/docs/products/cks/how-to/coreweave-charts/traefik).

If you don't require TLS you can install the chart without any custom values with the following command. If you do, skip to section 1.a

```bash
helm install traefik coreweave/traefik --namespace traefik --create-namespace
```

#### 1.a TLS Support with cert-manager

Cert-Manager is a simple way to manage TLS certificates. Like Traefik, CoreWeave publishes an easy to use chart. You can find the docs on it [here](https://docs.coreweave.com/docs/products/cks/how-to/coreweave-charts/cert-manager).

You can customize the cert-issuers that traefik will use if you wish, but otherwise you can use the defaults and install with the following command:

```bash
helm install cert-manager coreweave/cert-manager --set cert-issuers.enabled=true --namespace cert-manager --create-namespace
```

Once cert-manager is installed, you can install traefik with values configured to use the cert issuers.

To install it, first create the `values-traefik.yaml` file:

```yaml
tls:
  enabled: true
  clusterIssuer: letsencrypt-prod
  labels:
     cert-manager.io/cluster-issuer: letsencrypt-prod
  annotations:
     cert-manager.io/cluster-issuer: letsencrypt-prod
```

Then install it using the following commands:

```bash
helm install traefik coreweave/traefik --namespace traefik --create-namespace -f values-traefik.yaml
```

### 2. Huggingface tokens

Some models on huggingface require you do be authed into an account that has been granted access. You can easily do this by using a huggingface token.

The chart allows you to specify the secret token in plain text but it is recommended that you create a huggingface token secret separately and reference it outside of this chart. This also allows you to use the same token for all vLLM deployments.

Once you fetch a token from HuggingFace [here](https://huggingface.co/settings/tokens), create a kubernetes secret with the following command:

```bash
export HF_TOKEN="<huggingface-token>"
kubectl create secret generic hf-token -n inference --from-literal=token="$HF_TOKEN"
```

Now you can use the following in the values for the basic inference chart:

```yaml
hfToken:
  secretName: "hf-token"
```

### 3. Model Cache PVC

Similar to the HuggingFace token, the chart has functionality to create a PVC for you but it is recommended you create one outside the scope of the helm chart so it can persist across deployments and be reused.

To create one manually, apply the following yaml:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: huggingface-model-cache
  namespace: inference
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Ti
  storageClassName: shared-vast
```

```bash
kubectl apply -f huggingface-model-cache.yaml
```

Once applied, you can configure the model cache section of the chart values like this:

```yaml
modelCache:
  enabled: true
  create: false
  name: huggingface-model-cache
```

### 4. Verify Dependencies

Ensure that all of the dependencies exist with the following commands

```bash
kubectl get pods -n traefik
kubectl get pods -n cert-manager
kubectl get pvc -n inference
kubectl get secret -n inference
```

## Installing the Basic Inference Chart

Once the prerequisites are set up, you can install this chart. Take a look at the `values.yaml` file to see all that you can adjust. 

### Full examples

There are example values files in the `hack/` folder that you can use.

These examples expect that everything in the prereq steps are already installed.

For example, to run `meta-llama/Llama-3.1-8B-Instruct` you can use `hack/values-llama-small.yaml`:

```bash
helm install basic-inference ./ --namespace inference --create-namespace -f hack/values-llama-small.yaml
```

## Using the Service

Once the helm chart is deployed, you can query the endpoint using the standard OpenAI API spec.

If you followed the installation steps above and created a Traefik ingress, you can retrieve the endpoint via kubectl by looking at the `ingress`. In the following example, the endpoint to query would be `navs-vllm.cw2025-training.coreweave.app`.

If you installed and used cert-manager as the instructions recommend, you can use `https`.

```bash
❯ kubectl get ingress                                                                                                                                                         
NAME       CLASS     HOSTS                                     ADDRESS         PORTS     AGE
deepseek   traefik   `navs-vllm.cw2025-training.coreweave.app`   166.19.16.127   80, 443   7d14h
❯ export VLLM_ENDPOINT="https://navs-vllm.cw2025-training.coreweave.app"
```

### cURL

Assuming the ingress endpoint is stored in an environment variable named `VLLM_ENDPOINT`, you can use the following queries.

First, check that the service is healthy. If this returns a `200` the service is healthy

```bash
❯ curl -s -o /dev/null -w "%{http_code}" $VLLM_ENDPOINT/health
200
```

Then you can get the current active models:

```bash
❯ curl -s $VLLM_ENDPOINT/v1/models | jq '.data[].id'
"deepseek-ai/DeepSeek-R1"
❯ export VLLM_MODEL="deepseek-ai/DeepSeek-R1"
```

Finally you can run inference against the model:

```bash
❯ curl -X POST "$VLLM_ENDPOINT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
        "model": "'"$VLLM_MODEL"'",
        "messages": [
          { "role": "system", "content": "You are a helpful assistant and an expert in modern AI infrastructure." },
          { "role": "user",   "content": "Explain why HGX H200 nodes suit large-MoE models." }
        ]
      }'
```

### OpenAI Client Library

Most application use the OpenAI libraries across various languages to run inference. Since vLLM is running with the OpenAI API spec you can use it here.

All you need to do is adjust the base URL used with the library.

#### Python Example

First instantiate the OpenAI client. Make sure you adjust the model and base URL. You can find the values by following the steps in the cURL section. 

```python
MODEL = "deepseek-ai/DeepSeek-R1"
client = OpenAI(
    base_url="https://navs-vllm.cw2025-training.coreweave.app/v1",
    api_key="unused",
)
```

Then you can use the client as you would normally.

Chat completion example:

```python
chat = client.chat.completions.create(
    model=MODEL,
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user",   "content": "Explain why HGX H200 nodes suit large-MoE models."},
    ],
    temperature=0.5
)
print(chat.choices[0].message.content)
```

Streaming example:

```python
stream = client.chat.completions.create(
    model=MODEL,
    messages=[{"role": "user", "content": "What would a GPU cloud provider have to do to receive the highest ranking in the SemiAnalysis ClusterMAX award?"}],
    stream=True,                # yields chunks as they arrive
)
for chunk in stream:
    if chunk.choices and chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
```

## Cleanup

To uninstall the chart and its dependencies, run:

```bash
helm uninstall basic-inference --namespace inference
helm uninstall cert-manager --namespace cert-manager
helm uninstall traefik --namespace traefik
```

If you manually installed your huggingface token and model cache, clean those up as well:

```bash
kubectl delete -f huggingface-model-cache.yaml
kubectl delete secret hf-token
```

# ToDo

- [ ] Autoscaling
- [ ] vLLM Metrics
- [ ] Routing to different models
- [ ] Object storage
- [ ] Tensorizer
- [ ] Multi-node
- [ ] Auth
