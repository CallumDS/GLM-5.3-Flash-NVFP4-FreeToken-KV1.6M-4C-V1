#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${FREETOKEN_IMAGE:-freetoken:glm53}"
CONTAINER_NAME="${FREETOKEN_CONTAINER:-glm53-freetoken}"
MODEL_DIR="${FREETOKEN_MODEL_DIR:-/mnt/4tb/models-glm53-mixed}"
HF_HUB_DIR="${FREETOKEN_HF_HUB_DIR:-/mnt/4tb/huggingface/hub}"
CACHE_DIR="${FREETOKEN_CACHE_DIR:-/mnt/4tb/freetoken-glm53-cache}"
PORT="${FREETOKEN_PORT:-8000}"

[[ -d "$MODEL_DIR" ]] || { echo "Model directory does not exist: $MODEL_DIR" >&2; exit 1; }
[[ -d "$HF_HUB_DIR" ]] || { echo "Hugging Face cache directory does not exist: $HF_HUB_DIR" >&2; exit 1; }
mkdir -p "$CACHE_DIR"

if sudo docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  echo "Container already exists: $CONTAINER_NAME" >&2
  echo "Stop/remove it first, or set FREETOKEN_CONTAINER." >&2
  exit 2
fi

exec sudo docker run -d \
  --name "$CONTAINER_NAME" --init --ipc=host --cap-add=SYS_NICE \
  --ulimit memlock=-1 --ulimit stack=67108864 \
  --ulimit nofile=1048576:1048576 --runtime=nvidia --gpus device=0 \
  -v "$CACHE_DIR:/root/.cache:rw" \
  -v "$MODEL_DIR:$MODEL_DIR:ro" \
  -v "$HF_HUB_DIR:$HF_HUB_DIR:ro" \
  -e HF_HUB_OFFLINE=1 -e SAFETENSORS_FAST_GPU=1 \
  -e CUDA_DEVICE_ORDER=PCI_BUS_ID \
  -e FREETOKEN_GLM_ATTN_FP8=0 -e FREETOKEN_GLM_MLP_FP8=0 \
  -p "$PORT:8000" "$IMAGE" serve \
  --model "$MODEL_DIR" --served-model-name glm-5.3-flash-nvfp4 \
  --host 0.0.0.0 --port 8000 --gpu 0 --memory-ratio 0.94 \
  --dtype bfloat16 --max-seq-len-override 819200 \
  --num-tokens 1638400 --kv-reserve-tokens 1638400 \
  --max-running-requests 4 --cuda-graph-max-bs 4 \
  --max-prefill-length 8192 --cache-type radix \
  --moe-backend auto --moe-cache-auto --moe-cpu-threads 28 \
  --moe-hybrid-max-fetch -1 --nvfp4-backend auto \
  --tool-call-parser glm47 --reasoning-parser glm \
  --sampling-defaults model --enable-cache-report
