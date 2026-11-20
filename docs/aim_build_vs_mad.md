# AIM-build vs ROCm/MAD — Offering Analysis

A comparison of [`amd-enterprise-ai/aim-build`](https://github.com/amd-enterprise-ai/aim-build)
and [`ROCm/MAD`](https://github.com/ROCm/MAD). These two AMD repos solve **different parts
of the model lifecycle** and are complementary, not competing.

## Summary table

| | **amd-enterprise-ai/aim-build** | **ROCm/MAD** |
|---|---|---|
| **Name** | AMD Inference Microservice (AIM) Containers | Model Automation & Dashboarding |
| **Core job** | **Deploy & serve** models in production | **Benchmark & measure** model recipes |
| **Output** | A running OpenAI-compatible inference endpoint | `perf.csv` / `perf.html` performance reports |
| **Primary user** | Enterprise/customer deploying inference | AMD perf/CI engineers, recipe developers |
| **Driver** | `aim` runtime CLI (`serve`, `dry-run`, `detect-hardware`) | `madengine run --tags ...` |
| **Config model** | YAML **profiles**, auto-selected from detected HW | `models.json` entries (~191) + per-model Dockerfile + `run.sh` |
| **Engine(s)** | vLLM (extensible), OpenAI-compatible API | vLLM, SGLang, PyTorch, JAX/MaxText, Megatron-LM, Primus, xDiT, llm-foundry |
| **Workloads** | Inference serving only | Training, fine-tuning, inference, micro-benchmarks (P/D disagg, KV-cache, Large-EP) |
| **Deploy targets** | Docker, **Kubernetes, KServe** | Docker host (single-node benchmark runs) |
| **Hardware** | Instinct MI300X/325X/350X/355X, Radeon Pro W7900/R9700, EPYC CPU | AMD Instinct + NVIDIA (ROCm/CUDA) |
| **Model catalog** | ~56 Instinct + 25 EPYC + 8 Radeon (curated AIMs) | 191 model configs across many frameworks |
| **License** | Dual: MIT + AMD EPYC AIMs License | See repo `LICENSE.txt` |

## What each actually does

### aim-build (AIM)

A **production inference serving** framework. Its value is **zero-tuning deployment**:
at container start it detects the GPU model/count/memory via AMD SMI, then a
`ProfileSelector` picks the optimal YAML profile (filtered by accelerator → GPU count →
engine → latency/throughput metric → precision, preferring "optimized" profiles). A
`CommandGenerator` turns that into vLLM engine args and launches a supervised process
exposing an OpenAI-compatible API.

Notable production features:

- **Two container tiers**: generic base (`aim-base`, `aim-epyc-base`, `aim-radeon-base`)
  that accept any model at runtime via `AIM_MODEL_ID`, and model-specific containers with
  pre-baked optimized profiles.
- Precision flexibility (FP4/FP8/FP16/FP32/BF16/INT4/INT8), custom profile overrides,
  HF/local model caching with fallback.
- Hardening: non-root execution, read-only profile mounts, GPU-idle health checks before
  startup, argv-based (no-shell) subprocess exec, structured logging.

Core components: `AIMRuntime` (orchestrator), `ProfileSelector`, `AcceleratorDetector`,
`CommandGenerator`, and the vLLM/engine runtime.

### MAD

A **benchmarking/CI harness**. For each `models.json` entry it:

1. Builds a `ci-<model>` Docker image
2. Launches `container_<model>`
3. Clones the recipe repo
4. Runs the script
5. Emits `perf.csv` / `perf.html`

Its value is **reproducible cross-framework, cross-arch performance measurement**, now
fronted by the separate [`madengine`](https://github.com/ROCm/madengine) CLI. It also ships
"blueprints" — documented day-0 recipes (Kimi-K3, vLLM/SGLang inference, JAX/Megatron/Primus
training, xDiT diffusion, P/D-disaggregated serving, etc.).

## How they relate

Think of it as a pipeline:

- **MAD proves out and measures** the best recipe/config for a model on given hardware.
- **AIM packages the winning configuration** as a deployable, self-optimizing microservice
  for customers.

MAD answers *"how fast and how?"*; AIM answers *"ship it behind an API."*

## When to use which

- Standing up an inference endpoint for customers / K8s / KServe → **aim-build**.
- Comparing frameworks, precisions, or GPU archs; CI perf regression; training or
  fine-tuning recipes → **MAD**.

## Sources

- [ROCm/MAD](https://github.com/ROCm/MAD) — README and repo structure
- [amd-enterprise-ai/aim-build](https://github.com/amd-enterprise-ai/aim-build) —
  `README.md`, `docs/aim_architecture.md`, `docs/latest_aims.md`
