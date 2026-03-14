# Jupyter Quant Kubernetes

> **⚠️ This project is a Kubernetes-focused fork of the excellent [jupyter-quant](https://github.com/quantbelt/jupyter-quant) project by [@gnzsnz](https://github.com/gnzsnz).**
>
> **All credit for the original design, package selection, and quant research environment goes to the original author.** This fork adapts the image for cloud-native Kubernetes deployments with JupyterHub integration and GPU acceleration support.

A cloud-native Jupyter quant research environment for Kubernetes and JupyterHub.

## Highlights

- Cloud-native design for Kubernetes and JupyterHub deployments
- **GPU-accelerated variants available** (NVIDIA CUDA 12.x and AMD ROCm 6.x)
- Includes tools for quant analysis: statsmodels, pymc, arch, py_vollib,
  zipline-reloaded, PyPortfolioOpt, etc.
- The usual suspects are included: numpy, pandas, scipy, scikit-learn,
  yellowbrick, shap, optuna.
- [ib_async](https://github.com/ib-api-reloaded/ib_async) for Interactive Broker
  connectivity.
- Includes all major Python packages for statistical and time series analysis,
  see [requirements](https://github.com/quantbelt/jupyter-quant/blob/master/requirements.txt).
  For an extensive list check
  [list installed packages](#list-installed-packages) section.
- [Zipline-reloaded](https://github.com/stefan-jansen/zipline-reloaded/),
  [pyfolio-reloaded](https://github.com/stefan-jansen/pyfolio-reloaded)
  and [alphalens-reloaded](https://github.com/stefan-jansen/alphalens-reloaded).
- You can install it as a python package: `pip install -U jupyter-quant`
- Designed for ephemeral containers with persistent volumes for data.
- Optimized for size: 2GB image vs 4GB for jupyter/scipy-notebook.
- Includes jedi language server, jupyterlab-lsp, black and isort.
- All packages installed with pip under `~/.local/lib/python`.
- Includes Cython, Numba, bottleneck and numexpr for performance.
- sudo access for installing additional packages if needed.
- bash and stow for [BYODF](#install-your-dotfiles) (bring your dotfiles).
- Common command line utilities: git, less, nano, jq, ssh, curl, bash completion.
- Support for [apt cache](https://github.com/gnzsnz/apt-cacher-ng).
- No built environment - build wheels outside the container and import.

## Image Variants

| Variant | Base Image | GPU Support | Use Case |
|---------|------------|-------------|----------|
| `Aidas-dev/jupyter-quant-kubernetes:latest` | python:3.13-slim | CPU only | General quant research, backtesting |
| `Aidas-dev/jupyter-quant-kubernetes:nvidia` | nvidia/cuda:12.4.1 | NVIDIA GPU (CUDA 12.x) | GPU-accelerated ML training, XGBoost, PyTorch |
| `Aidas-dev/jupyter-quant-kubernetes:amd` | rocm/pytorch | AMD GPU (ROCm 6.x) | GPU-accelerated ML on AMD hardware |

### GPU-Accelerated Packages

**NVIDIA variant includes:**
- PyTorch with CUDA 12.4 support
- XGBoost with GPU acceleration (`xgboost-cu12`)
- Optional: RAPIDS cuDF for GPU DataFrame operations

**AMD variant includes:**
- PyTorch with ROCm 6.2 support
- XGBoost with ROCm support
- Optional: Polars GPU for DataFrame operations

## Quick Start

### Kubernetes + JupyterHub

This image is designed for cloud-native deployments using JupyterHub on Kubernetes.

1. **Install JupyterHub** using [Zero to JupyterHub](https://z2jh.jupyter.org/en/stable/)

2. **Add to your JupyterHub config** (`config.yaml`):

```yaml
singleuser:
  image:
    name: Aidas-dev/jupyter-quant-kubernetes
    tag: latest  # or specific version like 2512.2
  cpu:
    limit: 4
    guarantee: 1
  memory:
    limit: 8G
    guarantee: 4G
  storage:
    type: dynamic
    capacity: 10Gi
```

3. **Deploy JupyterHub**:
```bash
helm upgrade jupyterhub jupyterhub/jupyterhub \
  --version=3.3.5 \
  --values=config.yaml \
  --namespace jupyter --create-namespace
```

### Kubernetes + GPU Support

#### NVIDIA GPU Configuration

Requires: [NVIDIA GPU Operator](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/) installed on your cluster.

```yaml
singleuser:
  image:
    name: Aidas-dev/jupyter-quant-kubernetes
    tag: nvidia  # GPU-enabled variant
  cpu:
    limit: 8
    guarantee: 2
  memory:
    limit: 32G
    guarantee: 8G
  extraResource:
    limits:
      nvidia.com/gpu: 1  # Request 1 GPU
  storage:
    type: dynamic
    capacity: 50Gi
```

#### AMD GPU Configuration

Requires: [AMD GPU Operator](https://rocm.github.io/gpu-operator/) installed on your cluster.

```yaml
singleuser:
  image:
    name: Aidas-dev/jupyter-quant-kubernetes
    tag: amd  # GPU-enabled variant
  cpu:
    limit: 8
    guarantee: 2
  memory:
    limit: 32G
    guarantee: 8G
  extraResource:
    limits:
      amd.com/gpu: 1  # Request 1 GPU
  nodeSelector:
    amd.com/gpu.product: "mi300"  # Adjust based on your GPU type
  storage:
    type: dynamic
    capacity: 50Gi
```

#### Multi-Profile Setup (CPU + GPU Options)

Allow users to choose between CPU and GPU environments:

```yaml
singleuser:
  profileList:
    - display_name: "CPU Environment"
      description: "Standard quant research environment (CPU only)"
      default: true
      kubespawner_override:
        image: Aidas-dev/jupyter-quant-kubernetes:latest
        cpu:
          limit: 4
          guarantee: 1
        memory:
          limit: 8G
          guarantee: 4G
    - display_name: "NVIDIA GPU Environment"
      description: "GPU-accelerated ML training with CUDA (NVIDIA)"
      kubespawner_override:
        image: Aidas-dev/jupyter-quant-kubernetes:nvidia
        cpu:
          limit: 8
          guarantee: 2
        memory:
          limit: 32G
          guarantee: 8G
        extraResource:
          limits:
            nvidia.com/gpu: 1
    - display_name: "AMD GPU Environment"
      description: "GPU-accelerated ML training with ROCm (AMD)"
      kubespawner_override:
        image: Aidas-dev/jupyter-quant-kubernetes:amd
        cpu:
          limit: 8
          guarantee: 2
        memory:
          limit: 32G
          guarantee: 8G
        extraResource:
          limits:
            amd.com/gpu: 1
        nodeSelector:
          amd.com/gpu.product: "mi300"
```

### Docker (Standalone Testing)

For local testing without JupyterHub:

```bash
docker run -it --rm \
  -p 8888:8888 \
  -v $(pwd)/Notebooks:/home/gordon/Notebooks \
  -v quant_data:/home/gordon/.local \
  -v quant_conf:/home/gordon/.config \
  Aidas-dev/jupyter-quant-kubernetes:latest \
  jupyter-lab --no-browser --ip=0.0.0.0
```

### Docker with GPU Support

#### NVIDIA GPU (requires NVIDIA Container Toolkit)

```bash
docker run -it --rm \
  --gpus all \
  -p 8888:8888 \
  -v $(pwd)/Notebooks:/home/gordon/Notebooks \
  -v quant_data:/home/gordon/.local \
  -v quant_conf:/home/gordon/.config \
  Aidas-dev/jupyter-quant-kubernetes:nvidia \
  jupyter-lab --no-browser --ip=0.0.0.0
```

Verify GPU access inside the container:
```python
import torch
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0)}")

import xgboost as xgb
print(f"XGBoost GPU enabled: {xgb.config()['device']}")
```

#### AMD GPU (requires ROCm drivers)

```bash
docker run -it --rm \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add video \
  --ipc=host \
  --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined \
  -p 8888:8888 \
  -v $(pwd)/Notebooks:/home/gordon/Notebooks \
  -v quant_data:/home/gordon/.local \
  -v quant_conf:/home/gordon/.config \
  Aidas-dev/jupyter-quant-kubernetes:amd \
  jupyter-lab --no-browser --ip=0.0.0.0
```

Verify GPU access inside the container:
```python
import torch
print(f"ROCm available: {torch.cuda.is_available()}")
print(f"GPU: {torch.cuda.get_device_name(0)}")

import xgboost as xgb
print(f"XGBoost GPU enabled: {xgb.config()['device']}")
```

### PyPI Package

To use `jupyter-quant` as a [pypi package](https://pypi.org/project/jupyter-quant/)
see [install quant package](#install-jupyter-quant-package).

### Docker Compose (Legacy)

For standalone Docker usage (not recommended for production):

```yml
services:
  jupyter-quant:
    image: Aidas-dev/jupyter-quant-kubernetes:${IMAGE_VERSION}
    environment:
      APT_PROXY: ${APT_PROXY:-}
      BYODF: ${BYODF:-}
      SSH_KEYDIR: ${SSH_KEYDIR:-}
      START_SCRIPTS: ${START_SCRIPTS:-}
      TZ: ${QUANT_TZ:-}
    restart: unless-stopped
    ports:
      - ${LISTEN_PORT}:8888
    volumes:
      - quant_conf:/home/gordon/.config
      - quant_data:/home/gordon/.local
      - ${PWD}/Notebooks:/home/gordon/Notebooks

volumes:
  quant_conf:
  quant_data:
```

```bash
cp .env-dist .env
docker compose config
docker compose up
```

## Volumes

### Kubernetes (JupyterHub)

When using JupyterHub on Kubernetes, storage is managed by the Helm chart:

```yaml
singleuser:
  storage:
    type: dynamic
    capacity: 10Gi
    dynamic:
      storageClass: standard  # or your preferred storage class
```

Each user gets their own Persistent Volume Claim (PVC) automatically provisioned.

### Docker (Standalone)

The image uses 3 volumes:

1. `quant_data` - `~/.local` folder with Python packages and caches
2. `quant_conf` - `~/.config` for Jupyter, IPython, Matplotlib config
3. Bind mount - `~/Notebooks` for notebook files

This enables ephemeral containers while preserving notebooks, config, and installed packages.

## Common tasks

### Kubernetes (JupyterHub)

#### Access user server logs

```bash
kubectl logs -n jupyter jupyter-hub-user-username-abc123
```

#### Exec into user server

```bash
kubectl exec -it -n jupyter jupyter-hub-user-username-abc123 -- bash
```

#### List installed packages

```bash
kubectl exec -it -n jupyter jupyter-hub-user-username-abc123 -- pip list
```

#### Check JupyterHub status

```bash
helm status jupyterhub -n jupyter
```

### Docker (Standalone Testing)

#### Get running server URL

```bash
docker exec -it jupyterquant jupyter-server list
```

or

```bash
docker logs -t jupyter-quant 2>&1 | grep token=
```

#### Show jupyter config

```bash
docker exec -it jupyter-quant jupyter-server --show-config
```

#### Set password

```bash
docker exec -it jupyter-quant jupyter-server password
```

#### Get command line help

```bash
docker exec -it jupyter-quant jupyter-server --help
docker exec -it jupyter-quant jupyter-lab --help
```

#### List installed packages

```bash
docker exec -it jupyter-quant pip list
# outdated packages
docker exec -it jupyter-quant pip list -o
```

#### Pass parameters to jupyter-lab

```bash
docker run -it --rm Aidas-dev/jupyter-quant-kubernetes --core-mode
docker run -it --rm Aidas-dev/jupyter-quant-kubernetes --show-config-json
```

#### Run a command in the container

```bash
docker run -it --rm Aidas-dev/jupyter-quant-kubernetes bash
```

### Build wheels outside the container

Build wheels outside the container and import wheels into the container

```bash
# make sure python version match .env-dist
docker run -it --rm -v $PWD/wheels:/wheels python:3.11 bash
pip wheel --no-cache-dir --wheel-dir /wheels numpy
```

This will build wheels for numpy (or any other package that you need) and save
the file in `$PWD/wheels`. Then you can copy the wheels in your notebook mount
and install it within the container. You can even drag and drop into Jupyter.

### Install your dotfiles

`git clone` your dotfiles to `Notebook/etc/dotfiles`, set environment variable
`BYODF=/home/gordon/Notebook/etc/dotfiles` in your deployment config. When
the container starts up stow will create links like `/home/gordon/.bashrc`

### Install your SSH keys

You need to define environment variable `SSH_KEY_DIR` which should point to a
location with your keys. The suggested place is
`SSH_KEYDIR=/home/gordon/Notebooks/etc/ssh`, make sure the directory has the
right permissions (`chmod 700 Notebooks/etc/ssh`).

The `entrypoint.sh` script will create a symbolic link pointing to
`$SSH_KEYDIR` on `/home/gordon/.ssh`.

Within Jupyter's terminal, you can then:

```shell
# start agent
eval $(ssh-agent)
# add keys to agent
ssh-add
# open a tunnel
ssh -fNL 4001:localhost:4001 gordon@bastion-ssh
```

### Run scripts at start up

If you define `START_SCRIPTS` env variable with a path, all scripts on that
directory will be executed at start up. The sample `.env-dist` file contains
a commented line with `START_SCRIPTS=/home/gordon/Notebooks/etc/start_scripts`
as an example and recommended location.

Files should have a `.sh` suffix and should run under `bash`. in directory
[start_scripts](https://github.com/quantbelt/jupyter-quant/tree/master/start_scripts)
you will find example scripts to load ssh keys and install python packages.

### Install jupyter-quant package

Jupyter-quant is available as a package in [pypi](https://pypi.org/project/jupyter-quant/).
It's a meta-package that pulls all dependencies in it's highest possible version.

Install [pypi package](https://pypi.org/project/jupyter-quant/).

```bash
pip install -U jupyter-quant
```

Additional options supported are

```bash
pip install -U jupyter-quant[bayes] # to install pymc & arviz/graphviz

pip install -U jupyter-quant[sk-util] # to install skfolio & sktime
```

`jupyter-quant` it's a meta-package that pins all it's dependencies versions.
If you need/want to upgrade a dependency you can uninstall `jupyter-quant`,
although this can break interdependencies. Or install from git, where it's
updated regularly.

```bash
# git install
pip install -U git+https://github.com/quantbelt/jupyter-quant.git
```
