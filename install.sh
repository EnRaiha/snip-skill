#!/bin/sh
# install.sh — Install snip skill: binary + plugin + safe config + skill
# Usage: curl -fsSL https://raw.githubusercontent.com/<user>/snip-skill/main/install.sh | sh
#        curl -fsSL https://raw.githubusercontent.com/<user>/snip-skill/main/install.sh | sh -s -- --help

set -e

REPO="edouard-claude/snip"
SKILL_REPO="EnRaiha/snip-skill"
INSTALL_DIR="/usr/local/bin"
FALLBACK_DIR="${HOME}/.local/bin"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
SNIP_CONFIG_DIR="${HOME}/.config/snip"
SKILL_NAME="snip"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { printf "${CYAN}[snip-skill]${NC} %s\n" "$1"; }
ok()    { printf "${GREEN}[snip-skill]${NC} %s\n" "$1"; }
warn()  { printf "${YELLOW}[snip-skill]${NC} %s\n" "$1"; }
error() { printf "${RED}[snip-skill]${NC} %s\n" "$1" >&2; exit 1; }

need_cmd() {
  if ! command -v "$1" > /dev/null 2>&1; then
    error "required command not found: $1"
  fi
}

confirm() {
  printf "%s [y/N] " "$1"
  read -r response
  case "$response" in
    [yY][eE][sS]|[yY]) return 0 ;;
    *) return 1 ;;
  esac
}

detect_os() {
  case "$(uname -s)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "darwin" ;;
    *)       error "unsupported OS: $(uname -s)" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo "amd64" ;;
    aarch64|arm64)  echo "arm64" ;;
    *)              error "unsupported architecture: $(uname -m)" ;;
  esac
}

install_snip_binary() {
  if command -v snip > /dev/null 2>&1; then
    ok "snip already installed ($(snip --version 2>&1 || echo "unknown version"))"
    return 0
  fi

  info "installing snip binary..."

  OS="$(detect_os)"
  ARCH="$(detect_arch)"
  info "detected platform: ${OS}/${ARCH}"

  LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')

  [ -z "${LATEST_TAG}" ] && error "could not determine latest snip release"

  VERSION="${LATEST_TAG#v}"
  ARCHIVE="snip_${VERSION}_${OS}_${ARCH}.tar.gz"
  URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/${ARCHIVE}"

  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "${TMP_DIR}"' EXIT

  info "downloading ${URL}"
  curl -fsSL -o "${TMP_DIR}/${ARCHIVE}" "${URL}"

  info "extracting..."
  tar xzf "${TMP_DIR}/${ARCHIVE}" -C "${TMP_DIR}"

  [ ! -f "${TMP_DIR}/snip" ] && error "binary not found in archive"

  if [ -d "${INSTALL_DIR}" ] && [ -w "${INSTALL_DIR}" ]; then
    TARGET="${INSTALL_DIR}/snip"
  else
    mkdir -p "${FALLBACK_DIR}"
    TARGET="${FALLBACK_DIR}/snip"
    warn "${INSTALL_DIR} not writable, installing to ${FALLBACK_DIR}"
  fi

  mv "${TMP_DIR}/snip" "${TARGET}"
  chmod +x "${TARGET}"

  if "${TARGET}" --version > /dev/null 2>&1; then
    INSTALLED_VERSION="$("${TARGET}" --version 2>&1 || true)"
    ok "installed ${INSTALLED_VERSION} to ${TARGET}"
  else
    ok "installed snip to ${TARGET}"
  fi

  case ":${PATH}:" in
    *":$(dirname "${TARGET}"):"*) ;;
    *)
      warn "$(dirname "${TARGET}") is not in your PATH"
      info "Add it with:  export PATH=\"$(dirname "${TARGET}"):\${PATH}\""
      ;;
  esac
}

install_skill_file() {
  mkdir -p "${CLAUDE_SKILLS_DIR}/${SKILL_NAME}"

  SKILL_SOURCE="./SKILL.md"
  SKILL_TARGET="${CLAUDE_SKILLS_DIR}/${SKILL_NAME}/SKILL.md"

  if [ -f "${SKILL_TARGET}" ]; then
    if ! confirm "Overwrite existing ${SKILL_TARGET}?"; then
      info "skipping skill installation"
      return 0
    fi
  fi

  if [ -f "${SKILL_SOURCE}" ]; then
    cp "${SKILL_SOURCE}" "${SKILL_TARGET}"
    ok "installed skill to ${SKILL_TARGET}"
  else
    info "downloading SKILL.md..."
    curl -fsSL -o "${SKILL_TARGET}" \
      "https://raw.githubusercontent.com/${SKILL_REPO}/main/SKILL.md" \
      && ok "downloaded skill to ${SKILL_TARGET}" \
      || warn "could not download skill file, skipping"
  fi
}

install_config() {
  mkdir -p "${SNIP_CONFIG_DIR}"

  CONFIG_TARGET="${SNIP_CONFIG_DIR}/config.toml"
  CONFIG_SOURCE="./config/config.toml"

  if [ -f "${CONFIG_TARGET}" ]; then
    if ! confirm "Overwrite existing ${CONFIG_TARGET}?"; then
      info "skipping config installation"
      return 0
    fi
  fi

  if [ -f "${CONFIG_SOURCE}" ]; then
    cp "${CONFIG_SOURCE}" "${CONFIG_TARGET}"
    ok "installed config to ${CONFIG_TARGET}"
  else
    curl -fsSL -o "${CONFIG_TARGET}" \
      "https://raw.githubusercontent.com/${SKILL_REPO}/main/config/config.toml" \
      && ok "downloaded config to ${CONFIG_TARGET}" \
      || warn "could not download config, skipping"
  fi
}

install_opencode_plugin() {
  OPENCODE_GLOBAL="${HOME}/.config/opencode/opencode.json"
  OPENCODE_LOCAL=".opencode/opencode.json"

  TARGET_FILE=""
  if [ -f "${OPENCODE_LOCAL}" ]; then
    TARGET_FILE="${OPENCODE_LOCAL}"
  elif [ -f "${OPENCODE_GLOBAL}" ]; then
    TARGET_FILE="${OPENCODE_GLOBAL}"
  else
    info "no opencode.json found — creating global config"
    mkdir -p "${HOME}/.config/opencode"
    TARGET_FILE="${OPENCODE_GLOBAL}"
  fi

  if [ -f "${TARGET_FILE}" ]; then
    if grep -q "opencode-snip" "${TARGET_FILE}" 2>/dev/null; then
      ok "opencode-snip plugin already in ${TARGET_FILE}"
      return 0
    fi
  fi

  if ! confirm "Add opencode-snip plugin to ${TARGET_FILE}?"; then
    info "skipping plugin installation"
    return 0
  fi

  if [ -f "${TARGET_FILE}" ]; then
    TMP_JSON="$(mktemp)"
    if command -v jq > /dev/null 2>&1; then
      jq '.plugin = (.plugin // []) + ["opencode-snip@latest"]' "${TARGET_FILE}" > "${TMP_JSON}" \
        && mv "${TMP_JSON}" "${TARGET_FILE}"
    else
      sed 's/"plugin": \[/"plugin": ["opencode-snip@latest", /' "${TARGET_FILE}" > "${TMP_JSON}" \
        && mv "${TMP_JSON}" "${TARGET_FILE}"
    fi
  else
    cat > "${TARGET_FILE}" << 'JSONEOF'
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["opencode-snip@latest"]
}
JSONEOF
  fi

  ok "added opencode-snip plugin to ${TARGET_FILE}"
  warn "restart OpenCode session for plugin to take effect"
}

print_summary() {
  printf '\n'
  info "═══════════════════════════════════════════"
  info "  snip-skill installation complete"
  info "═══════════════════════════════════════════"
  printf '\n'
  info "  ✓ snip binary"
  info "  ✓ safe config:     ~/.config/snip/config.toml"
  info "  ✓ skill file:      ~/.claude/skills/snip/SKILL.md"
  printf '\n'

  if grep -q "opencode-snip" "${TARGET_FILE:-/dev/null}" 2>/dev/null; then
    info "  ✓ opencode plugin: ${TARGET_FILE}"
    info "    (restart OpenCode to activate)"
    printf '\n'
  fi

  info "  ╔══════════════════════════════════════╗"
  info "  ║      ESCAPE PROTOCOL (remember)      ║"
  info "  ╠══════════════════════════════════════╣"
  info "  ║                                      ║"
  info "  ║  Output looks wrong?                 ║"
  info "  ║    → snip proxy <command>            ║"
  info "  ║                                      ║"
  info "  ║  See raw output:                     ║"
  info "  ║    → ls ~/.local/share/snip/tee/     ║"
  info "  ║                                      ║"
  info "  ║  Disable a filter:                   ║"
  info "  ║    → edit ~/.config/snip/config.toml ║"
  info "  ║    → add: curl = false               ║"
  info "  ║                                      ║"
  info "  ╚══════════════════════════════════════╝"
  printf '\n'
  info "  All 126 filters documented in:"
  info "    ~/.claude/skills/snip/SKILL.md"
  printf '\n'
}

main() {
  need_cmd curl
  need_cmd tar
  need_cmd uname

  info "snip-skill installer"
  info "═══════════════════════════════════════════"
  printf '\n'

  install_snip_binary
  install_skill_file
  install_config
  install_opencode_plugin
  print_summary
}

main "$@"
