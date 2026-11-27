#!/usr/bin/env bash
# Run on the NEW system, inside your Cinnamon session, from a terminal. Works on Linux Mint
# (Ubuntu based) and LMDE (Debian based); release-specific names are looked up, not assumed.
#
#   ./restore.sh --private ~/mint-private-backup-2026-11-26.tar      everything, with your private backup
#   ./restore.sh                                                     everything except private files
#   ./restore.sh --only desktop,helium                               only some steps
#   ./restore.sh --skip grub                                         all steps but some
#   ./restore.sh --with-dev                                          also build headers, pyenv, nvm, rustup...
#   ./restore.sh --list                                              show the steps
#
# Root steps run first, in one pkexec prompt. Then your user steps run. Log out and back in at the end.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$DIR")"
CFG="$DIR/config"

ROOT_STEPS="repos packages private-system system grub"
USER_STEPS="private-home shell desktop helium hardware dev"
declare -A INFO=(
    [repos]="Third-party apt repositories (Helium, VS Code, gh, Tailscale, ...)"
    [packages]="Apps from packages/apt.txt, NVIDIA driver, newer kernel if needed"
    [private-system]="From the private backup: Wi-Fi, ssh host keys, Tailscale, cloudflared, GRUB theme"
    [system]="/etc tweaks: environment, touchpad, zram, logind, sysctl, Papirus folders, zsh login shell"
    [grub]="GRUB menu: Windows (HackBGRT), Linux Mint (follows kernel updates), WBM OEM; theme; timeout"
    [private-home]="From the private backup: SSH/GPG keys, Helium profile, keyrings, themes, fonts, applets"
    [shell]="zsh + oh-my-zsh + powerlevel10k + autosuggestions, .zshrc, .p10k.zsh"
    [desktop]="Cinnamon settings, panels, applets, shortcuts, kitty, CopyQ, Nemo, themes, fonts"
    [helium]="Helium browser settings and extension list"
    [hardware]="Dell G3: fingerprint reader, G key fan boost (only if the hardware is present)"
    [dev]="Only with --with-dev: pyenv, nvm + Node, npm globals, rustup, Claude Code"
)

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; WARNINGS+=("$*"); }
WARNINGS=()

# ------------------------------------------------------------------ distro detection
detect() {
    . /etc/os-release
    if [ -n "${UBUNTU_CODENAME:-}" ]; then
        BASE=ubuntu; CODENAME=$UBUNTU_CODENAME
        UVER=$( (. /etc/upstream-release/lsb-release 2>/dev/null; echo "${DISTRIB_RELEASE:-}") )
        [ -n "$UVER" ] || UVER=$(sed -n 's/^VERSION_ID="\{0,1\}\([0-9.]*\).*/\1/p' /etc/os-release)
        OBS="xUbuntu_$UVER"
    else
        BASE=debian
        DVER=$(cut -d. -f1 /etc/debian_version)
        case "$DVER" in 12) dc=bookworm ;; 13) dc=trixie ;; 14) dc=forky ;; *) dc="" ;; esac
        CODENAME=${DEBIAN_CODENAME:-$dc}
        OBS="Debian_$DVER"
    fi
    HAS_NVIDIA=0
    lspci 2>/dev/null | grep -qiE 'vga|3d' && lspci | grep -iE 'vga|3d' | grep -qi nvidia && HAS_NVIDIA=1
}

# Read a list file: drop comments and blank lines.
list() { sed 's/#.*//; s/[[:space:]]*$//; /^$/d' "$@"; }
# Copy with @HOME@ replaced by the real home (text files) or as is (binary).
put() {   # src dst
    mkdir -p "$(dirname "$2")"
    if grep -Iq . "$1" 2>/dev/null; then sed "s|@HOME@|$HOME|g" "$1" > "$2"; else cp "$1" "$2"; fi
}

# ------------------------------------------------------------------ root steps
subst() {
    local v=$1
    v=${v//@CODENAME@/$CODENAME}; v=${v//@DISTRO@/$BASE}; v=${v//@OBS@/$OBS}
    printf '%s' "$v"
}
write_source() {   # one-line entry -> stdout; deb822 when the file is .sources ($dest)
    local line=$1 keypath=$2
    if [[ "$dest" == *.sources ]]; then
        local opts rest uri suite comps arch
        opts=$(echo "$line" | sed -n 's/^deb \[\(.*\)\].*/\1/p')
        rest=$(echo "$line" | sed 's/^deb \[[^]]*\] //')
        read -r uri suite comps <<<"$rest"
        arch=$(echo "$opts" | tr ' ' '\n' | sed -n 's/^arch=//p')
        echo "Types: deb"; echo "URIs: $uri"; echo "Suites: $suite"; echo "Components: $comps"
        [ -n "$arch" ] && echo "Architectures: $arch"
        echo "Signed-By: $keypath"
    else
        echo "$line"
    fi
}
repo_ok() {
    ! apt-get update -o Dir::Etc::sourcelist="$1" -o Dir::Etc::sourceparts=- \
        -o APT::Get::List-Cleanup=0 2>&1 | grep -qE '^(E:|Err:)|NO_PUBKEY|not signed'
}
fetch_key() {   # url dest: download, de-armor if needed
    local tmp; tmp=$(mktemp)
    curl -fsSL "$1" -o "$tmp" || { rm -f "$tmp"; return 1; }
    if grep -q 'BEGIN PGP' "$tmp"; then gpg --dearmor < "$tmp" > "$2"; else cp "$tmp" "$2"; fi
    chmod 644 "$2"; rm -f "$tmp"
}

step_repos() {
    install -d -m 755 /etc/apt/keyrings
    ADDED_PKGS=""
    while IFS='|' read -r file key keypath base line pkgs keyurl; do
        file=$(echo "$file" | xargs); key=$(echo "$key" | xargs); keypath=$(echo "$keypath" | xargs)
        base=$(echo "$base" | xargs); line=$(echo "$line" | xargs); pkgs=$(echo "$pkgs" | xargs)
        keyurl=$(echo "${keyurl:-}" | xargs)
        [ -n "$file" ] || continue
        [ "$base" = ubuntu ] && [ "$BASE" != ubuntu ] && { note "skip $file (Ubuntu only)"; continue; }
        file=$(subst "$file"); keypath=$(subst "$keypath"); keyurl=$(subst "$keyurl")
        line=${line//@KEY@/$keypath}; line=$(subst "$line")
        install -m 644 "$DIR/packages/keyrings/$key" "$keypath"
        dest="/etc/apt/sources.list.d/$file"
        write_source "$line" "$keypath" > "$dest"
        # Keep the repo only if apt can read it on this release; refresh a rotated key once.
        if ! repo_ok "$dest" && [ -n "$keyurl" ] && fetch_key "$keyurl" "$keypath"; then
            note "downloaded a newer signing key for $file"
        fi
        if repo_ok "$dest"; then
            note "added $file"
            ADDED_PKGS="$ADDED_PKGS $pkgs"
        else
            rm -f "$dest"
            warn "Repository $file doesn't work on $NAME ($CODENAME); skipped. Packages: $pkgs"
        fi
    done < <(list "$DIR/packages/repos.conf")
    echo "$ADDED_PKGS" > /run/clean-install-repo-pkgs
}

step_packages() {
    dpkg --add-architecture i386
    apt-get update -q >/dev/null 2>&1 || apt-get update
    wanted=$(list "$DIR/packages/apt.txt")
    [ "$WITH_DEV" = 1 ] && wanted="$wanted $(list "$DIR/packages/apt-dev.txt")"
    [ -f /run/clean-install-repo-pkgs ] && wanted="$wanted $(cat /run/clean-install-repo-pkgs)"
    [ "$BASE" = debian ] && wanted="$wanted default-mysql-server"
    avail=(); missing=()
    for p in $wanted; do
        if apt-cache policy "$p" 2>/dev/null | grep -q 'Candidate: [^(]'; then avail+=("$p"); else missing+=("$p"); fi
    done
    say "Installing ${#avail[@]} packages"
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${avail[@]}"; then
        warn "Bulk install failed; installing one by one"
        for p in "${avail[@]}"; do
            DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" >/dev/null 2>&1 || missing+=("$p (install failed)")
        done
    fi
    [ ${#missing[@]} -gt 0 ] && warn "Not available on this release: ${missing[*]}"

    # NVIDIA driver.
    if [ "$HAS_NVIDIA" = 1 ] && ! dpkg -l 'nvidia-driver*' 2>/dev/null | grep -q '^ii'; then
        say "Installing the NVIDIA driver"
        if [ "$BASE" = ubuntu ] && command -v ubuntu-drivers >/dev/null; then
            ubuntu-drivers install || warn "ubuntu-drivers failed; use Driver Manager"
        else
            DEBIAN_FRONTEND=noninteractive apt-get install -y nvidia-driver firmware-misc-nonfree \
                || warn "NVIDIA driver not installed (enable contrib/non-free, or use Driver Manager)"
        fi
    fi

    # G key fan boost needs kernel 6.15+. On Ubuntu-based Mint the HWE kernel is newer.
    kver=$(uname -r | awk -F. '{printf "%d%03d", $1, $2}')
    if [ "$kver" -lt 6015 ] && [ "$BASE" = ubuntu ] && [ -n "$UVER" ]; then
        if apt-cache policy "linux-generic-hwe-$UVER" | grep -q 'Candidate: [^(]'; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y "linux-generic-hwe-$UVER" \
                && note "Installed the HWE kernel (boot into it after the restore)"
        fi
    fi
}

step_private_system() {
    [ -n "$PRIV_DIR" ] && [ -f "$PRIV_DIR/system.tar.gz" ] || { note "no private backup given; skipped"; return; }
    tmp=$(mktemp -d)
    tar -C "$tmp" -xzf "$PRIV_DIR/system.tar.gz"
    if [ -d "$tmp/etc/NetworkManager/system-connections" ]; then
        cp -a "$tmp/etc/NetworkManager/system-connections/." /etc/NetworkManager/system-connections/
        chmod 600 /etc/NetworkManager/system-connections/* 2>/dev/null
        nmcli connection reload 2>/dev/null; note "Wi-Fi and network connections restored"
    fi
    if ls "$tmp"/etc/ssh/ssh_host_* >/dev/null 2>&1; then
        cp -a "$tmp"/etc/ssh/ssh_host_* /etc/ssh/
        systemctl try-restart ssh 2>/dev/null; note "ssh host keys restored (no 'host key changed' warnings)"
    fi
    if [ -d "$tmp/var/lib/tailscale" ] && command -v tailscale >/dev/null; then
        systemctl stop tailscaled; cp -a "$tmp/var/lib/tailscale/." /var/lib/tailscale/
        systemctl start tailscaled; note "Tailscale identity restored"
    fi
    if [ -f "$tmp/etc/systemd/system/cloudflared.service" ] && command -v cloudflared >/dev/null; then
        cp "$tmp/etc/systemd/system/cloudflared.service" /etc/systemd/system/
        systemctl daemon-reload; systemctl enable --now cloudflared; note "cloudflared tunnel restored"
    fi
    if [ -d "$tmp/usr/share/grub/themes" ]; then
        mkdir -p /usr/share/grub/themes; cp -a "$tmp/usr/share/grub/themes/." /usr/share/grub/themes/
        note "GRUB theme restored"
    fi
    rm -rf "$tmp"
}

step_system() {
    S="$CFG/system"
    # /etc/environment: add missing lines.
    while read -r l; do
        [ -n "$l" ] || continue
        case "$l" in NVIDIA_*|NVD_*) [ "$HAS_NVIDIA" = 1 ] || continue ;; esac
        grep -qxF "$l" /etc/environment || echo "$l" >> /etc/environment
    done < "$S/environment.add"
    # Drop-in files.
    (cd "$S" && find etc -type f) | while read -r f; do
        case "$f" in
            etc/modprobe.d/nvidia*) [ "$HAS_NVIDIA" = 1 ] || continue ;;
            etc/default/zramswap) [ -f /etc/default/zramswap ] || continue ;;
        esac
        install -D -m 644 "$S/$f" "/$f"; note "/$f"
    done
    systemctl daemon-reload
    systemctl enable disable-turbo.service 2>/dev/null && note "CPU turbo disabled at boot (thermal workaround; see README)"
    systemctl try-restart zramswap 2>/dev/null
    sysctl --system >/dev/null 2>&1
    [ "$HAS_NVIDIA" = 1 ] && { update-initramfs -u >/dev/null 2>&1 || true; }

    # Papirus yellow folders, also at the smallest Nemo zoom levels.
    if command -v papirus-folders >/dev/null; then
        for t in Papirus Papirus-Dark Papirus-Light; do
            [ -d "/usr/share/icons/$t" ] && papirus-folders -C yellow --theme "$t" >/dev/null 2>&1
        done
        P=/usr/share/icons/Papirus
        if [ -d "$P/32x32/places" ] && [ ! -d "$P/16x16/places.bak" ]; then
            cp -a "$P/16x16/places" "$P/16x16/places.bak"
            cp -r "$P/32x32/places/." "$P/16x16/places/"
            gtk-update-icon-cache -f "$P" >/dev/null 2>&1
        fi
        note "Papirus folders set to yellow"
    fi

    # Groups: serial ports (Arduino, adb), virt-manager.
    for g in dialout plugdev libvirt kvm; do
        getent group "$g" >/dev/null && usermod -aG "$g" "$TARGET_USER"
    done

    # zsh as login shell.
    if [ -x /usr/bin/zsh ] && [ "$(getent passwd "$TARGET_USER" | cut -d: -f7)" != /usr/bin/zsh ]; then
        usermod -s /usr/bin/zsh "$TARGET_USER" && note "Login shell set to zsh"
    fi
}

step_grub() {
    G="$CFG/grub"
    install -m 755 "$G/09_custom_entries" /etc/grub.d/09_custom_entries
    mkdir -p /etc/default/grub.d
    out=/etc/default/grub.d/99-clean-install.cfg
    {
        grep -v '^#' "$CFG/system/grub-defaults.cfg" | \
            if [ "$HAS_NVIDIA" = 1 ]; then cat; else sed 's/ *nvidia-drm.modeset=1//'; fi
        echo 'GRUB_DEFAULT="Linux Mint"'
        echo 'GRUB_DISABLE_OS_PROBER=true   # 09_custom_entries lists Windows itself'
        theme=$(sed -n 's/^#THEME_DIR=//p' "$CFG/system/grub-defaults.cfg")
        if [ -n "$theme" ] && [ -f "/usr/share/grub/themes/$theme/theme.txt" ]; then
            echo "GRUB_THEME=\"/usr/share/grub/themes/$theme/theme.txt\""
        elif [ -n "$theme" ]; then
            echo "# GRUB theme $theme not found (it comes from the private backup)" >&2
        fi
    } > "$out"
    # Test first; only then write the real grub.cfg.
    if grub-mkconfig -o /tmp/grub-test.cfg >/tmp/grub-test.log 2>&1 && grep -q 'menuentry "Linux Mint"' /tmp/grub-test.cfg; then
        update-grub >/dev/null 2>&1 && note "GRUB updated: $(grep -c '^menuentry' /boot/grub/grub.cfg) top entries, default \"Linux Mint\""
    else
        rm -f "$out" /etc/grub.d/09_custom_entries
        warn "GRUB test failed, left GRUB unchanged. Log: /tmp/grub-test.log"
    fi
    rm -f /tmp/grub-test.cfg
}

# ------------------------------------------------------------------ user steps
step_private_home() {
    [ -n "$PRIV_DIR" ] && [ -f "$PRIV_DIR/home.tar.gz" ] || { note "no private backup given; skipped"; return; }
    if pgrep -x helium >/dev/null || pgrep -f /opt/helium/helium >/dev/null; then
        warn "Helium is running; close it and run: ./restore.sh --only private-home --private <archive>"
        return
    fi
    tar -C "$HOME" -xzf "$PRIV_DIR/home.tar.gz"
    chmod 700 "$HOME/.ssh" "$HOME/.gnupg" 2>/dev/null
    [ -s "$PRIV_DIR/crontab.txt" ] && crontab "$PRIV_DIR/crontab.txt" && note "crontab restored"
    fc-cache -f >/dev/null 2>&1
    note "SSH/GPG keys, Helium profile, keyrings, themes, fonts and applets restored"
    note "Saved passwords (keyring) unlock with the SAME login password as the old system"
}

step_shell() {
    command -v git >/dev/null && command -v zsh >/dev/null || { warn "git/zsh missing; run the packages step first"; return; }
    Z="$HOME/.oh-my-zsh"
    [ -d "$Z" ] || git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$Z"
    C="$Z/custom"
    [ -d "$C/themes/powerlevel10k" ] || git clone -q --depth 1 https://github.com/romkatv/powerlevel10k.git "$C/themes/powerlevel10k"
    [ -d "$C/plugins/zsh-autosuggestions" ] || git clone -q --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$C/plugins/zsh-autosuggestions"
    for f in .zshrc .zshenv .p10k.zsh; do
        [ -f "$CFG/home/$f" ] || continue
        [ -f "$HOME/$f" ] && [ ! -f "$HOME/$f.pre-restore" ] && cp "$HOME/$f" "$HOME/$f.pre-restore"
        put "$CFG/home/$f" "$HOME/$f"
    done
    # Tools .zshrc loads may not be installed yet (they come with --with-dev); don't error on them.
    sed -i 's|^\. "\$HOME/\.cargo/env"|[ -f "$HOME/.cargo/env" ] \&\& . "$HOME/.cargo/env"|' "$HOME/.zshenv" 2>/dev/null
    sed -i 's|^eval "\$(pyenv init - zsh)"|command -v pyenv >/dev/null \&\& eval "$(pyenv init - zsh)"|' "$HOME/.zshrc"
    note "zsh, oh-my-zsh, powerlevel10k and zsh-autosuggestions set up"
}

install_spice() {   # type(applets|desklets) uuid
    local type=$1 uuid=$2 dest="$HOME/.local/share/cinnamon/$1"
    [ -d "/usr/share/cinnamon/$type/$uuid" ] || [ -d "$dest/$uuid" ] && return 0
    [ "$uuid" = g-mode@shantil ] && return 0          # installed by the hardware step
    local tmp; tmp=$(mktemp -d)
    if curl -fsSL -o "$tmp/s.zip" "https://cinnamon-spices.linuxmint.com/files/$type/$uuid.zip" \
            && unzip -q "$tmp/s.zip" -d "$tmp/x"; then
        mkdir -p "$dest"
        if [ -d "$tmp/x/$uuid" ]; then mv "$tmp/x/$uuid" "$dest/"; else mkdir -p "$dest/$uuid"; mv "$tmp/x"/* "$dest/$uuid/"; fi
        note "downloaded $type/$uuid"
    else
        warn "Couldn't download $uuid; install it from System Settings > ${type^}"
    fi
    rm -rf "$tmp"
}

step_desktop() {
    # Config files (shell files are handled by the shell step).
    (cd "$CFG/home" && find . -type f ! -name .zshrc ! -name .zshenv ! -name .p10k.zsh -printf '%P\n') |
        while read -r f; do put "$CFG/home/$f" "$HOME/$f"; done
    # The Fix NTFS Nemo action needs its helper script.
    [ -f "$REPO/nemo/fix_ntfs_gui.sh" ] && install -D -m 755 "$REPO/nemo/fix_ntfs_gui.sh" "$HOME/.local/bin/fix_ntfs_gui.sh"
    note "kitty, CopyQ, Touchegg, Taskscope, Nemo actions, autostart, default apps, applet settings"

    # Fonts: FiraCode Nerd Font (terminal and prompt).
    if ! fc-list | grep -qi 'FiraCode Nerd'; then
        tmp=$(mktemp -d)
        if curl -fsSL -o "$tmp/f.tar.xz" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz; then
            mkdir -p "$HOME/.local/share/fonts" && tar -C "$HOME/.local/share/fonts" -xJf "$tmp/f.tar.xz" --wildcards '*.ttf'
            fc-cache -f >/dev/null; note "FiraCode Nerd Font installed"
        else warn "Couldn't download FiraCode Nerd Font"; fi
        rm -rf "$tmp"
    fi
    # Themes: these come from the private backup (they're modified copies).
    if [ ! -d "$HOME/.themes/Windows-10-Dark" ]; then
        git clone -q --depth 1 https://github.com/B00merang-Project/Windows-10-Dark.git "$HOME/.themes/Windows-10-Dark" \
            && note "Downloaded the original Windows-10-Dark theme (re-apply your tweaks with Windows 10 Theme Tweaks)"
    fi
    [ -d "$HOME/.themes/Mint-Y-Shantil" ] || warn "Cinnamon theme Mint-Y-Shantil is missing (it's in the private backup)"
    # Repo tools.
    [ -x "$REPO/Windows 10 Theme Tweaks/install.sh" ] && "$REPO/Windows 10 Theme Tweaks/install.sh" >/dev/null && note "Windows 10 Theme Tweaks app installed"
    [ -x "$REPO/Nemo Empty Folder Icon/install.sh" ] && "$REPO/Nemo Empty Folder Icon/install.sh" >/dev/null 2>&1 && note "Nemo empty folder icon extension installed"

    # Third-party applets and desklets used on the panels.
    for u in $(grep -oE "^enabled-applets=.*" "$CFG/dconf.ini" | grep -oE "[A-Za-z0-9._-]+@[A-Za-z0-9._-]+" | sort -u); do
        install_spice applets "$u"
    done
    for u in $(grep -oE "^enabled-desklets=.*" "$CFG/dconf.ini" | grep -oE "[A-Za-z0-9._-]+@[A-Za-z0-9._-]+" | sort -u); do
        install_spice desklets "$u"
    done

    # Desktop settings last, so themes and applets they name exist.
    dconf dump / > "$HOME/.dconf-before-restore.ini"
    sed "s|@HOME@|$HOME|g" "$CFG/dconf.ini" | dconf load /
    note "Cinnamon settings loaded (old settings saved in ~/.dconf-before-restore.ini)"
}

step_helium() {
    command -v helium >/dev/null || { note "Helium not installed; skipped"; return; }
    [ -f "$CFG/helium.json" ] || return
    if pgrep -f /opt/helium/helium >/dev/null; then
        warn "Helium is running; close it and run: ./restore.sh --only helium"; return
    fi
    P="$HOME/.config/net.imput.helium/Default"
    had_ext=0; [ -d "$P/Extensions" ] && had_ext=1
    python3 -I "$DIR/lib/helium_prefs.py" apply "$P" "$CFG/helium.json" | sed 's/^/    /'
    if [ "$had_ext" = 0 ]; then
        note "Opening the extension pages in Helium; click 'Add to Chrome' on each."
        python3 -I -c 'import json,sys;[print("https://chromewebstore.google.com/detail/"+i) for i in json.load(open(sys.argv[1]))["extensions"]]' \
            "$CFG/helium.json" | xargs -r setsid helium >/dev/null 2>&1 &
    fi
}

step_hardware() {
    if lsusb 2>/dev/null | grep -qiE '27c6:(530c|533c|538c|5840)'; then
        say "Fingerprint reader found; installing the Goodix driver (asks for sudo)"
        "$REPO/Fingerprint (Goodix 53xc)/install.sh" && note "Enroll a finger: fprintd-enroll -f right-index-finger"
    fi
    if ls /sys/class/hwmon/hwmon*/fan1_boost >/dev/null 2>&1; then
        say "Dell fan boost found; installing G-Mode (asks for sudo)"
        "$REPO/G-Mode Fan Boost/install.sh"
    elif grep -qi 'G3 3590' /sys/class/dmi/id/product_name 2>/dev/null; then
        warn "G-Mode needs kernel 6.15+. Reboot into the newer kernel, then: ./restore.sh --only hardware"
    fi
}

step_dev() {
    [ "$WITH_DEV" = 1 ] || { note "skipped (add --with-dev)"; return; }
    [ -d "$HOME/.pyenv" ] || git clone -q --depth 1 https://github.com/pyenv/pyenv.git "$HOME/.pyenv"
    if [ ! -d "$HOME/.nvm" ]; then
        git clone -q https://github.com/nvm-sh/nvm.git "$HOME/.nvm"
        git -C "$HOME/.nvm" checkout -q "$(git -C "$HOME/.nvm" describe --abbrev=0 --tags)"
    fi
    export NVM_DIR="$HOME/.nvm"; set +u; . "$NVM_DIR/nvm.sh"
    nvm install --lts >/dev/null && note "Node $(node -v) via nvm"
    npm config set prefix "$HOME/.npm-global"
    list "$DIR/packages/npm-global.txt" | xargs -r npm install -g --silent && note "npm globals installed"
    command -v rustup >/dev/null || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path >/dev/null
    command -v claude >/dev/null || curl -fsSL https://claude.ai/install.sh | bash >/dev/null
    set -u
    note "pyenv, nvm, rustup and Claude Code installed"
}

# ------------------------------------------------------------------ main
# (Stop here when sourced, so the steps can be tested one at a time.)
[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0
ONLY=""; SKIP=""; PRIV=""; WITH_DEV=0; AS_ROOT=0; TARGET_USER=${USER:-}; PRIV_DIR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --only) ONLY=",$2,"; shift ;;
        --skip) SKIP=",$2,"; shift ;;
        --private) PRIV="$2"; shift ;;
        --with-dev) WITH_DEV=1 ;;
        --list) for s in $ROOT_STEPS $USER_STEPS; do printf '  %-15s %s\n' "$s" "${INFO[$s]}"; done; exit 0 ;;
        --as-root) AS_ROOT=1; TARGET_USER="$2"; PRIV_DIR="$3"; shift 2 ;;
        -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1 (see --help)"; exit 2 ;;
    esac
    shift
done
[ "$PRIV_DIR" = - ] && PRIV_DIR=""
wanted() { { [ -z "$ONLY" ] || [[ "$ONLY" == *",$1,"* ]]; } && [[ "$SKIP" != *",$1,"* ]]; }
run() { wanted "$1" || return 0; say "${INFO[$1]}"; "step_${1//-/_}"; }

detect

if [ "$AS_ROOT" = 1 ]; then
    for s in $ROOT_STEPS; do run "$s"; done
    rm -f /run/clean-install-repo-pkgs
    printf '%s\n' "${WARNINGS[@]}" > /run/clean-install-warnings 2>/dev/null
    exit 0
fi

[ "$(id -u)" = 0 ] && { echo "Run this as your user, not root. It asks for root itself."; exit 1; }
echo "Restoring onto $NAME ${VERSION:-} ($BASE $CODENAME)$( [ "$HAS_NVIDIA" = 1 ] && echo ', NVIDIA GPU')"

# Unpack the private backup once.
if [ -n "$PRIV" ]; then
    [ -f "$PRIV" ] || { echo "Private backup not found: $PRIV"; exit 1; }
    PRIV_DIR=$(mktemp -d); chmod 700 "$PRIV_DIR"; trap 'rm -rf "$PRIV_DIR"' EXIT
    case "$PRIV" in
        *.gpg) gpg -d "$PRIV" | tar -C "$PRIV_DIR" -xf - ;;
        *) tar -C "$PRIV_DIR" -xf "$PRIV" ;;
    esac || { echo "Couldn't read $PRIV"; exit 1; }
fi

need_root=0
for s in $ROOT_STEPS; do wanted "$s" && need_root=1; done
if [ "$need_root" = 1 ]; then
    say "System steps need root: authorise once with pkexec"
    args=(--as-root "$TARGET_USER" "${PRIV_DIR:--}")
    [ -n "$ONLY" ] && args+=(--only "$ONLY")
    [ -n "$SKIP" ] && args+=(--skip "$SKIP")
    [ "$WITH_DEV" = 1 ] && args+=(--with-dev)
    pkexec "$DIR/restore.sh" "${args[@]}" \
        || warn "Root steps did not finish (pkexec cancelled or a step failed)"
    if [ -f /run/clean-install-warnings ]; then
        while read -r w; do [ -n "$w" ] && WARNINGS+=("$w"); done < /run/clean-install-warnings
    fi
fi
for s in $USER_STEPS; do run "$s"; done

echo
if [ ${#WARNINGS[@]} -gt 0 ]; then
    say "Done, with notes:"; printf '  - %s\n' "${WARNINGS[@]}"
else
    say "Done."
fi
echo "    Log out and back in (or reboot) so the panels, theme, shell and GRUB changes all take effect."
