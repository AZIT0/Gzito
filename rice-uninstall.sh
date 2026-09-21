#!/usr/bin/env bash
# =============================================================================
# Gzito · desinstalador: devuelve GNOME a fábrica
# -----------------------------------------------------------------------------
#   1. Resetea ajustes (atajos, temas, workspaces, fondo)
#   2. Borra las extensiones del rice
#   3. Quita dotfiles (ghostty, fastfetch, starship, nvim, gtk.css, Pills,
#      fish-starship, firefox user.js, wallpaper)
#   4. Paquetes solo-del-rice (pregunta antes)
#   5. Borra la carpeta del repo (para clonar limpio después)
#
# Uso:
#   ./rice-uninstall.sh        # luego: cerrar sesión y entrar
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

. /etc/os-release

log() { echo -e "\n== $* =="; }
is_arch()   { [[ "$ID" == "arch" || "$ID" == "cachyos" || "${ID_LIKE:-}" == *"arch"* ]]; }
is_fedora() { [[ "$ID" == "fedora" || "${ID_LIKE:-}" == *"fedora"* || "${ID_LIKE:-}" == *"rhel"* ]]; }

# Extensiones que instala el rice + algunas ya retiradas
# (se borran igual por si quedó resto de instalaciones viejas)
RICE_EXTS=(blur-my-shell@aunetx dash-to-dock@micxgx.gmail.com
  just-perfection-desktop@just-perfection caffeine@patapon.info
  appindicatorsupport@rgcjonas.gmail.com volume_scroller@francislavoie.github.io
  window-list@gnome-shell-extensions.gcampax.github.com
  workspace-indicator@gnome-shell-extensions.gcampax.github.com
  user-theme@gnome-shell-extensions.gcampax.github.com
  top-bar-organizer@julian.gse.jsts.xyz monitor@astraext.github.io)

reset_factory() {
  log "1 · Ajustes a fábrica"
  gsettings reset-recursively org.gnome.desktop.wm.keybindings 2>/dev/null || true
  gsettings reset-recursively org.gnome.shell.keybindings 2>/dev/null || true
  gsettings reset-recursively org.gnome.mutter.keybindings 2>/dev/null || true
  gsettings reset-recursively org.gnome.settings-daemon.plugins.media-keys 2>/dev/null || true
  dconf reset -f /org/gnome/shell/extensions/ 2>/dev/null || true
  gsettings reset org.gnome.mutter dynamic-workspaces 2>/dev/null || true
  gsettings reset org.gnome.mutter center-new-windows 2>/dev/null || true
  gsettings reset org.gnome.mutter overlay-key 2>/dev/null || true
  gsettings reset org.gnome.desktop.default-applications.terminal exec 2>/dev/null || true
  gsettings reset org.gnome.desktop.search-providers disabled 2>/dev/null || true
  gsettings reset org.freedesktop.Tracker3.Miner.Files index-on-battery 2>/dev/null || true
  gsettings reset org.gnome.desktop.background picture-uri 2>/dev/null || true
  gsettings reset org.gnome.desktop.background picture-uri-dark 2>/dev/null || true
  local k
  for k in num-workspaces focus-mode auto-raise button-layout; do
    gsettings reset org.gnome.desktop.wm.preferences "$k" 2>/dev/null || true
  done
  for k in gtk-theme icon-theme cursor-theme cursor-size font-name document-font-name \
    monospace-font-name color-scheme clock-show-date clock-show-weekday enable-animations; do
    gsettings reset org.gnome.desktop.interface "$k" 2>/dev/null || true
  done
  gsettings set org.gnome.shell enabled-extensions "[]" 2>/dev/null || true
}

remove_extensions() {
  log "2 · Extensiones fuera"
  local ext
  for ext in "${RICE_EXTS[@]}"; do
    rm -rf "$HOME/.local/share/gnome-shell/extensions/$ext"
  done
}

remove_dotfiles() {
  log "3 · Dotfiles fuera"
  rm -f ~/.config/ghostty/config ~/.config/fastfetch/config.jsonc ~/.config/starship.toml
  rm -f ~/.config/gtk-4.0/gtk.css ~/.config/gtk-3.0/gtk.css ~/.config/nvim/init.lua
  rm -rf ~/.local/share/themes/Pills ~/.local/share/backgrounds/river.jpg
  sed -i '/# starship prompt/d; /starship init fish | source/d' \
    ~/.config/fish/config.fish 2>/dev/null || true
  local prof
  for prof in ~/.config/mozilla/firefox/*.default-release ~/.mozilla/firefox/*.default-release; do
    [[ -d "$prof" ]] || continue
    rm -f "$prof/user.js"
    [[ -f "$prof/prefs.js.bak" ]] && cp "$prof/prefs.js.bak" "$prof/prefs.js"
  done
}

remove_packages() {
  log "4 · Paquetes (opcional)"
  local ans=""
  read -r -p "¿Desinstalar paquetes del rice? [s/N] " ans || ans=""
  [[ "$ans" == [sS]* ]] || { echo "paquetes conservados"; return 0; }
  if is_arch; then
    sudo pacman -Rns --noconfirm papirus-icon-theme materia-gtk-theme capitaine-cursors \
      inter-font ghostty fastfetch ttf-jetbrains-mono-nerd starship neovim 2>/dev/null || true
  elif is_fedora; then
    sudo dnf remove -y papirus-icon-theme materia-gtk-theme rsms-inter-fonts \
      ghostty fastfetch starship neovim 2>/dev/null || true
  fi
  [[ "${SHELL:-}" == *"fish"* ]] \
    && echo "(aviso) tu shell es fish, no lo desinstalo" \
    || { is_arch && sudo pacman -Rns --noconfirm fish 2>/dev/null || true;
         is_fedora && sudo dnf remove -y fish 2>/dev/null || true; }
  # Tweaks es app del sistema (la de Extensiones viene en gnome-shell y no sale)
  read -r -p "¿Sacar GNOME Tweaks también? [s/N] " ans2 || ans2=""
  if [[ "$ans2" == [sS]* ]]; then
    is_arch && sudo pacman -Rns --noconfirm gnome-tweaks 2>/dev/null || true
    is_fedora && sudo dnf remove -y gnome-tweaks 2>/dev/null || true
  fi
}

main() {
  reset_factory
  remove_extensions
  remove_dotfiles
  remove_packages
  echo ""
  echo "Listo. CIERRA SESIÓN y entra."
  echo "Nota: quedan Flathub, Chaotic-AUR/paru y COPRs (útiles, no molestan)."
  cd "$HOME" 2>/dev/null || true
  rm -rf "$SCRIPT_DIR"
}

main "$@"
