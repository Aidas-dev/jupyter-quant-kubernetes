# Kubernetes GPU Examples for jupyter-quant-kubernetes

> **⚠️ This project is a Kubernetes-focused fork of the excellent [jupyter-quant](https://github.com/quantbelt/jupyter-quant) project by [@gnzsnz](https://github.com/gnzsnz).**
>
> **All credit for the original design, package selection, and quant research environment goes to the original author.** This fork adapts the image for cloud-native Kubernetes deployments with JupyterHub integration and GPU acceleration support.

This directory contains example Kubernetes configurations for GPU-accelerated JupyterHub deployments.

## Prerequisites

### NVIDIA GPU Cluster

1. **NVIDIA GPU Operator** must be installed:
   ```bash
   helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
   helm install gpu-operator nvidia/gpu-operator --namespace gpu-operator --create-namespace
   ```

2. Verify GPU nodes:
   ```bash
   kubectl get nodes -o json | jq '.items[].status.capacity | select(.["nvidia.com/gpu"])'
   ```

### AMD GPU Cluster

1. **AMD GPU Operator** must be installed:
   ```bash
   helm repo add rocm https://rocm.github.io/gpu-operator
   helm install amd-gpu-operator rocm/gpu-operator-charts --namespace kube-amd-gpu --create-namespace
   ```

2. Verify GPU nodes:
   ```bash
   kubectl get nodes -o json | jq '.items[].status.capacity | select(.["amd.com/gpu"])'
   ```

## Example Configurations

### 1. CPU-Only Deployment

```yaml
# config-cpu.yaml
singleuser:
  image:
    name: gnzsnz/jupyter-quant
    tag: latest
  cpu:
    limit: 4
    guarantee: 2
  memory:
    limit: 8G
    guarantee: 4G
  storage:
    type: dynamic
    capacity: 20Gi
```

### 2. NVIDIA GPU Deployment

```yaml
# config-nvidia.yaml
singleuser:
  image:
    name: gnzsnz/jupyter-quant
    tag: nvidia
  cpu:
    limit: 8
    guarantee: 4
  memory:
    limit: 32G
    guarantee: 16G
  extraResource:
    limits:
      nvidia.com/gpu: 1
  storage:
    type: dynamic
    capacity: 50Gi
```

### 3. AMD GPU Deployment

```yaml
# config-amd.yaml
singleuser:
  image:
    name: gnzsnz/jupyter-quant
    tag: amd
  cpu:
    limit: 8
    guarantee: 4
  memory:
    limit: 32G
    guarantee: 16G
  extraResource:
    limits:
      amd.com/gpu: 1
  nodeSelector:
    amd.com/gpu.product: "mi300"  # Adjust for your GPU type
  storage:
    type: dynamic
    capacity: 50Gi
```

### 4. Multi-Profile (CPU + GPU Options)

```yaml
# config-multi-profile.yaml
singleuser:
  profileList:
    - display_name: "CPU Only"
      description: "Standard environment for backtesting and analysis"
      default: true
      kubespawner_override:
        image: gnzsnz/jupyter-quant:latest
        cpu:
          limit: 4
          guarantee: 2
        memory:
          limit: 8G
          guarantee: 4G

    - display_name: "NVIDIA GPU (A100/V100)"
      description: "GPU-accelerated training with CUDA - NVIDIA GPUs"
      kubespawner_override:
        image: gnzsnz/jupyter-quant:nvidia
        cpu:
          limit: 16
          guarantee: 8
        memory:
          limit: 64G
          guarantee: 32G
        extraResource:
          limits:
            nvidia.com/gpu: 1

    - display_name: "AMD GPU (MI300)"
      description: "GPU-accelerated training with ROCm - AMD GPUs"
      kubespawner_override:
        image: gnzsnz/jupyter-quant:amd
        cpu:
          limit: 16
          guarantee: 8
        memory:
          limit: 64G
          guarantee: 32G
        extraResource:
          limits:
            amd.com/gpu: 1
        nodeSelector:
          amd.com/gpu.product: "mi300"
```

### 5. Multi-GPU Deployment

For large-scale model training requiring multiple GPUs:

```yaml
# config-multi-gpu.yaml
singleuser:
  image:
    name: gnzsnz/jupyter-quant
    tag: nvidia  # or amd
  cpu:
    limit: 32
    guarantee: 16
  memory:
    limit: 128G
    guarantee: 64G
  extraResource:
    limits:
      nvidia.com/gpu: 4  # Request 4 GPUs
  storage:
    type: dynamic
    capacity: 100Gi
  extraPodConfig:
    spec:
      containers:
        - name: notebook
          resources:
            limits:
              nvidia.com/gpu: 4
```

## Deployment Commands

### Install JupyterHub with GPU config

```bash
# CPU only
helm upgrade jupyterhub jupyterhub/jupyterhub \
  --version=3.3.5 \
  --values=config-cpu.yaml \
  --namespace jupyter --create-namespace

# NVIDIA GPU
helm upgrade jupyterhub jupyterhub/jupyterhub \
  --version=3.3.5 \
  --values=config-nvidia.yaml \
  --namespace jupyter --create-namespace

# AMD GPU
helm upgrade jupyterhub jupyterhub/jupyterhub \
  --version=3.3.5 \
  --values=config-amd.yaml \
  --namespace jupyter --create-namespace

# Multi-profile
helm upgrade jupyterhub jupyterhub/jupyterhub \
  --version=3.3.5 \
  --values=config-multi-profile.yaml \
  --namespace jupyter --create-namespace
```

## Verify GPU Access

After users spawn their servers, they can verify GPU access:

```python
# NVIDIA GPU
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU count: {torch.cuda.device_count()}")
    print(f"GPU name: {torch.cuda.get_device_name(0)}")

# XGBoost GPU
import xgboost as xgb
params = {"device": "cuda", "tree_method": "hist"}
print(f"XGBoost device: {params['device']}")
```

```python
# AMD GPU
import torch
print(f"ROCm available: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU count: {torch.cuda.device_count()}")
    print(f"GPU name: {torch.cuda.get_device_name(0)}")
```

## Troubleshooting

### GPU Not Visible

1. **Check GPU operator status:**
   ```bash
   kubectl get pods -n gpu-operator  # NVIDIA
   kubectl get pods -n kube-amd-gpu  # AMD
   ```

2. **Check node labels:**
   ```bash
   kubectl get nodes --show-labels | grep gpu
   ```

3. **Check pod events:**
   ```bash
   kubectl describe pod jupyter-<username> -n jupyter
   ```

### Out of Memory (OOM)

If pods are being killed due to memory pressure:

1. Increase memory limits in config
2. Check GPU memory usage: `kubectl exec -it <pod> -- nvidia-smi` (NVIDIA)
3. Consider implementing memory limits in JupyterHub:
   ```yaml
   singleuser:
     memory:
       limit: 32G
       guarantee: 16G
   ```

### Node Selector Issues (AMD)

If pods are stuck in Pending state:

1. Verify node labels match your config:
   ```bash
   kubectl get nodes -o json | jq '.items[].metadata.labels' | grep amd.com
   ```

2. Adjust `nodeSelector` in your config to match available GPU types

## Cost Optimization

### Idle Culling

Automatically shut down idle GPU servers to save costs:

```yaml
hub:
  config:
    JupyterHub:
      active_server_limit: 100
      inactive_server_limit: 200
    Spawner:
      idle_timeout: 1800  # 30 minutes
```

### GPU Resource Quotas

Prevent users from requesting too many GPUs:

```yaml
singleuser:
  extraResource:
    limits:
      nvidia.com/gpu: 2  # Max 2 GPUs per user
```

## References

- [Zero to JupyterHub](https://z2jh.jupyter.org/en/stable/)
- [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/)
- [AMD GPU Operator](https://rocm.github.io/gpu-operator/)
- [KubeSpawner Documentation](https://jupyterhub-kubespawner.readthedocs.io/)
