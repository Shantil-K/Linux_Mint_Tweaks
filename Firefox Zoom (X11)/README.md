# Firefox Touchpad Zoom & Smooth Scrolling (X11)

On X11, Firefox and Gecko-based browsers (such as Waterfox, LibreWolf, Floorp, and Thunderbird) use legacy X11 pointer events by default, which disables pinch-to-zoom gestures and smooth pixel-by-pixel touchpad scrolling.

Setting the environment variable:
```bash
MOZ_USE_XINPUT2=1
```
activates the XInput 2 protocol in Mozilla GTK apps, enabling:
- **Pinch-to-zoom** gestures on precision touchpads and touchscreens
- **Smooth, kinetic pixel-scrolling** with touchpad two-finger scroll
- Native touchscreen touch-and-drag interactions

---

## Systemwide Setup (Permanent)

### Option 1: Automated Script
Run the helper script:
```bash
./enable_xinput2.sh
```

### Option 2: One-Liner Terminal Command
Add the variable to `/etc/environment` (which is loaded systemwide by PAM for all graphical sessions, desktop menus, and terminals):

```bash
grep -qxF 'MOZ_USE_XINPUT2=1' /etc/environment || echo 'MOZ_USE_XINPUT2=1' | sudo tee -a /etc/environment
```

Then log out and log back in (or restart your system) for the changes to take effect across all application launchers.

---

## Verifying the Setting

After logging back in, you can verify that the variable is active:

1. In terminal:
   ```bash
   echo $MOZ_USE_XINPUT2
   # Should output: 1
   ```
2. Or in Firefox / Waterfox:
   - Open `about:support` in the address bar.
   - Look under **Environment Variables** -> `MOZ_USE_XINPUT2` = `1`.

---

## How to Revert

If you ever want to remove this setting:
```bash
sudo sed -i '/MOZ_USE_XINPUT2=1/d' /etc/environment
rm -f ~/.config/environment.d/moz_xinput2.conf
```
