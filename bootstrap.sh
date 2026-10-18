#!/usr/bin/env bash
# bootstrap.sh — LA commande pour installer, réinstaller ou réparer un Mac (Apple silicon ou Intel) :
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/MathieuValez/mac-setup/main/bootstrap.sh)"
#
# Ce script est public et ne contient rien de personnel : il pose les outils de base
# (Command Line Tools, Homebrew sur Apple silicon / MacPorts sur Intel, gh, chezmoi),
# connecte GitHub, applique les dotfiles du dépôt privé MathieuValez/dotfiles (qui demande
# le rôle et le nom du Mac la première fois), puis passe la main à install.sh de ce dépôt,
# qui fait tout le reste. Relançable à volonté : chaque étape vérifie l'état avant d'agir.

set -euo pipefail

GITHUB_USER="MathieuValez"
DOTFILES="$HOME/.local/share/chezmoi"
ARCH="$(uname -m)"

say() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()  { printf '   \033[32m✔\033[0m %s\n' "$*"; }

say "Mac $(scutil --get LocalHostName 2>/dev/null || hostname -s) — $ARCH — macOS $(sw_vers -productVersion)"

# ---------------------------------------------------------------- 1. Command Line Tools (git, compilateurs)
say "Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then ok "présents"
else
  # Déclenche l'installation via Mise à jour de logiciels, sans fenêtre à valider
  touch /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  LABEL="$(softwareupdate -l 2>/dev/null | grep -o 'Label: Command Line Tools.*' | head -1 | sed 's/^Label: //')"
  if [[ -n "$LABEL" ]]; then softwareupdate -i "$LABEL" --verbose
  else xcode-select --install 2>/dev/null || true; echo "   Valide la fenêtre d'installation ; j'attends…"; fi
  rm -f /tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
  ok "installés"
fi

# ---------------------------------------------------------------- 2. Gestionnaire de paquets
if [[ "$ARCH" == "arm64" ]]; then
  say "Homebrew (Apple silicon)"
  if [[ -x /opt/homebrew/bin/brew ]]; then ok "présent"
  else /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
  for f in gh chezmoi; do brew list --formula "$f" >/dev/null 2>&1 || brew install "$f"; done
else
  # Intel : l'installeur Homebrew refuse les Mac Intel (« only supported on Apple Silicon processors ») ;
  # MacPorts fournit des binaires à jour (chezmoi, gh, mosh, mise…) et reste maintenu pour Intel.
  say "MacPorts (Intel)"
  if [[ -x /opt/local/bin/port ]]; then ok "présent"
  else
    MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
    PKG_URL="$(curl -fsSL https://api.github.com/repos/macports/macports-base/releases/latest \
      | grep -o "https://[^\"]*MacPorts-[0-9.]*-${MAJOR}-[A-Za-z]*\.pkg" | head -1)"
    [[ -n "$PKG_URL" ]] || { echo "   Pas de paquet MacPorts pour macOS $MAJOR : https://www.macports.org/install.php"; exit 1; }
    echo "   Téléchargement de $(basename "$PKG_URL")…"
    curl -fsSL -o /tmp/MacPorts.pkg "$PKG_URL"
    sudo installer -pkg /tmp/MacPorts.pkg -target /
    rm -f /tmp/MacPorts.pkg
  fi
  export PATH="/opt/local/bin:/opt/local/sbin:$PATH"
  sudo port -q selfupdate >/dev/null 2>&1 || sudo port selfupdate
  for p in gh chezmoi; do port -q installed "$p" 2>/dev/null | grep -q active || sudo port -N install "$p"; done
fi
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------- 3. GitHub
say "GitHub (gh)"
if gh auth status >/dev/null 2>&1; then ok "connecté ($(gh api user --jq .login 2>/dev/null || echo '?'))"
else gh auth login --hostname github.com --git-protocol https --web --scopes admin:public_key; fi
gh auth setup-git >/dev/null 2>&1 || true

# ---------------------------------------------------------------- 4. Dotfiles (dépôt privé)
say "Dotfiles (chezmoi, $GITHUB_USER/dotfiles)"
if [[ -d "$DOTFILES/.git" ]]; then
  [[ -f "$HOME/.config/chezmoi/chezmoi.toml" ]] || chezmoi init      # (re)pose les questions rôle / nom si la config manque
  chezmoi update --exclude=scripts && ok "dépôt tiré et dotfiles appliqués"
else
  chezmoi init --apply --exclude=scripts "$GITHUB_USER" && ok "dépôt cloné, dotfiles appliqués"
fi

# ---------------------------------------------------------------- 5. Le reste : install.sh du dépôt privé
say "Installation / réparation (install.sh du dépôt)"
chmod +x "$DOTFILES/install.sh"
exec "$DOTFILES/install.sh"
