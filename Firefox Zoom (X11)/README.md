# Firefox Touchpad Zoom & Smooth Scrolling (X11)

On X11, pinch-to-zoom in Firefox and Gecko-based browsers (Waterfox, LibreWolf, Floorp, Thunderbird) needs two things:

1. **`MOZ_USE_XINPUT2=1`** — makes Mozilla GTK apps use the XInput 2 protocol for smooth pixel scrolling and gestures.
2. **The libinput touchpad driver** — the older **synaptics** driver cannot send pinch gestures to apps at all. On many laptops synaptics is installed and overrides libinput (`70-synaptics.conf` loads after `40-libinput.conf`), so pinch-to-zoom silently does nothing.

Together these enable:
- **Pinch-to-zoom** gestures on touchpads and touchscreens
- **Smooth, kinetic pixel-scrolling** with two-finger scroll
- Native touchscreen touch-and-drag interactions

---

## Check Which Touchpad Driver You Use

```bash
xinput list-props "$(xinput list --id-only "$(xinput list --name-only | grep -i touchpad | head -1)")" | grep -i -E 'libinput|synaptics' | head -3
```
- Lines starting with `libinput` → you're fine.
- Lines starting with `Synaptics` → you need the driver step below.

---

## Systemwide Setup (Permanent)

### Option 1: Automated Script
Does both steps (environment variable + libinput driver):
```bash
./enable_xinput2.sh
```

### Option 2: Manual Commands

**1. Environment variable** (loaded by PAM for all graphical sessions, menus and terminals):
```bash
grep -qxF 'MOZ_USE_XINPUT2=1' /etc/environment || echo 'MOZ_USE_XINPUT2=1' | sudo tee -a /etc/environment
```

**2. libinput driver** — install it and make touchpads use it instead of synaptics:
```bash
sudo apt install xserver-xorg-input-libinput
sudo mkdir -p /etc/X11/xorg.conf.d
sudo tee /etc/X11/xorg.conf.d/90-touchpad-libinput.conf >/dev/null <<'EOF'
Section "InputClass"
    Identifier "touchpad libinput override"
    MatchIsTouchpad "on"
    MatchDevicePath "/dev/input/event*"
    Driver "libinput"
    Option "Tapping" "on"
EndSection
EOF
```

Then log out and log back in (or restart). Touchpad speed/acceleration may feel slightly different under libinput; adjust it in **System Settings → Mouse and Touchpad**.

---

## Verifying the Setting

After logging back in:

1. Environment variable:
   ```bash
   echo $MOZ_USE_XINPUT2
   # Should output: 1
   ```
   Or open `about:support` in the browser → **Environment Variables** → `MOZ_USE_XINPUT2` = `1`.
2. Driver: run the check command above — it should now show `libinput` properties.
3. Pinch two fingers on the touchpad in the browser — the page should zoom.

---

## How to Revert

```bash
sudo sed -i '/MOZ_USE_XINPUT2=1/d' /etc/environment
rm -f ~/.config/environment.d/moz_xinput2.conf
sudo rm -f /etc/X11/xorg.conf.d/90-touchpad-libinput.conf
```
Then log out and back in. If the touchpad stops working after the driver change, use a mouse or a text console (Ctrl+Alt+F3) to run the last command.
