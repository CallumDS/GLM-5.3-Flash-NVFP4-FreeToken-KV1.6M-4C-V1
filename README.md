# GLM-5.3-Flash NVFP4 FreeToken configuration

This repository records the current live configuration of the FreeToken server on the host that runs `glm53-freetoken`.

## Current service

- Image: `freetoken:glm53`
- Image digest: `sha256:955f7606a6f6cb3b1d51cf8bfd72bc5ad923c672e82810ab3e005a9a99ae33b1`
- FreeToken API version: `0.1.2`
- Container: `glm53-freetoken`
- Model: `/mnt/4tb/models-glm53-mixed`
- Served model name: `glm-5.3-flash-nvfp4`
- Bind address: `0.0.0.0:8000`
- GPU: device `0`
- Container started: `2026-09-02T22:12:52Z`

The API exposes `/v1/models`, `/v1/chat/completions`, and `/health`. The health endpoint reports the service as `serving`.

## Launch command

The reproducible launcher is [`start-freetoken-glm53-flash.sh`](start-freetoken-glm53-flash.sh). Its defaults match the live container:

```bash
sudo docker run -d \
  --name glm53-freetoken --init --ipc=host --cap-add=SYS_NICE \
  --ulimit memlock=-1 --ulimit stack=67108864 \
  --ulimit nofile=1048576:1048576 --runtime=nvidia --gpus device=0 \
  -v /mnt/4tb/freetoken-glm53-cache:/root/.cache:rw \
  -v /mnt/4tb/models-glm53-mixed:/mnt/4tb/models-glm53-mixed:ro \
  -v /mnt/4tb/huggingface/hub:/mnt/4tb/huggingface/hub:ro \
  -e HF_HUB_OFFLINE=1 -e SAFETENSORS_FAST_GPU=1 \
  -e CUDA_DEVICE_ORDER=PCI_BUS_ID \
  -e FREETOKEN_GLM_ATTN_FP8=0 -e FREETOKEN_GLM_MLP_FP8=0 \
  -p 8000:8000 freetoken:glm53 serve \
  --model /mnt/4tb/models-glm53-mixed \
  --served-model-name glm-5.3-flash-nvfp4 \
  --host 0.0.0.0 --port 8000 --gpu 0 \
  --memory-ratio 0.94 --dtype bfloat16 \
  --max-seq-len-override 819200 \
  --num-tokens 1638400 --kv-reserve-tokens 1638400 \
  --max-running-requests 4 --cuda-graph-max-bs 4 \
  --max-prefill-length 8192 --cache-type radix \
  --moe-backend auto --moe-cache-auto --moe-cpu-threads 28 \
  --moe-hybrid-max-fetch -1 --nvfp4-backend auto \
  --tool-call-parser glm47 --reasoning-parser glm \
  --sampling-defaults model --enable-cache-report
```

## Runtime settings

| Setting | Value |
|---|---|
| Data type | `bfloat16` |
| KV capacity reservation | `1,638,400` tokens (1.6M) |
| Maximum model context | `819,200` tokens |
| Maximum concurrent requests | `4` |
| CUDA graph maximum batch size | `4` |
| Maximum prefill length | `8,192` |
| GPU memory ratio | `0.94` |
| KV/cache type | `radix` |
| Cache reporting | enabled |
| MoE backend | `auto` |
| MoE cache | enabled (`--moe-cache-auto`) |
| MoE CPU threads | `28` |
| MoE hybrid max fetch | `-1` |
| NVFP4 backend | `auto` |
| Attention FP8 override | disabled (`0`) |
| MLP FP8 override | disabled (`0`) |
| Tool-call parser | `glm47` |
| Reasoning parser | `glm` |
| Sampling defaults | model-defined |

No explicit `--kv-cache-dtype` override is active in the live command.

## Storage and environment

| Host path | Container path | Mode |
|---|---|---|
| `/mnt/4tb/models-glm53-mixed` | `/mnt/4tb/models-glm53-mixed` | read-only |
| `/mnt/4tb/huggingface/hub` | `/mnt/4tb/huggingface/hub` | read-only |
| `/mnt/4tb/freetoken-glm53-cache` | `/root/.cache` | read/write |

Active environment overrides:

```text
HF_HUB_OFFLINE=1
SAFETENSORS_FAST_GPU=1
CUDA_DEVICE_ORDER=PCI_BUS_ID
FREETOKEN_GLM_ATTN_FP8=0
FREETOKEN_GLM_MLP_FP8=0
```

The container also reports CUDA `13.0.1`, `TORCH_CUDA_ARCH_LIST=12.0`, `TVM_FFI_CUDA_ARCH_LIST=12.0`, `MAX_JOBS=32`, and `CMAKE_BUILD_PARALLEL_LEVEL=32`.

## Observed operation

At capture time the service was healthy and serving requests. Logs showed radix-cache hits, including a prefill with `184,576` cached tokens, two running requests, an empty request queue, and approximately `40` decode tokens/second in that sample. These are observations, not guaranteed performance figures.

The host snapshot showed an RTX PRO 5000 Blackwell with 73,415 MiB total VRAM and approximately 72,762 MiB allocated while serving. Host memory had approximately 386 GiB available. VRAM and RAM usage vary with workload.

## Start

```bash
chmod +x start-freetoken-glm53-flash.sh
./start-freetoken-glm53-flash.sh
```

The launcher supports `FREETOKEN_PORT`, `FREETOKEN_IMAGE`, `FREETOKEN_CONTAINER`, `FREETOKEN_MODEL_DIR`, `FREETOKEN_HF_HUB_DIR`, and `FREETOKEN_CACHE_DIR` overrides. It refuses to replace an existing container.

Secrets, access tokens, prompts, and private request data are intentionally excluded.
