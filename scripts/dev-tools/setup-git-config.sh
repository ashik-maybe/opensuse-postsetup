#!/usr/bin/env bash
# setup-git-config.sh — Install Git, configure user/aliases, generate SSH key (openSUSE).
#
# Usage:
#   ./setup-git-config.sh [--name "Full Name"] [--email "a@b.c"] [--dry-run] [--yes] [--help]
#
# Exit codes: 0 ok · 1 error · 2 aborted
# Idempotent: existing config and keys are skipped, never overwritten.
# Standalone: installs Git itself when missing, needs no other script first.
# === MODULES: config / helpers / guards / steps / main (all in this file) ===

set -euo pipefail
IFS=$'\n\t'

readonly SSH_KEY="$HOME/.ssh/id_ed25519"

NAME=""
EMAIL=""
DRY_RUN=false
ASSUME_YES=false

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
die()  { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

run() {
    local IFS=' '
    log "→ $*"
    if $DRY_RUN; then return 0; fi
    "$@"
}

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
    echo ""
    echo "Options:"
    echo "  --name \"Full Name\"   Set git user.name"
    echo "  --email \"a@b.c\"        Set git user.email"
    echo "  --dry-run              Print steps without changing anything"
    echo "  --yes, -y              Skip confirmation prompts"
    echo "  --help, -h             Show this help"
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)  NAME="${2:-}"; shift ;;
            --email) EMAIL="${2:-}"; shift ;;
            --dry-run) DRY_RUN=true ;;
            --yes|-y)  ASSUME_YES=true ;;
            --help|-h) usage ;;
            *) die "Unknown argument: $1 (try --help)" ;;
        esac
        shift
    done
}

confirm() {
    local prompt="$1"
    if $ASSUME_YES || $DRY_RUN; then return 0; fi
    local reply
    read -rp "$prompt (y/N): " -n 1 reply || true
    echo ""
    [[ "$reply" =~ ^[Yy]$ ]]
}

# === MODULE: step_git v1 ===
step_git() {
    log "Checking Git..."
    if command -v git >/dev/null; then
        ok "Git already installed: $(git --version)"
    else
        run sudo zypper --non-interactive install --no-recommends git
        ok "Git install requested"
    fi
}
# === END MODULE: step_git ===

# === MODULE: step_user v1 ===
step_user() {
    log "Setting up Git user info..."
    if [[ -n "$NAME" ]]; then
        run git config --global user.name "$NAME"
        ok "user.name set"
    elif git config --global user.name &>/dev/null; then
        warn "user.name already set: $(git config --global user.name)"
    else
        if confirm "Set user.name now"; then
            local name=""
            if $DRY_RUN; then run git config --global user.name "(dry-run name)"
            else
                read -rp "Enter your full name: " name
                run git config --global user.name "$name"
                ok "user.name set"
            fi
        fi
    fi
    if [[ -n "$EMAIL" ]]; then
        run git config --global user.email "$EMAIL"
        ok "user.email set"
    elif git config --global user.email &>/dev/null; then
        warn "user.email already set: $(git config --global user.email)"
    else
        if confirm "Set user.email now"; then
            local email=""
            if $DRY_RUN; then run git config --global user.email "(dry-run email)"
            else
                read -rp "Enter your email: " email
                run git config --global user.email "$email"
                ok "user.email set"
            fi
        fi
    fi
}
# === END MODULE: step_user ===

# === MODULE: step_defaults v1 ===
step_defaults() {
    log "Setting defaults and aliases..."
    run git config --global init.defaultBranch main
    run git config --global alias.st status
    run git config --global alias.co checkout
    run git config --global alias.br branch
    run git config --global alias.ci commit
    run git config --global alias.lg "log --oneline --graph --all"
    run git config --global alias.last "log -1 HEAD"
    run git config --global alias.unstage "reset HEAD --"
    run git config --global alias.amend "commit --amend --no-edit"
    if command -v codium >/dev/null; then
        run git config --global core.editor "codium --wait"
    elif command -v code >/dev/null; then
        run git config --global core.editor "code --wait"
    elif command -v vim >/dev/null; then
        run git config --global core.editor "vim"
    else
        run git config --global core.editor "nano"
    fi
    ok "Defaults and aliases set"
}
# === END MODULE: step_defaults ===

# === MODULE: step_ssh v1 ===
step_ssh() {
    log "Setting up SSH key..."
    if [[ -f "$SSH_KEY" ]]; then
        warn "SSH key already exists: $SSH_KEY"
    elif confirm "Generate new SSH key"; then
        local email
        email="$(git config --global user.email 2>/dev/null || echo "")"
        [[ -n "$email" ]] || email="$(hostname)@$(hostname -d 2>/dev/null || echo local)"
        run bash -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
        run ssh-keygen -t ed25519 -C "$email" -f "$SSH_KEY" -N ""
        run bash -c "eval \"\$(ssh-agent -s)\" >/dev/null && ssh-add '$SSH_KEY' || true"
        if ! $DRY_RUN; then
            echo ""
            echo "Your public key:"
            cat "$SSH_KEY.pub"
            echo ""
            warn "Add this key to https://github.com/settings/keys and https://gitlab.com/-/profile/keys"
        fi
    else
        warn "SSH key generation skipped"
    fi
}
# === END MODULE: step_ssh ===

main() {
    parse_args "$@"
    step_git
    step_user
    step_defaults
    step_ssh
    ok "Git setup complete."
    if ! $DRY_RUN; then
        git config --global --list | grep -E 'user\.|init\.|core\.|alias\.' | sed 's/^/  • /' || true
    fi
}

main "$@"
