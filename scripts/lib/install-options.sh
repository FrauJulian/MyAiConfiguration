#!/usr/bin/env bash
# shellcheck disable=SC2154

read_install_boolean() {
  local prompt=$1 default=$2 hint=y/N answer
  [ "$default" = false ] || hint=Y/n
  while :; do
    printf '%s [%s] ' "$prompt" "$hint" >&2
    IFS= read -r answer || { printf 'Input ended before install options were confirmed.\n' >&2; return 1; }
    answer=${answer%$'\r'}
    case "$answer" in
      '') printf '%s\n' "$default"; return ;;
      y|Y|yes|Yes|YES) printf 'true\n'; return ;;
      n|N|no|No|NO) printf 'false\n'; return ;;
    esac
  done
}

read_install_options() {
  update_agents=false
  flashbang=true
  semantic_retrieval=false
  local saved key value
  if [ -f "$home_path/.my-ai-configuration/selection.json" ]; then
    if saved=$(python3 "$root/scripts/lib/selection-state.py" read --home "$home_path" --manifest "$root/adapters/plugins.tsv" --format tsv --allow-legacy); then
      while IFS=$'\t' read -r key value; do
        value=${value%$'\r'}
        case "$key" in update_agents) update_agents=$value ;; flashbang) flashbang=$value ;; semantic_retrieval) semantic_retrieval=$value ;; esac
      done <<< "$saved"
    else
      printf 'WARN Saved options could not be read; confirm new options below.\n' >&2
    fi
  fi
  [ "$dry_run" = false ] || return 0
  update_agents=$(read_install_boolean "Update selected agent CLIs ($client)?" "$update_agents") || return
  flashbang=$(read_install_boolean 'Enable the Flashbang notification hook?' "$flashbang") || return
  semantic_retrieval=$(read_install_boolean 'Enable Qwen3 embedding and reranking semantic retrieval?' "$semantic_retrieval") || return
}

global_npm_package() {
  command -v npm >/dev/null 2>&1 || return 1
  npm list -g "$1" --depth=0 --json >/dev/null 2>&1
}

cli_npm_package() {
  case "$1" in
    codex) printf '@openai/codex\n' ;;
    claude) printf '@anthropic-ai/claude-code\n' ;;
  esac
}

# read_cli_reinstall_option <client> <dry_run> -- asked once per install run, never persisted;
# a dry run never prompts and never previews it.
read_cli_reinstall_option() {
  local client=$1 dry_run=$2
  if [ "$dry_run" = true ]; then printf 'false\n'; return; fi
  read_install_boolean "Uninstall $client and reinstall via npm?" false
}

invoke_cli_reinstall() {
  local client=$1 dry_run=$2 summary=${3:-false}
  local selected_client clients=() package
  case "$client" in codex|both) clients+=(codex) ;; esac
  case "$client" in claude|both) clients+=(claude) ;; esac
  for selected_client in "${clients[@]}"; do
    if [ "$selected_client" = codex ] && [ "$dry_run" = false ] && codex_process_active; then
      printf 'WARN Codex CLI reinstall skipped because codex.exe is running. Close all Codex sessions and run install again to reinstall the CLI.\n' >&2
      continue
    fi
    package=$(cli_npm_package "$selected_client")
    if global_npm_package "$package"; then
      CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1 run_plugin_command "$dry_run" npm uninstall -g "$package" </dev/null || return
    else
      printf 'WARN %s CLI was not found as a global npm package; a non-npm installation cannot be removed automatically. Installing %s via npm alongside it.\n' "$selected_client" "$package" >&2
    fi
    CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1 run_plugin_command "$dry_run" npm install -g "${package}@latest" </dev/null || return
    if [ "$summary" = true ]; then
      if [ "$dry_run" = true ]; then printf 'CLI %s reinstall: dry-run\n' "$selected_client"; else printf 'CLI %s reinstall: PASS\n' "$selected_client"; fi
    fi
  done
}

is_windows_host() {
  case "${OSTYPE:-}" in msys*|cygwin*|win32*) return 0 ;; *) return 1 ;; esac
}

codex_process_active() {
  is_windows_host || return 1
  command -v powershell.exe >/dev/null 2>&1 || return 1
  powershell.exe -NoProfile -Command "if (Get-Process -Name codex -ErrorAction SilentlyContinue) { exit 0 }; exit 1" >/dev/null 2>&1
}

global_npm_codex() {
  command -v npm >/dev/null 2>&1 || return 1
  npm list -g '@openai/codex' --depth=0 --json >/dev/null 2>&1
}

update_selected_agent_clis() {
  local selected_client clients=()
  case "$client" in codex|both) clients+=(codex) ;; esac
  case "$client" in claude|both) clients+=(claude) ;; esac
  for selected_client in "${clients[@]}"; do
    if [ "$selected_client" = codex ] && [ "$dry_run" = false ] && codex_process_active; then
      printf 'WARN Codex CLI update skipped because codex.exe is running. Close all Codex sessions and run the update again to update the CLI.\n' >&2
      continue
    fi
    if [ "$selected_client" = codex ] && global_npm_codex; then
      CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1 CI=true run_plugin_command "$dry_run" npm install -g '@openai/codex@latest' </dev/null || return
    else
      CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE=1 CI=true run_plugin_command "$dry_run" "$selected_client" update </dev/null || return
    fi
  done
}
