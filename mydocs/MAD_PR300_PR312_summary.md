# MAD Distributed-Inference Refactor — PR #300 & #312 Summary

Summary of [ROCm/MAD#300](https://github.com/ROCm/MAD/pull/300) and
[ROCm/MAD#312](https://github.com/ROCm/MAD/pull/312).

> **Note:** #312 is *stacked on top of* #300 — it merges #300's head and adds the
> SGLang-specific changes on top.

---

## PR #300 — Distributed-inference refactor
*by Cemberk · OPEN (draft) · +39,398 / −2,346 · 176 files*

A large structural rework of the distributed-inference benchmark cards (vLLM
disaggregated, SGLang disaggregated, vLLM colocated multi-node) so a card
*describes* a setup rather than hard-coding a launcher. The same card runs on
SLURM, Spur, and Kubernetes — standalone or via madengine.

### Layered architecture
- **Node program** — each launcher's per-node body becomes
  `scripts/<launcher>/node.sh`, with shared logic in
  `scripts/common/node/node_lib.sh`.
- **Dispatchers** (`scripts/common/dispatch/dispatch.sh`, `MAD_DISPATCH`) —
  pluggable schedulers: `slurm-srun` (default), `spur-array` (job-array
  rendezvous on shared storage), `k8s-indexed` (one pod per node).
- **Shared launcher steps** (`launcher_lib.sh`) — node selection, address
  resolution, running the node program, verdict.
- **Topology spec** (`scripts/common/topology/`) — roles, node counts,
  parallelism, router placement expressed as data (`MAD_TOPOLOGY=<spec.json>`
  replaces `xP`/`yD` flags); `ROUTER_NODE=1` isolates the router/benchmark
  client.
- **One config order** (`config/layers.sh`) — site < connector `.env` < recipe <
  topology < submit-time; each run writes `config.resolved.json` showing every
  value and the layer that set it.
- **Pin-set images** — `docker/di_vllm` and `docker/di_sglang` build any pin set
  from `docker/pins/` (base image by digest per GPU arch, components at upstream
  commits, fork changes as patches in `docker/patches/`). The four per-model
  Dockerfiles are deleted.

### Bug fixes
- Recipe `env:` values being overridden when `cluster.sh`/connector `.env` set them.
- SGLang sorting nodes by name (misassigned ranks with 10+ unpadded names).
- Over-registration of decode backends (SGLang and rixl).
- SGLang/colocated launchers failing under `sbatch`.
- Missing server-metrics flags on SGLang's router-hosting prefill node.

### Testing
GPU-free snapshot harness (`snapshot.py`) — 42/42 cards unchanged across all
modes (plain, `--spooled`, `--equivalence spur-array`, `--equivalence
k8s-indexed`, `--spec-file`). Real-cluster runs still pending before merge.

---

## PR #312 — SGLang render (recipes as data)
*by vdar25 · OPEN · changes below are only what's added on top of #300*

Converts the SGLang disaggregated recipe's server/router commands from shell
into data-driven rendering, plus fabric-portability fixes discovered bringing
the recipe up on Broadcom Thor2 NICs.

### Recipes as data (`scripts/sglang_disagg/render.py`, `models.yaml`)
- `models.yaml` is layered (`defaults` → per-model `base`/`modes`/`roles` with
  `extends`, plus `backends`, `overlays`, `compat`).
- `render.py shell --rank N` emits a node's role, server argv, and router argv —
  the three hand-built command strings, inline YAML reader, and parallel-size
  math are gone.
- `render.py validate` replaces hard-coded model lists; `plan` previews commands
  GPU-free; `check` reports flags the image's SGLang won't accept.

### SGLang version compat (replaces `sglang_compat.sh`)
- `compat` section lists renamed/removed flags, applied only when the installed
  SGLang's `--help` no longer accepts the original (e.g. 0.5.20:
  `--cuda-graph-bs` → `--cuda-graph-bs-decode`, drop
  `--prefill-round-robin-balance`). On 0.5.12 commands are unchanged.

### Broadcom Thor2 / MI350X support
- gfx950 image builds rdma-core v61.0 over the base (new `rdma_core` pin
  component) to support the in-kernel `bnxt_re` driver.
- RDMA preflight: `ibv_rc_pingpong` loopback per `IB_DEVICES` NIC before the
  barrier, so a bad NIC fails in seconds instead of hanging the first KV
  transfer. `RDMA_PREFLIGHT=0` skips it.

### Site setting
- `CONTAINER_PRIVILEGE_ARGS` (default `--privileged`) replaces hard-coded
  `--privileged`; fallback `--cap-add IPC_LOCK --ulimit memlock=-1:-1` where
  Docker refuses privileged containers.

### Fabric-agnostic benchmarks
- `kvcache_transfer_bench` and `large-ep-benchmark` get NIC/GID/interface
  detection from `cluster.sh` (Thor2 + AINIC detected, CX7 unchanged), addresses
  on `FABRIC_SUBNET_PREFIX`, roles matched on short hostnames; no longer pin
  `IBDEVICE=mlx5_0`.

### Compatibility
18 SGLang snapshot goldens re-recorded — every `docker run` identical, every
server/router command has the same flags/values in a different order (plus one
dedupe: DeepSeek prefill's doubled `--mem-fraction-static`).

### Testing
Offline tests all pass. GPU run on MI300X (DeepSeek-V3, MoRI EP DP attention) is
set up with throughput baselines but results still *pending*; Thor2/MI350X
result TODO.

---

## In short
- **#300** lays down the generalized multi-scheduler framework (dispatchers,
  topology specs, config layers, pin-set images).
- **#312** builds on it to make the SGLang recipe fully data-driven and portable
  across network fabrics.

Both are still open drafts awaiting real-cluster validation.
