# Infrastructure notes

Not config, but the reasoning is expensive to rediscover.

## Disk

Reclaimed 32.9 G → 28.8 G. `disk_report.sh` (read-only) and `cleanup.sh`
(prompts before each delete) live in the repo root.

Where it actually goes:

```
Docker              ~15 G   (open-webui alone is 6.4 G)
/mnt/data/swapfile    4 G   normal, leave it
ESPHome            ~2.4 G   live toolchains after cleanup
backups            ~1.2 G
recorder DB        ~386 M
```

Findings worth keeping:

- **ESPHome had no stale toolchains.** Every tool dir held exactly one version.
  The reclaimable parts were `cache/idf/dist` (594 M of already-extracted
  tarballs) and the riscv32 toolchain (2.0 G), unused because every device here
  is xtensa ESP32.
- **The journal grows ~50 MB/day** when voice-pipeline loggers are at debug.
  They are at `warning` in `configuration.yaml` for that reason.
- `find -size +200M` **silently matches nothing** on busybox. Use 512-byte
  blocks: `-size +409600`.

## Network (UniFi UDR-5G-Max)

- 5 GHz was **three radios on overlapping channels** — two APs both on 153,
  inside the gateway's 80 MHz block at 149. Now 36 / 44 / 149, no overlap, no
  DFS.
- **BSS Transition (802.11v) and Fast Roaming (802.11r) are off.** A client was
  being steered off a −38 dBm AP onto a −61 dBm one, failing authentication
  there, and going offline ~30 s each time. Roaming away from −38 is never a
  client-side decision.
- **The IoT SSID isolates nothing.** All SSIDs share one network object, there
  are no VLANs, and `l2_isolation` is false. Camera-to-HA-only restriction is
  **not enforceable** on a flat network: same-subnet traffic is switched at L2
  and never reaches the gateway firewall. The existing "no internet" rule works
  only because that traffic crosses a zone boundary. Deferred to the house move.
- IDS is in `ids` (detect) mode. The UDR-5G-Max is rated **2.3 Gbps IDS/IPS**,
  roughly 3× the old Dream Machine, so blocking mode is within budget — but
  gateway memory sits at 82%, which is the thing to watch.

## Voice

Pipeline: openWakeWord → OpenAI STT → `conversation.ben_router` (Hermes) →
OpenAI TTS. A local pipeline also exists: Speech-to-Phrase + Piper.

- **Groq is a good STT swap** — `whisper-large-v3-turbo`, multilingual, free
  tier covers a household comfortably (20 RPM, 2000 RPD, 28800 audio sec/day,
  10-second minimum billing per request).
- **Groq TTS cannot be used**: Orpheus supports English and Arabic only. This
  pipeline is Spanish.
- **Do not add the local Whisper add-on.** On this i5-8259U (AVX2, no AVX-512,
  no CUDA) it would be both slower *and* less accurate than Groq. Measured
  cloud floor to Groq is ~145 ms; local add-ons are 0 ms, but Speech-to-Phrase
  is fixed-vocabulary and cannot feed an LLM.
- Piper is already local and would cut TTS latency versus OpenAI TTS.
