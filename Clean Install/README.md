# Clean Install

Move to a fresh Linux Mint install and keep your setup: apps, repositories, desktop, panels, applets,
keyboard shortcuts, kitty, zsh, Helium, GRUB menu, system tweaks, fingerprint reader and the G key.

Works for a reinstall of the **same Mint version**, **LMDE** (Debian based) or a **newer Mint**.
Names that change between releases (Ubuntu/Debian codenames, package names) are looked up on the
new system, and anything that isn't available is skipped and listed at the end, not treated as an error.

```
Old system                                   New system
──────────                                   ──────────
./backup.sh                                  git clone ... && cd "Linux_Mint_Tweaks/Clean Install"
  ├─ config/  (public, commit it)    ──────►  ./restore.sh --private /path/to/mint-private-backup-<date>.tar
  └─ ~/mint-private-backup-<date>.tar  ──USB──►
     (secrets, never commit)
```

## What carries over

| Area | What | Where it's kept |
|---|---|---|
| Apps | ~90 apt packages grouped by purpose (+22 optional build headers); 12 third-party repos (Helium, VS Code, gh, cloudflared, Tailscale, Waterfox, pgAdmin, FirefoxPWA, Google Earth, Papirus, fastfetch, nvidia-vaapi) | `packages/` |
| Desktop | Cinnamon theme, icons, cursor, fonts, panels and their applets, applet settings, desklets, hot corners, gestures, keyboard shortcuts (incl. G key, Ctrl+Shift+Esc Taskscope, Super+V CopyQ), notifications, power/lid settings, Nemo preferences and actions | `config/dconf.ini`, `config/home/.config/cinnamon/spices/` |
| Terminal | kitty config, zsh + oh-my-zsh + powerlevel10k + autosuggestions, `.zshrc`, `.p10k.zsh`, FiraCode Nerd Font | `config/home/` |
| Apps' settings | CopyQ, Touchégg, Taskscope, default apps, autostart entries, Nemo bookmarks, monitor layout | `config/home/` |
| Helium | Layout, toolbar, home button, side panel, session restore, NTP shortcuts, extension shortcuts and the extension list | `config/helium.json` |
| Helium (full) | Bookmarks, history, logins, passwords, cookies, extensions and their data | private archive |
| GRUB | Windows Boot Manager (via HackBGRT) → **Linux Mint** (always the newest kernel) → WBM OEM, hidden menu, 10 s timeout, Intervals-window theme, `nvidia-drm.modeset=1` | `config/grub/`, `config/system/grub-defaults.cfg` |
| System | `/etc/environment` (VA-API, Firefox XInput2), libinput touchpad with tap, zram (zstd, 50%), lid/idle never sleeps, ping without root, NVIDIA modeset/suspend options, turbo off at boot, Papirus yellow folders, zsh login shell | `config/system/` |
| Hardware | Goodix fingerprint driver, G-Mode fan boost + applet (only installed if the hardware is there) | the repo's own folders |
| Secrets | SSH/GPG keys, git credentials, gh login, keyrings, KeePassXC, Wi-Fi passwords, Tailscale identity, cloudflared tunnel, ssh host keys, DuckDNS cron | private archive |
| Looks | Mint-Y-Shantil and patched Windows-10-Dark themes, fonts (Aptos, MS core), wallpapers, GRUB theme | private archive |

Not carried over on purpose: window sizes, recent files, editor history, night-light location,
Warpinator device ID, `dell-thermal-performance.service` (it turns the fans **off**, see
[G-Mode Fan Boost](../G-Mode%20Fan%20Boost/#warning-dont-use-the-dell-pc-performance-profile)).

## 1. Before reinstalling (old system)

```bash
cd ~/Linux_Mint_Tweaks/"Clean Install"
./backup.sh              # or ./backup.sh --encrypt to protect the archive with a passphrase
git -C .. add -A && git -C .. commit -m "Clean Install: refresh config" && git -C .. push
```

`backup.sh` asks for root once (pkexec) for Wi-Fi passwords, Tailscale and the GRUB theme.

Then copy these **off the Linux partition**. A USB drive is best. The Windows `SSD` or `OS` partition also
works, since the Mint installer doesn't touch it.

- [ ] `~/mint-private-backup-<date>.tar` (about 320 MB)
- [ ] Your own files: `Documents`, `Pictures`, `Downloads`, `Music`, `Videos`, `Games`, `Android`,
      `Arduino`, `AndroidStudioProjects` and anything else in `~` you care about. The archive has only settings.
- [ ] Local `.deb` installers you'll want again (see [Manual installs](#manual-installs)).

## 2. Installing Mint on this laptop (Dell G3 3590, one 2 TB disk)

In the installer pick **Something else** and set only these two partitions:

| Partition | Size | Set to | Format? |
|---|---|---|---|
| `nvme0n1p1` | 100 MB | EFI System Partition | **No** (it has Windows' boot files and HackBGRT) |
| `nvme0n1p6` | Linux | ext4, mount point `/` | Yes |

Bootloader: `/dev/nvme0n1`. **Leave p2–p5 alone**: p3 is Windows 11, p4 is Windows 10, and
**p5 is the raw disk of the Windows 8.1 VM** (it looks unformatted, but it isn't empty).

Use the **same user name and login password** as before. The saved passwords in the keyring
(Helium logins, Wi-Fi for your user, etc.) only unlock with the old password.

## 3. After installing (new system)

Log in to Cinnamon, open a terminal and run:

```bash
sudo apt install -y git
git clone https://github.com/Shantil-K/Linux_Mint_Tweaks ~/Linux_Mint_Tweaks
cd ~/Linux_Mint_Tweaks/"Clean Install"
./restore.sh --private /media/$USER/<usb>/mint-private-backup-<date>.tar
```

It asks for root once (pkexec) for the system steps, and `sudo` again for the fingerprint and
G-Mode installers. When it finishes, **reboot**. Then:

```bash
fprintd-enroll -f right-index-finger      # fingerprints must be enrolled again
./restore.sh --only hardware              # only if it said G-Mode needs the newer kernel
```

### Options

```
./restore.sh --list                   show the steps
./restore.sh --only desktop,helium    run some steps
./restore.sh --skip grub,hardware     run all but some
./restore.sh --with-dev               also: build headers, pyenv, nvm + Node LTS, npm globals, rustup, Claude Code
```

| Step | Root | What it does |
|---|---|---|
| `repos` | yes | Adds each third-party repo with its bundled key; keeps it only if apt can read it on this release. If a vendor replaced its key, downloads the current one and tries again. |
| `packages` | yes | Installs `packages/apt.txt` (and `apt-dev.txt` with `--with-dev`) plus the repos' packages. Installs the NVIDIA driver and, if the kernel is older than 6.15, the HWE kernel. |
| `private-system` | yes | Wi-Fi networks, ssh host keys, Tailscale login, cloudflared tunnel, GRUB theme. |
| `system` | yes | `/etc` tweaks, Papirus yellow folders, groups (dialout, plugdev, libvirt, kvm), zsh as login shell. |
| `grub` | yes | Installs the menu entries and settings, tests with `grub-mkconfig` first, and leaves GRUB unchanged if the test fails. |
| `private-home` | | SSH/GPG keys, Helium profile, keyrings, themes, fonts, applet code, launchers, crontab. Helium must be closed. |
| `shell` | | oh-my-zsh, powerlevel10k, zsh-autosuggestions, `.zshrc`, `.zshenv`, `.p10k.zsh`. |
| `desktop` | | Config files, FiraCode Nerd Font, third-party applets from cinnamon-spices, Windows 10 Theme Tweaks, Nemo empty-folder icons, then all Cinnamon settings. Your previous settings are saved to `~/.dconf-before-restore.ini`. |
| `helium` | | Applies the Helium settings. Without the private profile, opens each extension's Web Store page for you to click **Add**. |
| `hardware` | | Runs [Fingerprint](../Fingerprint%20(Goodix%2053xc)/) and [G-Mode Fan Boost](../G-Mode%20Fan%20Boost/) installers if the sensor / fan boost is present. |
| `dev` | | `--with-dev` only. |

## LMDE and newer Mint releases

- **LMDE:** PPAs are skipped (Papirus, fastfetch and nvidia-vaapi-driver come from Debian instead;
  `papirus-folders` isn't available, so folders stay the default colour). `mysql-server` becomes
  `default-mysql-server` (MariaDB). NVIDIA uses Debian's `nvidia-driver`; enable *contrib* and *non-free*
  first if it says the driver wasn't installed. The GRUB entry uses `/vmlinuz` (Debian's kernel symlink).
- **Newer Mint:** repos are written for the new codename; a repo that hasn't published for it yet is
  skipped and its packages listed. Run `./restore.sh --only repos,packages` again later to pick them up.
- **Same Mint version:** everything applies as on the old system.

The GRUB menu no longer needs Grub Customizer. `/etc/grub.d/09_custom_entries` writes the three
entries every time `update-grub` runs, finding the partitions by UUID. The stock entry ("Ubuntu" on Mint) and
"Advanced options" remain below them. Don't install Grub Customizer on top, or the entries appear twice.

## Manual installs

These weren't installed from a repository, so download them again:

| Kind | Apps |
|---|---|
| Downloaded `.deb` | AnyDesk, RustDesk, Stremio, DBeaver CE, draw.io, Heroic, HTTP Toolkit, Deskreen CE, XDM, Adobe Reader, scrcpy-gui, webOS Dev Manager, webOS Homebrew fork, ADB Device Manager, CrossMacro, Taskscope, ZapFast, ObtainIt, ArtCraft launcher, CadCraft, DeckCraft, GridCraft, MailCraft, PdfCraft, WordCraft, gphoto-storage-saver |
| pipx | gtktube (not on PyPI; install from its source folder) |
| Installer scripts / binaries | Ollama (`curl -fsSL https://ollama.com/install.sh \| sh`), Zed, Cursor agent, Antigravity CLI, Litecord |
| Big toolkits | CUDA 12.6 (local repo from NVIDIA), Android Studio, Arduino IDE 2 |
| In `~/Documents` | scrcpy, EasyOCR venv (used by the Text Extractor shortcut), Linux_Mint_Shortcuts |

Also set again by hand: Helium's search engine (Google), the [battery charge mode](../Battery%20Charge%20Limit/),
and Steam library folders.

## Notes

- **CPU turbo** is turned off at boot by `disable-turbo.service` (a thermal workaround). To turn turbo
  back on: `sudo systemctl disable --now disable-turbo.service`.
- **Privacy:** `config/` is public. It has no tokens, keys, passwords or e-mail addresses; the home folder is
  stored as `@HOME@`. Everything secret is in the private archive only. Keep that archive offline.
  If you used `--encrypt`, restore asks for the passphrase.
- **Keeping it current:** run `./backup.sh` and commit whenever you change your setup. Only `config/`
  changes. Edit `packages/apt.txt` by hand when you install or remove apps you care about.
- `restore.sh` can be run again; it skips what's already in place. Back-ups of replaced shell files are
  saved as `*.pre-restore`.
