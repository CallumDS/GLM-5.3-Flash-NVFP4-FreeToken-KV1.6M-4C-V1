# GLM-5.3-Flash NVFP4 FreeToken configuration

This repository records reproducible text-only and vision-enabled FreeToken
configurations for GLM-5.3-Flash on an RTX PRO 5000 Blackwell.

## Current vision service

- Container: `glm53-freetoken-mm-port8`
- Image: `freetoken-glm53-mm:port8`
- FreeToken API version: `0.1.2`
- Model: `/mnt/4tb/models-glm53-mixed`
- Served model: `glm-5.3-flash-freetoken-image-test`
- Endpoint: `http://127.0.0.1:8000/v1`
- GPU: device `0`
- Vision: enabled with `FREETOKEN_LOAD_VISION=1`
- Launcher: [`start-freetoken-glm53-flash-vision.sh`](start-freetoken-glm53-flash-vision.sh)

The vision bridge loads the GLM-5 visual encoder from the checkpoint, accepts
image URLs/data URIs in OpenAI-style message content, converts them to vision
embeddings, and expands the image marker into language-model placeholder
tokens. Text-only requests continue to use the normal decode path.

## Optimized launch settings

```text
--num-tokens 1638400
--kv-reserve-tokens 1638400
--max-running-requests 4
--cuda-graph-max-bs 4
--moe-backend hybrid
--moe-cache-auto
--moe-cpu-threads 28
--moe-hybrid-max-fetch -1
--nvfp4-backend auto
```

`--moe-hybrid-max-fetch -1` uses the GPU-specific `ft bench bw` profile in
`/root/.cache/freetoken/benchbw/`. On this machine it selects a 19.2% PCIe
fetch fraction and computes the remaining expert misses on the CPU. The cache
mount uses `/mnt/4tb/freetoken-glm53-cache`, containing the profile for GPU
UUID `GPU-4bc146b6-b136-ab90-52c8-36923f404b73`.

| Setting | Value |
|---|---|
| Data type | `bfloat16` |
| KV reservation | 1,638,400 tokens / 1.6M |
| Maximum model context | 819,200 tokens |
| Maximum concurrent requests | 4 |
| CUDA graph maximum batch | 4 |
| Maximum prefill length | 8,192 |
| GPU memory ratio | 0.94 |
| Cache type | `radix` |
| MoE CPU threads | 28 |
| Tool-call parser | `glm47` |
| Reasoning parser | `glm` |
| Attention/MLP FP8 overrides | disabled (`0`) |

## Benchmark results

Source: `glm53_flash_ft_vision_full_2.json`, measured 2026-09-04 with
`llm-decode-bench` v0.4.34, 30 seconds per cell, 8,192 maximum output
tokens, using OpenAI streaming measurement. Prometheus metrics were
unavailable, so aggregate throughput comes from streamed output tokens.

Aggregate decode throughput in tokens/second:

| Context | C=1 | C=2 | C=4 |
|---:|---:|---:|---:|
| 0 | 33.75 | 49.95 | 69.13 |
| 8k | 32.60 | 48.58 | 65.10 |
| 16k | 32.79 | 48.13 | 67.39 |
| 32k | 32.75 | 47.97 | 62.87 |
| 64k | 32.97 | 50.02 | 61.31 |

At 32k context, the single-user result was **32.75 tok/s** and the
concurrency-4 result was **62.87 aggregate tok/s**. Single-user TTFT was
approximately 3.0 seconds across the matrix.

For comparison, the earlier vision configuration that resolved `auto` to the
offload backend measured 18.44 tok/s at 32k. Explicit hybrid with the
bandwidth profile restored performance to approximately 32.7 tok/s, within
measurement noise of the prior non-vision hybrid configuration.

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
FREETOKEN_LOAD_VISION=1
FREETOKEN_VISION_MODEL_PATH=/mnt/4tb/models-glm53-mixed
CUDA_DEVICE_ORDER=PCI_BUS_ID
FREETOKEN_GLM_ATTN_FP8=0
FREETOKEN_GLM_MLP_FP8=0
```

## Starting the vision service

```bash
chmod +x start-freetoken-glm53-flash-vision.sh
./start-freetoken-glm53-flash-vision.sh
```

The launcher refuses to replace an existing container. It supports
`FREETOKEN_IMAGE_TEST_IMAGE`, `FREETOKEN_IMAGE_TEST_CONTAINER`,
`FREETOKEN_IMAGE_TEST_MODEL_DIR`, `FREETOKEN_IMAGE_TEST_HF_HUB_DIR`,
`FREETOKEN_IMAGE_TEST_CACHE_DIR`, and `FREETOKEN_IMAGE_TEST_PORT` overrides.

The original text-only launcher remains available as
[`start-freetoken-glm53-flash.sh`](start-freetoken-glm53-flash.sh).

Secrets, access tokens, prompts, and private request data are intentionally
excluded.
