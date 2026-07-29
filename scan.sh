#!/bin/bash
# ==============================================================================
#  Ollama Hardware Scanner — Startup Script
#  Runs inside the custom Ollama container on every boot.
#
#  What this does:
#    1. Reads host CPU, RAM, GPU specs from /proc, /sys, nvidia-smi
#    2. Runs llm-checker to get scored model recommendations
#    3. Runs llmfit to show per-model fit analysis
#    4. Runs whichllm for benchmark-ranked GPU-aware suggestions
#    5. Writes the full report to /scan/hardware-report.txt
#    6. Starts the Ollama server normally
# ==============================================================================

set -euo pipefail

REPORT_DIR="/scan"
REPORT_FILE="$REPORT_DIR/hardware-report.txt"
mkdir -p "$REPORT_DIR"

# ── ANSI colours (safe in Docker logs) ───────────────────────────────────────
BOLD="\033[1m"
CYAN="\033[1;36m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

banner() {
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD} $1${RESET}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

section() {
  echo ""
  echo -e "${YELLOW}▶ $1${RESET}"
  echo ""
}

# ── Write header to report ────────────────────────────────────────────────────
{
  echo "============================================================"
  echo " OLLAMA HARDWARE SCAN REPORT"
  echo " Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "============================================================"
} > "$REPORT_FILE"

# ==============================================================================
#  SECTION 1: Raw hardware detection from /proc and /sys
# ==============================================================================
banner "🖥️  HARDWARE PROFILE — HOST SYSTEM"

section "CPU"
CPU_MODEL=$(grep -m1 'model name' /host/proc/cpuinfo 2>/dev/null \
  || grep -m1 'model name' /proc/cpuinfo 2>/dev/null \
  || echo "Unknown CPU")
CPU_CORES=$(grep -c '^processor' /host/proc/cpuinfo 2>/dev/null \
  || grep -c '^processor' /proc/cpuinfo 2>/dev/null \
  || echo "?")
echo -e "  Model  : ${GREEN}${CPU_MODEL#*: }${RESET}"
echo -e "  Cores  : ${GREEN}${CPU_CORES}${RESET}"

section "System RAM"
TOTAL_KB=$(grep MemTotal /host/proc/meminfo 2>/dev/null \
  || grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}' \
  || echo "0")
# Try host proc first, then fallback
if grep -q MemTotal /host/proc/meminfo 2>/dev/null; then
  TOTAL_KB=$(grep MemTotal /host/proc/meminfo | awk '{print $2}')
else
  TOTAL_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
fi
TOTAL_GB=$(( TOTAL_KB / 1024 / 1024 ))
echo -e "  Total RAM : ${GREEN}${TOTAL_GB} GB${RESET}"

section "GPU (NVIDIA)"
if command -v nvidia-smi &>/dev/null; then
  nvidia-smi \
    --query-gpu=name,memory.total,memory.free,driver_version,compute_cap \
    --format=csv,noheader | while IFS=',' read -r name total free driver cap; do
      echo -e "  GPU       : ${GREEN}${name}${RESET}"
      echo -e "  VRAM Total: ${GREEN}${total}${RESET}"
      echo -e "  VRAM Free : ${GREEN}${free}${RESET}"
      echo -e "  Driver    : ${GREEN}${driver}${RESET}"
      echo -e "  CUDA Cap  : ${GREEN}${cap}${RESET}"
  done
else
  echo -e "  ${YELLOW}⚠ nvidia-smi not found — CPU-only mode or GPU not passed through${RESET}"
fi

# Write raw specs to report file
{
  echo ""
  echo "--- CPU ---"
  echo "Model : ${CPU_MODEL#*: }"
  echo "Cores : ${CPU_CORES}"
  echo ""
  echo "--- RAM ---"
  echo "Total : ${TOTAL_GB} GB"
  echo ""
  echo "--- GPU ---"
  if command -v nvidia-smi &>/dev/null; then
    nvidia-smi --query-gpu=name,memory.total,memory.free,driver_version,compute_cap \
      --format=csv,noheader
  else
    echo "No NVIDIA GPU detected"
  fi
} >> "$REPORT_FILE"

# ==============================================================================
#  SECTION 2: llm-checker — 4D scored recommendations
# ==============================================================================
banner "📊  LLM-CHECKER — Model Recommendations for This Hardware"

if command -v llm-checker &>/dev/null; then
  section "Hardware Detection"
  llm-checker hw-detect 2>/dev/null | tee -a "$REPORT_FILE" || true

  section "Recommended Models (General)"
  llm-checker recommend 2>/dev/null | tee -a "$REPORT_FILE" || true

  section "Recommended Models (Coding / Agentic)"
  llm-checker recommend --category coding 2>/dev/null | tee -a "$REPORT_FILE" || true
else
  echo -e "${YELLOW}  llm-checker not available — skipping${RESET}"
  echo "llm-checker: not installed" >> "$REPORT_FILE"
fi

# ==============================================================================
#  SECTION 3: llmfit — Interactive TUI fit analysis (non-interactive JSON mode)
# ==============================================================================
banner "🔩  LLMFIT — Hardware Fit Analysis"

LLMFIT_BIN=""
for p in /usr/local/bin/llmfit /root/.cargo/bin/llmfit; do
  [ -f "$p" ] && LLMFIT_BIN="$p" && break
done

if [ -n "$LLMFIT_BIN" ]; then
  section "Model Compatibility (JSON output)"
  # llmfit supports --output json for non-interactive use
  $LLMFIT_BIN --output json 2>/dev/null | tee -a "$REPORT_FILE" \
    || $LLMFIT_BIN 2>/dev/null | head -60 | tee -a "$REPORT_FILE" \
    || echo "  llmfit ran but produced no output" | tee -a "$REPORT_FILE"
else
  echo -e "${YELLOW}  llmfit not available — skipping${RESET}"
  echo "llmfit: not installed" >> "$REPORT_FILE"
fi

# ==============================================================================
#  SECTION 4: whichllm — Benchmark-ranked GPU-aware suggestions
# ==============================================================================
banner "🏆  WHICHLLM — Benchmark-Ranked Model Suggestions"

WHICHLLM_BIN=""
for p in /usr/local/bin/whichllm /root/.local/bin/whichllm; do
  [ -f "$p" ] && WHICHLLM_BIN="$p" && break
done

if [ -n "$WHICHLLM_BIN" ]; then
  section "Top models for your GPU (GPU-only, 1GB VRAM headroom)"
  $WHICHLLM_BIN --gpu-only --speed usable --vram-headroom 1GB 2>/dev/null \
    | tee -a "$REPORT_FILE" || true

  section "Full benchmark-ranked recommendation"
  $WHICHLLM_BIN 2>/dev/null | head -80 | tee -a "$REPORT_FILE" || true
else
  echo -e "${YELLOW}  whichllm not available — skipping${RESET}"
  echo "whichllm: not installed" >> "$REPORT_FILE"
fi

# ==============================================================================
#  SECTION 5: Inline VRAM-based suggestion table (always runs, no deps)
# ==============================================================================
banner "💡  BUILT-IN VRAM GUIDE — What You Can Run Right Now"

if command -v nvidia-smi &>/dev/null; then
  VRAM_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1 | tr -d ' ')
  VRAM_GB=$(( VRAM_MB / 1024 ))
  echo -e "  Detected VRAM: ${GREEN}${VRAM_GB} GB${RESET}"
  echo ""
  if   [ "$VRAM_GB" -ge 48 ]; then
    echo -e "  ${GREEN}✅ Tier: FLAGSHIP${RESET} — Can run 70B+ models (llama3:70b, qwen2.5:72b)"
  elif [ "$VRAM_GB" -ge 24 ]; then
    echo -e "  ${GREEN}✅ Tier: ENTHUSIAST${RESET} — Can run 32B models (qwen2.5:32b, deepseek-r1:32b)"
  elif [ "$VRAM_GB" -ge 16 ]; then
    echo -e "  ${GREEN}✅ Tier: HIGH-END${RESET} — Can run 14B models (gemma3:12b, phi4:14b)"
  elif [ "$VRAM_GB" -ge 10 ]; then
    echo -e "  ${GREEN}✅ Tier: MID-RANGE${RESET} — Can run 12B models (gemma3:12b, mistral:12b)"
  elif [ "$VRAM_GB" -ge 6 ]; then
    echo -e "  ${YELLOW}✅ Tier: STANDARD${RESET} — Best at 7B models (qwen2.5:7b, hermes3, llava:7b)"
  elif [ "$VRAM_GB" -ge 4 ]; then
    echo -e "  ${YELLOW}⚡ Tier: COMPACT${RESET} — Best at 4B models (gemma3:4b, phi4-mini)"
  else
    echo -e "  ${YELLOW}⚡ Tier: MINIMAL${RESET} — Best at 1-3B models (deepseek-r1:1.5b, moondream)"
  fi
else
  TOTAL_GB_INT=${TOTAL_GB:-0}
  echo -e "  ${YELLOW}No GPU detected — using system RAM (${TOTAL_GB_INT} GB) for CPU inference${RESET}"
  if   [ "$TOTAL_GB_INT" -ge 32 ]; then
    echo -e "  ${GREEN}✅ CPU Tier: HIGH${RESET} — Can run 13B models via CPU (slow but functional)"
  elif [ "$TOTAL_GB_INT" -ge 16 ]; then
    echo -e "  ${YELLOW}✅ CPU Tier: MID${RESET} — Best at 7B models on CPU"
  else
    echo -e "  ${YELLOW}⚡ CPU Tier: LOW${RESET} — Best at 3B models on CPU"
  fi
fi

# ==============================================================================
#  Final summary
# ==============================================================================
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${GREEN}  ✅ Scan complete. Full report saved to: $REPORT_FILE${RESET}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
echo -e "  Read it any time with:  ${BOLD}docker exec ollama cat $REPORT_FILE${RESET}"
echo -e "  Re-run scan:            ${BOLD}docker exec ollama /scan.sh${RESET}"
echo ""

# ==============================================================================
#  Hand off to real Ollama server
# ==============================================================================
echo -e "${GREEN}▶ Starting Ollama server...${RESET}"
exec /bin/ollama serve
