# Fingerprint Reader (Goodix 53xc)

Makes the Goodix fingerprint reader work on Linux Mint for login, the lock screen and `sudo`.
Tested on a **Dell G3 3590** (sensor `27c6:530c`) running Linux Mint 22.3, dual booted with Windows 10 and Windows 11.

The standard open-source `libfprint` has no driver for this sensor. Dell publishes a proprietary
"TOD" (Touch OEM Driver) plugin for it, `libfprint-2-tod1-goodix`, in its official Canonical OEM archive.
That package supports these USB IDs:

| USB ID      | Sensor            |
|-------------|-------------------|
| `27c6:530c` | Goodix 53xc       |
| `27c6:533c` | Goodix 53xc       |
| `27c6:538c` | Goodix 53xc       |
| `27c6:5840` | Goodix 53xc       |

Check your sensor with:
```bash
lsusb | grep -i goodix
```

## Install

```bash
cd "Fingerprint (Goodix 53xc)" && ./install.sh
```

The script:
1. Checks that you have a supported sensor.
2. Installs `fprintd`, `libpam-fprintd` and `libfprint-2-tod1`.
3. Downloads and installs `libfprint-2-tod1-goodix` 0.0.6 from `dell.archive.canonical.com`.
4. Reloads udev rules and restarts `fprintd`.
5. Turns on fingerprint authentication with `pam-auth-update --enable fprintd`.

### Manual install
```bash
sudo apt install fprintd libpam-fprintd libfprint-2-tod1
wget "http://dell.archive.canonical.com/updates/pool/public/libf/libfprint-2-tod1-goodix/libfprint-2-tod1-goodix_0.0.6-0ubuntu1~somerville1_amd64.deb"
sudo apt install ./libfprint-2-tod1-goodix_0.0.6-0ubuntu1~somerville1_amd64.deb
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo pam-auth-update --enable fprintd
```

## Enroll and test

```bash
fprintd-list $USER                         # should show "Goodix Fingerprint Sensor 53xc"
fprintd-enroll -f right-index-finger       # touch the sensor repeatedly until done
fprintd-verify                             # test
```
You can also enroll fingers from **Users and Groups** in Mint's settings.

After enabling, the login screen, lock screen and `sudo` ask for your fingerprint first.
You get one try with a 10-second timeout, and the password still works if it fails.

To turn fingerprint authentication off again:
```bash
sudo pam-auth-update --disable fprintd
```

## Dual booting with Windows

**Where your fingerprints are stored:** this sensor does *not* store fingerprints on the chip.
The 53xc driver captures the fingerprint image over an encrypted (TLS-PSK) link and runs Goodix's
matching algorithm on the computer. On Linux, the templates are saved on disk in `/var/lib/fprint/<user>/`.
Windows keeps its own copy in its Windows Hello database. Enrolling in one OS does not erase the
other OS's fingerprints, and each OS (including each Windows install) needs its own enrollment.

**What can break:** the sensor is paired with the driver through a pre-shared key (PSK) that is
stored on the sensor. When the Linux driver starts, it checks that key, and if it doesn't accept it, it
generates a new one and writes it to the sensor. The Windows driver does the same. If they disagree, the sensor may stop
responding in one OS after you use the other. If that happens:
- **Windows:** remove the fingerprint under *Settings → Accounts → Sign-in options*, reinstall the
  Goodix driver from Dell Support (or uninstall the device in Device Manager and reboot), then enroll again.
- **Linux:** `sudo systemctl restart fprintd`, then delete and re-enroll: `fprintd-delete $USER && fprintd-enroll`.

## Can the sensor just send raw images to a different, open-source driver?

It already sends images and matching already happens on the computer, so templates already live on disk.
What you can't do is talk to the sensor without Goodix's proprietary code: every image is encrypted with
the paired PSK and processed by Goodix's closed matching library. Community reverse-engineering projects
(e.g. `goodix-fp-linux-dev`) have managed this for some other Goodix chips by re-pairing or
re-flashing the sensor. That changes the PSK or firmware the Windows driver expects, so it can
break fingerprint login on Windows, and there's no supported open-source driver for `530c`.
