#!/usr/bin/env bash
# =============================================================================
# Gzito · instalador del rice minimalista (píldoras) para GNOME
# -----------------------------------------------------------------------------
# Qué hace:
#   1. Paquetes del sistema (Arch/CachyOS o Fedora)
#   2. Extensiones GNOME vía gext (últimas) y las activa
#   3. Limpia todos los atajos y aplica los propios construidos desde cero
#   4. Estética base (temas, fuentes, modo oscuro, workspaces, foco)
#   5. Prefs de extensiones (dock, blur, barra, monitores…)
#   6. Dotfiles (ghostty, fastfetch, starship, nvim, gtk, Pills)
#   7. Opcionales: Firefox/Zen, wallpaper, Chaotic-AUR, Flatpak
#
# Uso:
#   ./install.sh               # luego: cerrar sesión y entrar
#   ./install.sh --yes         # responde Sí a todo
#
# Estructura del repo:
#   install.sh  rice-uninstall.sh  README.md
#   config/ (ghostty, fastfetch, starship, nvim, gtk-4.0, gtk-3.0)  themes/Pills
#   wallpapers/  screenshots/
set -euo pipefail

# ./install.sh --yes responde Sí a todas las preguntas
AUTO=0
[[ "${1:-}" == "--yes" ]] && AUTO=1

# -----------------------------------------------------------------------------
# Configuración
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"

. /etc/os-release

# Comandos requeridos (falla claro si falta algo)
for _cmd in gsettings dconf curl unzip glib-compile-schemas; do
  command -v "$_cmd" >/dev/null 2>&1 \
    || { echo "Falta requerido: $_cmd"; exit 1; }
done

# Extensiones como "uuid:id_ego" (el id solo sirve para el link manual si gext falla).
# gext instala siempre la última versión de cada una.
EXTENSIONS=(
  "user-theme@gnome-shell-extensions.gcampax.github.com:19"
  "blur-my-shell@aunetx:3193"
  "dash-to-dock@micxgx.gmail.com:307"
  "just-perfection-desktop@just-perfection:3843"
  "caffeine@patapon.info:517"
  "appindicatorsupport@rgcjonas.gmail.com:6150"
  "workspace-indicator@gnome-shell-extensions.gcampax.github.com:5489"
  "top-bar-organizer@julian.gse.jsts.xyz:4356"
  "monitor@astraext.github.io:5677"
)


PKGS_ARCH=(papirus-icon-theme materia-gtk-theme capitaine-cursors inter-font
  ghostty fastfetch ttf-jetbrains-mono ttf-jetbrains-mono-nerd fish starship neovim
  firefox nautilus gnome-text-editor python3 python-pipx)

PKGS_FEDORA=(papirus-icon-theme materia-gtk-theme rsms-inter-fonts
  ghostty fastfetch jetbrains-mono-fonts jetbrains-mono-nl-fonts fish starship neovim
  firefox nautilus gnome-text-editor python3 unzip curl flatpak pipx)

CHAOTIC_KEY="3056513887B78AEB"
CHAOTIC_MIRROR="https://cdn-mirror.chaotic.cx/chaotic-aur"

# -----------------------------------------------------------------------------
# Ayudantes
# -----------------------------------------------------------------------------
log() { echo -e "\n== $* =="; }

# Pregunta S/n (por defecto Sí; sin terminal responde No)
ask() {
  [[ "$AUTO" == 1 ]] && return 0
  [[ -t 0 ]] || return 1
  local ans=""
  read -r -p "$1 [S/n] " ans || true
  [[ -z "$ans" || "$ans" == [Ss]* ]]
}

is_arch()   { [[ "$ID" == "arch" || "$ID" == "cachyos" || "${ID_LIKE:-}" == *"arch"* ]]; }
is_fedora() { [[ "$ID" == "fedora" || "${ID_LIKE:-}" == *"fedora"* || "${ID_LIKE:-}" == *"rhel"* ]]; }

# gsettings de una extensión (usa sus schemas locales, no voltea si falta)
# Uso: ext_set <uuid> <schema> <clave> <valor>
ext_set() {
  GSETTINGS_SCHEMA_DIR="$EXT_DIR/$1/schemas" gsettings set "$2" "$3" "$4" 2>/dev/null \
    || echo "(aviso) sin schema $2 ($3)"
  return 0
}

# Basename del primer directorio existente (temas/iconos/cursor)
pick_first() {
  local p
  for p in "$@"; do
    [[ -d "$p" ]] && { basename "$p"; return 0; }
  done
  return 1
}

# Vacía todas las claves de un esquema de atajos
clear_schema() {
  local schema="$1" key
  for key in $(gsettings list-keys "$schema"); do
    gsettings set "$schema" "$key" "@as []" 2>/dev/null \
      || gsettings set "$schema" "$key" "[]" 2>/dev/null || true
  done
}

# -----------------------------------------------------------------------------
# 1. Paquetes + Chaotic-AUR/paru + Flatpak
# -----------------------------------------------------------------------------
THEMES_MISSING=()

# instala un paquete mostrando el error si falla (no voltea todo)
pkg_try() {
  local mgr="$1"; shift
  if [[ "$mgr" == "pacman" ]]; then
    sudo pacman -S --noconfirm --needed "$@" 2>&1 | tail -n 2 || true
  else
    sudo dnf install -y "$@" 2>&1 | tail -n 2 || true
  fi
}

step_packages() {
  log "1 · Paquetes del sistema ($ID)"
  local p
  if is_arch; then
    for p in "${PKGS_ARCH[@]}"; do
      pacman -Q "$p" >/dev/null 2>&1 && continue
      echo "-- $p"
      pkg_try pacman "$p" || echo "(aviso) falló $p"
    done
    for p in colloid-everforest-gtk-theme-git \
      colloid-everforest-theme-git papirus-folders; do
      pacman -Q "$p" >/dev/null 2>&1 && continue
      if sudo pacman -S --noconfirm "$p" 2>/dev/null; then
        echo "-- $p OK"
      else
        echo "(aviso) $p necesita Chaotic-AUR/paru (se reintenta al final)"
        THEMES_MISSING+=("$p")
      fi
    done
  elif is_fedora; then
    sudo dnf copr enable -y scottames/ghostty 2>/dev/null || true
    local p
    for p in "${PKGS_FEDORA[@]}"; do
      rpm -q "$p" >/dev/null 2>&1 && continue
      echo "-- $p"
      pkg_try dnf "$p" || echo "(aviso) falló $p"
    done
    sudo dnf copr enable -y tcg/themes 2>/dev/null || true
    sudo dnf install -y la-capitaine-cursor-theme 2>/dev/null || true
  else
    echo "(aviso) distro no soportada: instala manual papirus, materia, inter, ghostty, fastfetch, jetbrains-mono"
  fi
}

step_aur() {
  is_arch || return 0
  log "Extra · Chaotic-AUR + ayudante AUR"
  if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf 2>/dev/null; then
    local ks ok=0
    for ks in keyserver.ubuntu.com hkp://keyserver.ubuntu.com:80 pgp.mit.edu keys.openpgp.org; do
      sudo pacman-key --recv-keys "$CHAOTIC_KEY" --keyserver "$ks" 2>/dev/null && { ok=1; break; }
    done
    [[ "$ok" == 1 ]] || echo "(aviso) keyserver sin respuesta, sigo igual"
    sudo pacman-key --lsign-key "$CHAOTIC_KEY" 2>/dev/null || true
    sudo pacman-key --populate archlinux 2>/dev/null || true
    # Sin --noconfirm: si pide importar key, responde Y
    sudo pacman -U \
      "$CHAOTIC_MIRROR/chaotic-keyring.pkg.tar.zst" \
      "$CHAOTIC_MIRROR/chaotic-mirrorlist.pkg.tar.zst"
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' \
      | sudo tee -a /etc/pacman.conf >/dev/null
  else
    echo "chaotic-aur ya configurado"
  fi
  if ! command -v paru >/dev/null 2>&1 && ! command -v yay >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm paru 2>/dev/null \
      || echo "(aviso) instala paru/yay manual para AUR"
  else
    echo "ayudante AUR OK: $(command -v paru || command -v yay)"
  fi
  if [[ "${#THEMES_MISSING[@]}" -gt 0 ]]; then
    echo "Reintentando temas: ${THEMES_MISSING[*]}"
    sudo pacman -Sy --noconfirm "${THEMES_MISSING[@]}" 2>&1 | tail -n 3 || true
  fi
}

step_flatpak() {
  log "Extra · Flatpak + Flathub"
  is_arch && sudo pacman -S --noconfirm --needed flatpak 2>/dev/null || true
  sudo flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null \
    || flatpak remote-add --user --if-not-exists flathub \
      https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true
  flatpak remotes 2>/dev/null | head -n 5 || true
  # Solo idiomas es/en (menos descarga), sin runtimes sobrantes, todo al día
  sudo flatpak config --set languages "es;en" 2>/dev/null || true
  sudo flatpak uninstall --unused -y 2>/dev/null || true
  sudo flatpak update -y 2>/dev/null || echo "(aviso) revisa flatpak manual"
}

# -----------------------------------------------------------------------------
# 3. Extensiones
# -----------------------------------------------------------------------------
install_extensions_gext() {
  export PATH="$HOME/.local/bin:$PATH"
  if ! command -v gext >/dev/null 2>&1; then
    pipx install gnome-extensions-cli --system-site-packages 2>/dev/null \
      || pip3 install --user gnome-extensions-cli 2>/dev/null \
      || { echo "(aviso) sin gext: instala manual desde https://extensions.gnome.org"; return 1; }
  fi
  local enabled="" entry uuid id tries ok
  for entry in "${EXTENSIONS[@]}"; do
    uuid="${entry%%:*}"; id="${entry##*:}"
    echo "-- $uuid"
    ok=0
    for tries in 1 2 3; do
      if [[ -d "$EXT_DIR/$uuid" ]] || gext install "$uuid" 2>&1 | tail -n 2; then
        [[ -d "$EXT_DIR/$uuid" ]] && { ok=1; break; }
      fi
      sleep 2
    done
    if [[ "$ok" == 1 ]]; then
      glib-compile-schemas "$EXT_DIR/$uuid/schemas/" 2>/dev/null || true
      enabled="${enabled:+"$enabled", }'$uuid'"
    else
      echo "(aviso) fallo $uuid, manual: https://extensions.gnome.org/extension/$id/"
    fi
  done
  [[ -n "$enabled" ]] && gsettings set org.gnome.shell enabled-extensions "[$enabled]"
}

step_extensions() {
  log "2 · Extensiones (últimas vía gext)"
  install_extensions_gext || true
}

# -----------------------------------------------------------------------------
# 4. Atajos (limpieza + propios)
# -----------------------------------------------------------------------------
step_reset_shortcuts() {
  log "3 · Limpieza base de atajos"
  gsettings reset-recursively org.gnome.settings-daemon.plugins.media-keys
  dconf reset -f /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom3/
  dconf reset -f /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom4/
  clear_schema org.gnome.desktop.wm.keybindings
  clear_schema org.gnome.shell.keybindings
  clear_schema org.gnome.mutter.keybindings
  clear_schema org.gnome.mutter.wayland.keybindings
}

mk_custom() { # n nombre comando tecla
  local base="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding"
  local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom$1/"
  gsettings set "$base:$path" name "$2"
  gsettings set "$base:$path" command "$3"
  gsettings set "$base:$path" binding "$4"
}

step_shortcuts() {
  log "4 · Atajos propios"
  local WM="org.gnome.desktop.wm.keybindings" i d D
  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings \
    "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/']"
  mk_custom 0 'Terminal'  'ghostty'              '<Super>Return'
  mk_custom 1 'Navegador' 'firefox --new-window' '<Super>w'
  mk_custom 2 'Archivos'  'nautilus --new-window' '<Super>e'

  gsettings set "$WM" close "['<Super>q', '<Alt>F4']"
  gsettings set "$WM" toggle-fullscreen "['<Super>f']"
  gsettings set "$WM" panel-run-dialog "['<Alt>F2']"
  for i in 1 2 3 4 5; do
    gsettings set "$WM" switch-to-workspace-$i "['<Super>$i']"
    gsettings set "$WM" move-to-workspace-$i "['<Super><Ctrl>$i']"
  done
  for d in left right up down; do
    D="$(tr '[:lower:]' '[:upper:]' <<< "${d:0:1}")${d:1}"
    gsettings set "$WM" switch-to-workspace-$d "['<Super>$D']"
    gsettings set "$WM" move-to-workspace-$d "['<Super><Ctrl>$D']"
  done
  gsettings set org.gnome.mutter overlay-key 'Super_L'
  gsettings set org.gnome.shell.keybindings toggle-application-view "['<Super>a']"
  gsettings reset org.gnome.shell.keybindings show-screenshot-ui
  gsettings reset org.gnome.shell.keybindings screenshot
  gsettings reset org.gnome.shell.keybindings screenshot-window
}

# -----------------------------------------------------------------------------
# 5. Estética base + prefs de extensiones
# -----------------------------------------------------------------------------
step_look() {
  log "5 · Comportamiento y estética base"
  local WM_PREFS="org.gnome.desktop.wm.preferences" IFACE="org.gnome.desktop.interface"
  gsettings set org.gnome.mutter dynamic-workspaces false
  gsettings set "$WM_PREFS" num-workspaces 5
  gsettings set org.gnome.mutter center-new-windows true
  gsettings set "$WM_PREFS" focus-mode 'sloppy'
  gsettings set "$WM_PREFS" auto-raise true
  gsettings set "$WM_PREFS" button-layout ':minimize,maximize,close'
  gsettings set "$IFACE" gtk-theme "$(pick_first \
    /usr/share/themes/Colloid-Green-Dark-Compact-Everforest \
    ~/.themes/Colloid-Green-Dark-Compact-Everforest \
    /usr/share/themes/Materia-dark-compact \
    ~/.themes/Materia-dark-compact || echo 'Materia-dark-compact')"
  gsettings set "$IFACE" icon-theme "$(pick_first \
    /usr/share/icons/Papirus-Dark ~/.icons/Papirus-Dark \
    /usr/share/icons/Colloid-Green-Everforest-Dark ~/.icons/Colloid-Green-Everforest-Dark || echo 'Papirus-Dark')"
  # Carpetas Papirus en amarillo
  if [[ "$(gsettings get "$IFACE" icon-theme)" == "'Papirus-Dark'" ]]; then
    sudo papirus-folders -C yellow --theme Papirus-Dark 2>/dev/null || true
  fi
  gsettings set "$IFACE" font-name 'Inter 10'
  gsettings set "$IFACE" monospace-font-name 'JetBrainsMono Nerd Font 10'
  gsettings set "$IFACE" cursor-theme "$(pick_first \
    /usr/share/icons/capitaine-cursors-light ~/.icons/capitaine-cursors-light \
    /usr/share/icons/capitaine-cursors ~/.icons/capitaine-cursors || echo 'Adwaita')"
  gsettings set "$IFACE" color-scheme 'prefer-dark'
  gsettings set "$IFACE" clock-show-date true
  gsettings set "$IFACE" clock-show-weekday true
  gsettings set org.gnome.desktop.default-applications.terminal exec 'ghostty'
  # Rendimiento: overview más rápido y menos indexado
  gsettings set org.gnome.desktop.interface enable-hot-corners false
  gsettings set org.gnome.desktop.search-providers disabled \
    "['org.gnome.Contacts.desktop', 'org.gnome.Calendar.desktop', 'org.gnome.Software.desktop', 'org.gnome.Characters.desktop', 'org.gnome.Clocks.desktop']"
  gsettings set org.freedesktop.Tracker3.Miner.Files index-on-battery false
}

step_extension_prefs() {
  log "6 · Prefs de extensiones"
  local BMS="org.gnome.shell.extensions.blur-my-shell" DTD="org.gnome.shell.extensions.dash-to-dock"
  local BLUR="blur-my-shell@aunetx" DOCK="dash-to-dock@micxgx.gmail.com"
  local PERF="just-perfection-desktop@just-perfection" ASTRA="monitor@astraext.github.io" i

  # Blur: panel transparente, dock con blur redondeado, sin blur en ventanas
  ext_set "$BLUR" "$BMS.panel" blur false
  ext_set "$BLUR" "$BMS.panel" override-background false
  ext_set "$BLUR" "$BMS.panel" corner-radius 12
  ext_set "$BLUR" "$BMS.panel" style-panel 1
  ext_set "$BLUR" "$BMS.dash-to-dock" blur true
  ext_set "$BLUR" "$BMS.dash-to-dock" override-background true
  ext_set "$BLUR" "$BMS.dash-to-dock" corner-radius 14
  ext_set "$BLUR" "$BMS.applications" blur false

  # Dock: abajo flotante, chico, auto-oculto, puntos, sin atajos propios
  ext_set "$DOCK" "$DTD" dock-position 'BOTTOM'
  ext_set "$DOCK" "$DTD" dash-max-icon-size 32
  ext_set "$DOCK" "$DTD" dock-fixed false
  ext_set "$DOCK" "$DTD" autohide true
  ext_set "$DOCK" "$DTD" intellihide true
  ext_set "$DOCK" "$DTD" transparency-mode 'DYNAMIC'
  ext_set "$DOCK" "$DTD" background-opacity 0.55
  ext_set "$DOCK" "$DTD" custom-theme-shrink true
  ext_set "$DOCK" "$DTD" extend-height false
  ext_set "$DOCK" "$DTD" force-straight-corner false
  ext_set "$DOCK" "$DTD" running-indicator-style 'DOTS'
  ext_set "$DOCK" "$DTD" show-show-apps-button false
  ext_set "$DOCK" "$DTD" show-trash false
  ext_set "$DOCK" "$DTD" show-mounts false
  ext_set "$DOCK" "$DTD" shortcut "@as []"
  ext_set "$DOCK" "$DTD" hotkeys-overlay false
  ext_set "$DOCK" "$DTD" hotkeys-show-dock false
  for i in 1 2 3 4 5 6 7 8 9 10; do
    ext_set "$DOCK" "$DTD" app-hotkey-$i "@as []"
    ext_set "$DOCK" "$DTD" app-ctrl-hotkey-$i "@as []"
    ext_set "$DOCK" "$DTD" app-shift-hotkey-$i "@as []"
  done

  # Barra y monitores
  ext_set "$PERF" org.gnome.shell.extensions.just-perfection activities-button false
  ext_set "$PERF" org.gnome.shell.extensions.just-perfection panel-size 30
  ext_set "user-theme@gnome-shell-extensions.gcampax.github.com" \
    org.gnome.shell.extensions.user-theme name 'Pills'
  ext_set "top-bar-organizer@julian.gse.jsts.xyz" \
    org.gnome.shell.extensions.top-bar-organizer hide "['activities']"
  ext_set "top-bar-organizer@julian.gse.jsts.xyz" \
    org.gnome.shell.extensions.top-bar-organizer left-box-order "['activities', 'workspace-indicator', 'appindicator-kstatusnotifieritem-steam', 'appindicator-kstatusnotifieritem-discord_status_icon_1', 'appindicator-kstatusnotifieritem-shelly.shellyorg.Notifications', 'appindicator-kstatusnotifieritem-Cachy-Update']"
  ext_set "top-bar-organizer@julian.gse.jsts.xyz" \
    org.gnome.shell.extensions.top-bar-organizer center-box-order "['dateMenu']"
  ext_set "top-bar-organizer@julian.gse.jsts.xyz" \
    org.gnome.shell.extensions.top-bar-organizer right-box-order "['monitor@astraext.github.io', 'screenRecording', 'screenSharing', 'dwellClick', 'a11y', 'keyboard', 'quickSettings']"
  ext_set "caffeine@patapon.info" \
    org.gnome.shell.extensions.caffeine show-indicator 'always'
  ext_set "workspace-indicator@gnome-shell-extensions.gcampax.github.com" \
    org.gnome.shell.extensions.workspace-indicator embed-previews true

  # Astra: solo iconos + porcentajes (GPU sin VRAM), sin discos
  local AM="org.gnome.shell.extensions.astra-monitor"
  ext_set "$ASTRA" "$AM" processor-header-graph false
  ext_set "$ASTRA" "$AM" processor-header-percentage true
  ext_set "$ASTRA" "$AM" processor-header-bars false
  ext_set "$ASTRA" "$AM" processor-header-icon true
  ext_set "$ASTRA" "$AM" processor-header-icon-size 12
  ext_set "$ASTRA" "$AM" memory-header-graph false
  ext_set "$ASTRA" "$AM" memory-header-bars false
  ext_set "$ASTRA" "$AM" memory-header-percentage true
  ext_set "$ASTRA" "$AM" memory-header-icon true
  ext_set "$ASTRA" "$AM" memory-header-icon-size 12
  ext_set "$ASTRA" "$AM" gpu-header-show true
  ext_set "$ASTRA" "$AM" gpu-header-activity-graph false
  ext_set "$ASTRA" "$AM" gpu-header-activity-percentage true
  ext_set "$ASTRA" "$AM" gpu-header-activity-bar false
  ext_set "$ASTRA" "$AM" gpu-header-memory-graph false
  ext_set "$ASTRA" "$AM" gpu-header-memory-percentage false
  ext_set "$ASTRA" "$AM" gpu-header-memory-bar false
  ext_set "$ASTRA" "$AM" gpu-header-icon true
  ext_set "$ASTRA" "$AM" gpu-header-icon-size 12
  ext_set "$ASTRA" "$AM" network-header-graph false
  ext_set "$ASTRA" "$AM" network-header-bars false
  ext_set "$ASTRA" "$AM" network-header-io true
  ext_set "$ASTRA" "$AM" network-header-icon true
  ext_set "$ASTRA" "$AM" network-header-icon-size 12
  ext_set "$ASTRA" "$AM" storage-header-show false
  ext_set "$ASTRA" "$AM" headers-font-size 10
}

# -----------------------------------------------------------------------------
# 6. Dotfiles + Firefox + wallpaper
# -----------------------------------------------------------------------------
# origen:destino relativos a repo y $HOME
DOTFILES=(
  "config/ghostty/config:.config/ghostty/config"
  "config/fastfetch/config.jsonc:.config/fastfetch/config.jsonc"
  "config/starship.toml:.config/starship.toml"
  "config/nvim/init.lua:.config/nvim/init.lua"
  "config/gtk-4.0/gtk.css:.config/gtk-4.0/gtk.css"
  "config/gtk-3.0/gtk.css:.config/gtk-3.0/gtk.css"
  "themes/Pills/gnome-shell/gnome-shell.css:.local/share/themes/Pills/gnome-shell/gnome-shell.css"
)

step_dotfiles() {
  log "7 · Dotfiles"
  local entry src dest
  for entry in "${DOTFILES[@]}"; do
    src="$SCRIPT_DIR/${entry%%:*}"; dest="$HOME/${entry##*:}"
    [[ -f "$src" ]] || { echo "(aviso) falta $src"; continue; }
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest" && echo "-- ${entry##*:}"
  done
  if ! grep -q "starship init fish" ~/.config/fish/config.fish 2>/dev/null; then
    mkdir -p ~/.config/fish
    printf '\n# starship prompt\nstarship init fish | source\n' >>~/.config/fish/config.fish
  fi
  # Sin Nerd Font (Fedora base), usar JetBrains Mono normal
  fc-list 2>/dev/null | grep -qi "nerd" \
    || sed -i 's/^font-family = .*/font-family = JetBrains Mono/' ~/.config/ghostty/config 2>/dev/null || true
}

step_firefox() {
  log "Extra · Firefox/Zen (Betterfox + DoH Mullvad)"
  local prof n=0
  for prof in ~/.config/mozilla/firefox/*.default-release ~/.mozilla/firefox/*.default-release ~/.zen/*.default; do
    [[ -d "$prof" ]] || continue
    cp "$prof/prefs.js" "$prof/prefs.js.bak" 2>/dev/null || true
    curl -sL -o "$prof/user.js" "https://raw.githubusercontent.com/yokoffing/Betterfox/main/user.js" || continue
    cat >> "$prof/user.js" <<'USERJS_EOF'

// Rice overrides: videollamadas + contraseñas intactas, DoH Mullvad
user_pref("media.peerconnection.enabled", true);
user_pref("signon.rememberSignons", true);
user_pref("network.trr.custom_uri", "https://doh.mullvad.net/dns-query");
user_pref("network.trr.uri", "https://doh.mullvad.net/dns-query");
user_pref("network.trr.mode", 3);
user_pref("network.proxy.socks_remote_dns", true);
USERJS_EOF
    n=$((n + 1))
    echo "  -> $prof"
  done
  [[ "$n" -gt 0 ]] && echo "user.js instalado en $n perfil(es)" || echo "(aviso) sin perfiles Firefox/Zen, omitido"
}

step_wallpaper() {
  log "Extra · Wallpaper"
  mkdir -p ~/.local/share/backgrounds
  if [[ -f "$SCRIPT_DIR/wallpapers/river.jpg" ]]; then
    cp "$SCRIPT_DIR/wallpapers/river.jpg" ~/.local/share/backgrounds/river.jpg
  else
    curl -sL -o ~/.local/share/backgrounds/river.jpg \
      "https://raw.githubusercontent.com/AZIT0/Gzito/main/wallpapers/river.jpg" || true
  fi
  if [[ -f ~/.local/share/backgrounds/river.jpg ]]; then
    gsettings set org.gnome.desktop.background picture-uri \
      "file://$HOME/.local/share/backgrounds/river.jpg"
    gsettings set org.gnome.desktop.background picture-uri-dark \
      "file://$HOME/.local/share/backgrounds/river.jpg"
  fi
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
  local START=$SECONDS
  echo "Distro detectada: $ID"
  step_packages
  step_extensions
  step_reset_shortcuts
  step_shortcuts
  step_look
  step_extension_prefs
  step_dotfiles
  ask "¿Instalar config Firefox/Zen (Betterfox)?" && step_firefox || echo "(omitido) Firefox/Zen"
  step_wallpaper
  ask "¿Configurar Chaotic-AUR + paru?" && step_aur || echo "(omitido) Chaotic-AUR"
  ask "¿Instalar Flatpak + Flathub?" && step_flatpak || echo "(omitido) Flatpak"
  echo ""
  echo "Listo en $(( (SECONDS - START) / 60 ))m$(( (SECONDS - START) % 60 ))s. CIERRA SESIÓN y entra."
}

main "$@"
