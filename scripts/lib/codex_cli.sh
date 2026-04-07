#!/usr/bin/env bash

resolve_codex_cli() {
  local candidate=""
  local current_path=""
  local latest_vscode_path=""
  local dir
  local -a vscode_candidates=()

  if [[ -n "${CODEX_BIN:-}" && -x "${CODEX_BIN:-}" ]]; then
    candidate="$CODEX_BIN"
  elif current_path="$(command -v codex 2>/dev/null || true)" && [[ -n "$current_path" ]]; then
    candidate="$current_path"
  fi

  if [[ -z "$candidate" || "$candidate" == /snap/bin/codex ]]; then
    shopt -s nullglob
    vscode_candidates=("$HOME"/.vscode-server/extensions/openai.chatgpt-*/bin/linux-x86_64/codex)
    shopt -u nullglob

    if [[ ${#vscode_candidates[@]} -gt 0 ]]; then
      latest_vscode_path="$(printf '%s\n' "${vscode_candidates[@]}" | sort -V | tail -n 1)"
      if [[ -x "$latest_vscode_path" ]]; then
        candidate="$latest_vscode_path"
      fi
    fi
  fi

  if [[ -z "$candidate" ]]; then
    for dir in /snap/bin "$HOME/.local/bin" "$HOME/bin"; do
      if [[ -x "$dir/codex" ]]; then
        candidate="$dir/codex"
        break
      fi
    done
  fi

  printf '%s\n' "$candidate"
}

ensure_codex_cli() {
  local candidate=""
  local codex_dir=""

  candidate="$(resolve_codex_cli)"
  if [[ -z "$candidate" ]]; then
    echo "codex CLI nao encontrado no PATH nem em caminhos comuns (/snap/bin, ${HOME}/.local/bin, ${HOME}/bin)." >&2
    echo "Define CODEX_BIN=/caminho/para/codex se estiver instalado noutro local." >&2
    return 1
  fi

  codex_dir="$(dirname "$candidate")"
  case ":${PATH:-}:" in
    *":$codex_dir:"*) ;;
    *)
      export PATH="$codex_dir${PATH:+:$PATH}"
      ;;
  esac

  export CODEX_BIN="$candidate"
}

resolve_codex_agent_file() {
  local repo_root="$1"
  local agent="$2"
  local candidate="$repo_root/.github/agents/${agent}.agent.md"

  if [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  echo "Agente Codex nao encontrado: $agent ($candidate)" >&2
  return 1
}

build_codex_exec_command() {
  local repo_root="$1"
  local model="$2"
  local mode="${CODEX_AUTO_MODE:-danger-full-access}"

  CODEX_EXEC_CMD=("$CODEX_BIN" exec --cd "$repo_root" --skip-git-repo-check --color never)

  case "$mode" in
    danger-full-access|dangerous|bypass|unsafe)
      CODEX_EXEC_CMD+=(--dangerously-bypass-approvals-and-sandbox)
      ;;
    full-auto)
      CODEX_EXEC_CMD+=(--full-auto)
      ;;
    workspace-write)
      CODEX_EXEC_CMD+=(--sandbox workspace-write)
      ;;
    read-only)
      CODEX_EXEC_CMD+=(--sandbox read-only)
      ;;
    *)
      echo "Valor invalido para CODEX_AUTO_MODE: $mode" >&2
      echo "Usa: danger-full-access, full-auto, workspace-write ou read-only." >&2
      return 1
      ;;
  esac

  if [[ -n "$model" ]]; then
    CODEX_EXEC_CMD+=(--model "$model")
  fi

  if [[ -n "${CODEX_PROFILE:-}" ]]; then
    CODEX_EXEC_CMD+=(--profile "$CODEX_PROFILE")
  fi

  if [[ "${CODEX_ENABLE_WEB_SEARCH:-0}" == "1" ]]; then
    CODEX_EXEC_CMD+=(--search)
  fi

  CODEX_EXEC_CMD+=(-)
}

emit_codex_agent_prompt() {
  local agent="$1"
  local agent_file="$2"
  local task_prompt="$3"

  printf '%s\n' "You are running inside Codex CLI for this repository."
  printf '%s\n' "Use the agent file below as the role instructions for this run and map its tool references to the tools available in Codex CLI."
  printf '%s\n' "Complete the task end-to-end without interactive questions unless genuinely blocked."
  printf '%s\n' "Modify files directly, keep stdout minimal, and make the final non-empty stdout line exactly the status required by the task."
  printf '\n%s\n' "===== AGENT FILE: .github/agents/${agent}.agent.md ====="
  cat "$agent_file"
  printf '\n%s\n' "===== TASK ====="
  printf '%s\n' "$task_prompt"
}

run_codex_agent() {
  local repo_root=""
  local agent=""
  local prompt=""
  local model=""
  local agent_file=""

  ensure_codex_cli || return 1

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root)
        repo_root="$2"
        shift 2
        ;;
      --agent)
        agent="$2"
        shift 2
        ;;
      --agent=*)
        agent="${1#*=}"
        shift
        ;;
      --prompt)
        prompt="$2"
        shift 2
        ;;
      --model)
        model="$2"
        shift 2
        ;;
      *)
        echo "Opcao desconhecida para run_codex_agent: $1" >&2
        return 1
        ;;
    esac
  done

  if [[ -z "$repo_root" ]]; then
    repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  fi

  if [[ -z "$agent" ]]; then
    echo "run_codex_agent requer --agent." >&2
    return 1
  fi

  if [[ -z "$prompt" ]]; then
    echo "run_codex_agent requer --prompt." >&2
    return 1
  fi

  agent_file="$(resolve_codex_agent_file "$repo_root" "$agent")" || return 1
  build_codex_exec_command "$repo_root" "$model" || return 1

  emit_codex_agent_prompt "$agent" "$agent_file" "$prompt" | "${CODEX_EXEC_CMD[@]}"
}
