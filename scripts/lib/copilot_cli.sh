#!/usr/bin/env bash

resolve_copilot_cli() {
  local candidate=""
  local current_path=""
  local latest_nvm_path=""
  local dir
  local -a nvm_candidates=()

  if [[ -n "${COPILOT_BIN:-}" && -x "${COPILOT_BIN:-}" ]]; then
    candidate="$COPILOT_BIN"
  elif current_path="$(command -v copilot 2>/dev/null || true)" && [[ -n "$current_path" ]]; then
    candidate="$current_path"
  fi

  if [[ -z "$candidate" ]]; then
    shopt -s nullglob
    nvm_candidates=("$HOME"/.nvm/versions/node/*/bin/copilot)
    shopt -u nullglob

    if [[ ${#nvm_candidates[@]} -gt 0 ]]; then
      latest_nvm_path="$(printf '%s\n' "${nvm_candidates[@]}" | sort -V | tail -n 1)"
      if [[ -x "$latest_nvm_path" ]]; then
        candidate="$latest_nvm_path"
      fi
    fi
  fi

  if [[ -z "$candidate" ]]; then
    for dir in "$HOME/.local/bin" "$HOME/bin"; do
      if [[ -x "$dir/copilot" ]]; then
        candidate="$dir/copilot"
        break
      fi
    done
  fi

  printf '%s\n' "$candidate"
}

ensure_copilot_cli() {
  local candidate=""
  local copilot_dir=""

  candidate="$(resolve_copilot_cli)"
  if [[ -z "$candidate" ]]; then
    echo "copilot CLI nao encontrado no PATH nem em caminhos comuns (${HOME}/.nvm, ${HOME}/.local/bin, ${HOME}/bin)." >&2
    echo "Define COPILOT_BIN=/caminho/para/copilot se estiver instalado noutro local." >&2
    return 1
  fi

  copilot_dir="$(dirname "$candidate")"
  case ":${PATH:-}:" in
    *":$copilot_dir:"*) ;;
    *)
      export PATH="$copilot_dir${PATH:+:$PATH}"
      ;;
  esac

  if [[ ! -x "$copilot_dir/node" ]] && ! command -v node >/dev/null 2>&1; then
    echo "node nao encontrado ao lado de $candidate nem no PATH." >&2
    return 1
  fi

  export COPILOT_BIN="$candidate"
}

run_copilot() {
  ensure_copilot_cli || return 1
  "$COPILOT_BIN" "$@"
}
