#!/usr/bin/env bash
#
# CLI interactive pour autoriser/automerger une gem Ruby ou un package npm
# dans la configuration Renovate de Captive.
#
# Écrit dans :
#   - preset/automergeRecommendedGems.json  (gems Ruby / manager bundler)
#   - preset/automergeRecommendedNPM.json   (packages npm)
#
# Puis valide (renovate-config-validator) et formate (npm run format).
#
set -euo pipefail

# Section : Config & UI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PRESET_DIR="${ADD_DEPENDENCY_PRESET_DIR:-$ROOT_DIR/preset}"
GEMS_FILE="$PRESET_DIR/automergeRecommendedGems.json"
NPM_FILE="$PRESET_DIR/automergeRecommendedNPM.json"

VALIDATED="non"
RESULT_FILE=""
RESULT_DETAIL=""

NPM_MINOR_DESC="Automerge des packages de confiance, sauf en majeure"
NPM_MAJOR_DESC="Automerge des packages de confiance, y compris en majeure"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_CYAN=$'\033[36m'; C_RED=$'\033[31m'; C_DIM=$'\033[2m'
else
  C_RESET=''; C_BOLD=''; C_GREEN=''; C_YELLOW=''; C_CYAN=''; C_RED=''; C_DIM=''
fi

info()    { printf '%s→ %s%s\n' "$C_YELLOW" "$1" "$C_RESET"; }
ok()      { printf '%s✓ %s%s\n' "$C_GREEN" "$1" "$C_RESET"; }
step()    { printf '%s✎ %s%s\n' "$C_CYAN" "$1" "$C_RESET"; }
err()     { printf '%s✗ %s%s\n' "$C_RED" "$1" "$C_RESET" >&2; }
ask()     { printf '%s%s%s ' "$C_CYAN$C_BOLD" "$1" "$C_RESET"; }
sep()     { printf '%s──────────────────────────────────────────────%s\n' "$C_DIM" "$C_RESET"; }
bold()    { printf '%s%s%s' "$C_BOLD" "$1" "$C_RESET"; }

if ! command -v jq >/dev/null 2>&1; then
  err "jq est requis mais introuvable. Installe-le : brew install jq"
  exit 1
fi

format_and_validate() {
  local file="$1"

  step "Formatage du fichier modifié…"
  local prettier_bin="$ROOT_DIR/node_modules/.bin/prettier"
  if [ -x "$prettier_bin" ] && "$prettier_bin" --write "$file" >/dev/null 2>&1; then
    ok "Formaté."
  elif ( cd "$ROOT_DIR" && npm run --silent format >/dev/null 2>&1 ); then
    ok "Formaté."
  else
    info "Formatage automatique indisponible — pense à lancer 'npm run format'."
  fi

  step "Validation de la config Renovate…"
  local out rc
  set +e
  out="$( cd "$ROOT_DIR" && RENOVATE_CONFIG_FILE="$file" npm exec -- renovate-config-validator 2>&1 )"
  rc=$?
  set -e
  if [ "$rc" -eq 0 ]; then
    ok "Config Renovate valide."
    VALIDATED="oui"
  elif printf '%s' "$out" | grep -qE 'node:internal|^[[:space:]]+at |SyntaxError|Cannot find module'; then
    info "Validateur Renovate indisponible dans cet environnement — étape ignorée."
    info "Pense à lancer 'npm run test:renovate-config' avant de committer."
  else
    err "La validation Renovate a échoué. Ton ajout est écrit et formaté, mais le fichier"
    err "contient une erreur (peut-être pré-existante) à corriger avant de committer :"
    printf '%s\n' "$out" | grep -vE 'Unknown env config|npm help npmrc' >&2
    exit 1
  fi
}

finish_animation() {
  if [ -t 1 ] && [ -z "${CI:-}" ]; then
    local frames=("📦   . . . .  🤖" "📦  . . . .   🤖" "📦 . . . .    🤖" "📦. . . .     🤖" "    🤖📦         ")
    for f in "${frames[@]}"; do
      printf '\r   %s%s%s   ' "$C_CYAN" "$f" "$C_RESET"
      sleep 0.12
    done
    printf '\r%*s\r' 40 ''
  fi
}

recap() {
  local name="$1" kind="$2" detail="$3" file="$4"
  local relfile="${file#"$ROOT_DIR"/}"
  echo
  printf '%s   ╭──────────────────────────────────────────────╮%s\n' "$C_GREEN" "$C_RESET"
  printf '%s   │  ✅  Dépendance ajoutée à la config Renovate    │%s\n' "$C_GREEN" "$C_RESET"
  printf '%s   ╰──────────────────────────────────────────────╯%s\n' "$C_GREEN" "$C_RESET"
  printf '     📦  %s (%s)\n' "$(bold "$name")" "$kind"
  [ -n "$detail" ] && printf '     🎯  %s\n' "$detail"
  printf '     📄  %s\n' "$relfile"
  if [ "${VALIDATED:-non}" = "oui" ]; then
    printf '     %s✓ validé   ✓ formaté%s\n' "$C_GREEN" "$C_RESET"
  else
    printf '     %s✓ formaté%s  %s(validation à relancer : npm run test:renovate-config)%s\n' "$C_GREEN" "$C_RESET" "$C_DIM" "$C_RESET"
  fi
  printf '     👉  pense à committer %s(gitmoji + français)%s\n' "$C_DIM" "$C_RESET"
  echo
}

nothing_to_do() {
  echo
  ok "$1"
  echo
  exit 0
}

apply_changes() {
  [ -n "$RESULT_FILE" ] || return 0
  format_and_validate "$RESULT_FILE"
  finish_animation
  recap "$NAME" "$KIND" "$RESULT_DETAIL" "$RESULT_FILE"
}

read_nonempty() {
  local prompt="$1" __var="$2" __val=""
  while [ -z "$__val" ]; do
    ask "$prompt"
    read -r __val
    [ -z "$__val" ] && err "Valeur vide, recommence."
  done
  printf -v "$__var" '%s' "$__val"
}

read_major() {
  local prompt="$1" __var="$2" __val=""
  while ! [[ "$__val" =~ ^[0-9]+$ ]]; do
    ask "$prompt"
    read -r __val
    [[ "$__val" =~ ^[0-9]+$ ]] || err "Entre un numéro de version majeure (ex: 7)."
  done
  printf -v "$__var" '%s' "$__val"
}

choose() {
  local __var="$1"; shift
  local prompt="$1"; shift
  local opts=("$@") i
  echo
  printf '%s%s%s\n' "$C_CYAN$C_BOLD" "$prompt" "$C_RESET"
  for i in "${!opts[@]}"; do
    printf '   %s%d%s) %s\n' "$C_BOLD" "$((i + 1))" "$C_RESET" "${opts[$i]}"
  done
  local choice=""
  while true; do
    ask "Ton choix [1-${#opts[@]}] :"
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#opts[@]}" ]; then
      printf -v "$__var" '%s' "${opts[$((choice - 1))]}"
      return 0
    fi
    err "Choix invalide."
  done
}

# Section : JSON primitives

jq_write() {
  local file="$1"; shift
  local filter="$1"; shift
  local tmp="$file.tmp.$$"
  jq --indent 2 "$@" "$filter" "$file" > "$tmp" && command mv -f "$tmp" "$file"
}

is_in_trust_list() {
  local file="$1" desc="$2" name="$3"
  jq -e --arg desc "$desc" --arg name "$name" '
    [.packageRules[] | select(.description == $desc) | .matchPackageNames[]?] | index($name) != null
  ' "$file" >/dev/null 2>&1
}

add_to_named_rule() {
  local file="$1" desc="$2" name="$3"
  jq_write "$file" '
    (.packageRules[] | select(.description == $desc).matchPackageNames)
    |= (if index($name) then . else . + [$name] end)
  ' --arg desc "$desc" --arg name "$name"
}

is_minor_excluded() {
  local file="$1" name="$2"
  jq -e --arg excl "!$name" '
    [.packageRules[0].matchPackageNames[]?] | index($excl) != null
  ' "$file" >/dev/null 2>&1
}

remove_minor_exclusion() {
  local file="$1" name="$2"
  jq_write "$file" '
    .packageRules[0].matchPackageNames |= map(select(. != $excl))
  ' --arg excl "!$name"
}

has_major_all_rule() {
  local file="$1" name="$2"
  jq -e --arg name "$name" '
    [.packageRules[] | select(.matchUpdateTypes == ["major"]) | .matchPackageNames[]?] | index($name) != null
  ' "$file" >/dev/null 2>&1
}

add_major_all_rule() {
  local file="$1" manager="$2" name="$3"
  jq_write "$file" '
    .packageRules += [{
      description: ("Automerge " + $name + " en major (toutes versions)"),
      matchManagers: [$manager],
      matchPackageNames: [$name],
      matchUpdateTypes: ["major"],
      automerge: true
    }]
  ' --arg name "$name" --arg manager "$manager"
}

add_targeted_major_rule() {
  local file="$1" manager="$2" name="$3" cur="$4" target="$5"
  local next=$((target + 1))
  jq_write "$file" '
    .packageRules += [{
      description: ("Automerge " + $name + " en major pour " + $cur + ".x → " + $target + ".x uniquement"),
      matchManagers: [$manager],
      matchPackageNames: [$name],
      matchCurrentVersion: ("/^" + $cur + "\\./"),
      allowedVersions: (">=" + $target + ".0.0 <" + $next + ".0.0"),
      automerge: true
    }]
  ' --arg name "$name" --arg manager "$manager" --arg cur "$cur" --arg target "$target" --arg next "$next"
}

# Section : Handlers métier

handle_gem_patch() {
  nothing_to_do "$(bold "$NAME") est déjà couvert par défaut en patch (toutes les gems bundler). Rien à faire 🎉"
}

handle_gem_minor() {
  if ! is_minor_excluded "$GEMS_FILE" "$NAME"; then
    nothing_to_do "$(bold "$NAME") est déjà couvert par défaut en minor (wildcard bundler). Rien à faire 🎉"
  fi

  info "$(bold "$NAME") est actuellement EXCLU du wildcard d'automerge minor."
  choose UNEXCLUDE "Veux-tu retirer cette exclusion (réautoriser l'automerge minor) ?" "oui" "non"
  if [ "$UNEXCLUDE" != "oui" ]; then
    nothing_to_do "Rien de modifié."
  fi

  step "Je retire l'exclusion !$NAME du wildcard…"
  remove_minor_exclusion "$GEMS_FILE" "$NAME"
  RESULT_FILE="$GEMS_FILE"
  RESULT_DETAIL="exclusion minor retirée"
}

handle_gem_major() {
  local cur target
  choose SCOPE "Pour les majors de $(printf '%s' "$NAME"), on accepte…" "tous les majors" "uniquement une montée ciblée (ex: 7.x → 8.x)"

  if [[ "$SCOPE" == tous* ]]; then
    if has_major_all_rule "$GEMS_FILE" "$NAME"; then
      nothing_to_do "$(bold "$NAME") a déjà une règle d'automerge major (tous). Rien à faire."
    fi
    info "On autorisera l'automerge de TOUS les majors de $(bold "$NAME")."
    step "J'ajoute la règle dans preset/automergeRecommendedGems.json…"
    add_major_all_rule "$GEMS_FILE" "bundler" "$NAME"
    RESULT_DETAIL="major : toutes versions"
  else
    read_major "Version majeure ACTUELLE (ex: 7) :" cur
    read_major "Version majeure CIBLE (ex: 8) :" target
    info "On limitera l'automerge à la montée $(bold "${cur}.x → ${target}.x") uniquement ; le reste restera en review manuelle."
    step "J'ajoute la règle ciblée dans preset/automergeRecommendedGems.json…"
    add_targeted_major_rule "$GEMS_FILE" "bundler" "$NAME" "$cur" "$target"
    RESULT_DETAIL="major ciblé : ${cur}.x → ${target}.x"
  fi

  RESULT_FILE="$GEMS_FILE"
}

handle_npm_patch() {
  nothing_to_do "$(bold "$NAME") est déjà couvert : tous les patches npm sont automergés globalement. Rien à faire 🎉"
}

handle_npm_minor() {
  if is_in_trust_list "$NPM_FILE" "$NPM_MINOR_DESC" "$NAME" \
    || is_in_trust_list "$NPM_FILE" "$NPM_MAJOR_DESC" "$NAME"; then
    nothing_to_do "$(bold "$NAME") est déjà dans la liste de confiance (minor déjà couvert). Rien à faire."
  fi

  info "J'ajoute $(bold "$NAME") aux packages de confiance automergés en minor/patch (pas en major)."
  step "Écriture dans preset/automergeRecommendedNPM.json…"
  add_to_named_rule "$NPM_FILE" "$NPM_MINOR_DESC" "$NAME"
  RESULT_FILE="$NPM_FILE"
  RESULT_DETAIL="minor/patch automerge"
}

handle_npm_major() {
  local cur target
  choose SCOPE "Pour les majors de $(printf '%s' "$NAME"), on accepte…" "tous les majors" "uniquement une montée ciblée (ex: 4.x → 5.x)"

  if [[ "$SCOPE" == tous* ]]; then
    if is_in_trust_list "$NPM_FILE" "$NPM_MAJOR_DESC" "$NAME"; then
      nothing_to_do "$(bold "$NAME") est déjà automergé en major (tous). Rien à faire."
    fi
    info "On autorisera l'automerge de TOUS les majors de $(bold "$NAME")."
    step "Écriture dans preset/automergeRecommendedNPM.json…"
    add_to_named_rule "$NPM_FILE" "$NPM_MAJOR_DESC" "$NAME"
    RESULT_DETAIL="major : toutes versions"
  else
    read_major "Version majeure ACTUELLE (ex: 4) :" cur
    read_major "Version majeure CIBLE (ex: 5) :" target
    info "On limitera l'automerge à la montée $(bold "${cur}.x → ${target}.x") uniquement ; le reste restera en review manuelle."
    step "J'ajoute la règle ciblée dans preset/automergeRecommendedNPM.json…"
    add_targeted_major_rule "$NPM_FILE" "npm" "$NAME" "$cur" "$target"
    RESULT_DETAIL="major ciblé : ${cur}.x → ${target}.x"
  fi

  RESULT_FILE="$NPM_FILE"
}

# Section : Main

sep
printf '%s  Renovate — ajout d'\''une dépendance%s\n' "$C_BOLD" "$C_RESET"
printf '%s  Autorise/automerge une gem Ruby ou un package npm.%s\n' "$C_DIM" "$C_RESET"
sep

choose TYPE "De quel type de dépendance s'agit-il ?" "gem (Ruby / bundler)" "package npm"

if [[ "$TYPE" == gem* ]]; then
  KIND="gem"
  info "OK, gem Ruby. Rappel : les patches & minors sont DÉJÀ automergés par défaut chez nous (wildcard bundler)."
else
  KIND="npm"
  info "OK, package npm. Rappel : les patches npm sont DÉJÀ automergés globalement."
fi

echo
read_nonempty "Nom exact du package ?" NAME
info "Package : $(bold "$NAME")."

choose LEVEL "Quel niveau de mise à jour veux-tu autoriser en automerge ?" "patch" "minor" "major"
info "Niveau demandé : $(bold "$LEVEL")."

case "$KIND:$LEVEL" in
  gem:patch) handle_gem_patch ;;
  gem:minor) handle_gem_minor ;;
  gem:major) handle_gem_major ;;
  npm:patch) handle_npm_patch ;;
  npm:minor) handle_npm_minor ;;
  npm:major) handle_npm_major ;;
esac

apply_changes
