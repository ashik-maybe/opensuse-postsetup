#!/usr/bin/env bash
#
# setup-git-config.sh — Git Global Configuration & SSH Key Setup
# Usage: ./setup-git-config.sh

set -euo pipefail

# ── Colors
GREEN='\033[0;32m' BLUE='\033[0;34m' YELLOW='\033[0;33m' RED='\033[0;31m' CYAN='\033[0;36m' NC='\033[0m'
log()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success(){ echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

clear
echo -e "${CYAN}=================================================${NC}"
echo -e "${CYAN}        Git Global Config + SSH Setup${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# ── Install git if missing
if ! command -v git &>/dev/null; then
    log "Installing git..."
    if command -v dnf &>/dev/null; then
        sudo dnf install -y git
    elif command -v zypper &>/dev/null; then
        sudo zypper --non-interactive install --no-recommends git
    fi
    success "Git installed"
fi

# ── User info
echo ""
log "Setting up Git user info..."

if git config --global user.name &>/dev/null; then
    warn "Git user.name already set: $(git config --global user.name)"
    read -p "Change it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your full name: " GIT_NAME
        git config --global user.name "$GIT_NAME"
        success "user.name updated"
    fi
else
    read -p "Enter your full name: " GIT_NAME
    git config --global user.name "$GIT_NAME"
    success "user.name set"
fi

echo ""
if git config --global user.email &>/dev/null; then
    warn "Git user.email already set: $(git config --global user.email)"
    read -p "Change it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter your email: " GIT_EMAIL
        git config --global user.email "$GIT_EMAIL"
        success "user.email updated"
    fi
else
    read -p "Enter your email: " GIT_EMAIL
    git config --global user.email "$GIT_EMAIL"
    success "user.email set"
fi

# ── Default branch
echo ""
log "Setting default branch to 'main'..."
git config --global init.defaultBranch main
success "Default branch: main"

# ── Editor
echo ""
log "Setting default editor..."
if command -v codium &>/dev/null; then
    git config --global core.editor "codium --wait"
    success "Editor: VSCodium"
elif command -v code &>/dev/null; then
    git config --global core.editor "code --wait"
    success "Editor: VS Code"
elif command -v vim &>/dev/null; then
    git config --global core.editor "vim"
    success "Editor: vim"
else
    git config --global core.editor "nano"
    success "Editor: nano (default)"
fi

# ── Useful aliases
echo ""
log "Setting useful aliases..."
git config --global alias.st status
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.lg "log --oneline --graph --all"
git config --global alias.last "log -1 HEAD"
git config --global alias.unstage "reset HEAD --"
git config --global alias.amend "commit --amend --no-edit"
success "Aliases set: st, co, br, ci, lg, last, unstage, amend"

# ── SSH key
echo ""
log "Setting up SSH key for GitHub/GitLab..."

if [ -f ~/.ssh/id_ed25519 ]; then
    warn "SSH key already exists: ~/.ssh/id_ed25519"
else
    read -p "Generate new SSH key? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p ~/.ssh
        chmod 700 ~/.ssh
        ssh-keygen -t ed25519 -C "$(git config --global user.email)" -f ~/.ssh/id_ed25519 -N ""
        success "SSH key generated"

        # Start agent & add key
        eval "$(ssh-agent -s)" &>/dev/null
        ssh-add ~/.ssh/id_ed25519 2>/dev/null
        success "SSH key added to agent"

        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}Your public key:${NC}"
        echo ""
        cat ~/.ssh/id_ed25519.pub
        echo ""
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${YELLOW}→ Add this key to:${NC}"
        echo "  GitHub:  https://github.com/settings/keys"
        echo "  GitLab:  https://gitlab.com/-/profile/keys"
        echo ""
    fi
fi

# ── Summary
echo ""
echo -e "${CYAN}=================================================${NC}"
echo -e "${GREEN}  ✓ Git setup complete${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""
echo -e "${BLUE}Config:${NC}"
git config --global --list | grep -E 'user\.|init\.|core\.|alias\.' | sed 's/^/  • /'
echo ""
