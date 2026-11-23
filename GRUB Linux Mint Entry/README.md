# GRUB "Linux Mint" Entry That Follows Kernel Updates

On some installs (for example after an Ubuntu-based setup or OEM image), the GRUB menu calls
Linux Mint **"Ubuntu"**. A common fix is to make a custom entry named "Linux Mint" in
**Grub Customizer**. The catch is that Grub Customizer copies the entry with the kernel version
written into it:

```
linux   /boot/vmlinuz-6.14.0-33-generic root=UUID=... ro quiet splash $vt_handoff
initrd  /boot/initrd.img-6.14.0-33-generic
```

From then on, new kernels install normally but are **never booted**, because the default entry
still points at the old one. `uname -r` shows the old version even though
`linux-generic-hwe` says the newest kernel is installed.

## Check if you're affected

```bash
uname -r                                   # kernel you're running
readlink /boot/vmlinuz                     # newest kernel installed
grep -nE '/boot/(vmlinuz|initrd\.img)-' /etc/grub.d/proxifiedScripts/custom
```

If the last command prints lines with a version number, your custom entry is pinned.

## The fix

Keep the "Linux Mint" name, but point the entry at the `/boot/vmlinuz` and `/boot/initrd.img`
symlinks. The kernel package scripts update them to the newest kernel on every install,
so the entry stays current with no further changes.

```bash
cd "GRUB Linux Mint Entry" && ./fix_custom_entry_kernel.sh
```

The script shows the diff and asks before changing anything. It backs up the file and runs `update-grub`.

### Manual fix
```bash
F=/etc/grub.d/proxifiedScripts/custom
sudo cp -a $F $F.bak
sudo sed -i -E -e 's#/boot/vmlinuz-[^ ]+#/boot/vmlinuz#' -e 's#/boot/initrd\.img-[^ ]+#/boot/initrd.img#' $F
sudo update-grub
```

The entry should end up like this:
```
linux   /boot/vmlinuz root=UUID=... ro quiet splash $vt_handoff
initrd  /boot/initrd.img
```

## Notes

- **Why this is safe:** only the two file paths change. The entry name, its ID, the root UUID and
  the boot options stay the same, so `GRUB_DEFAULT="Linux Mint"` in `/etc/default/grub` keeps
  working. The old kernels stay installed.
- **Falling back:** if a new kernel has problems, hold **Shift** or **Esc** at boot (needed when
  `GRUB_TIMEOUT_STYLE=hidden`) and pick an older kernel under *Advanced options*.
- **Grub Customizer:** saving again in Grub Customizer keeps the custom entry as it is.
  If you edit the "Linux Mint" entry there, don't put a versioned kernel path back in.
- **Undo:** copy the backup back over `/etc/grub.d/proxifiedScripts/custom` and run `sudo update-grub`.
- **NVIDIA:** before rebooting into a new kernel, `dkms status` should list `nvidia` as
  `installed` for that kernel version.
