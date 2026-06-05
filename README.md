# Calamares Tweak Tool

A small **dev/expert** PySide6 panel for the Kiro **live ISO**. It flips the Calamares
installer's encryption + bootloader settings on the fly — edit `/etc/calamares`, then
launch the installer — so you can test config permutations without rebuilding the ISO.

It is the installer-side sibling of **ATT** (which tweaks an *installed* system); CTT
tweaks the *installer* in the live session.

## v1 scope

v1 does exactly one thing, safely: **pick the bootloader + encryption, and the tool
derives the correct LUKS generation automatically.**

- **GRUB → LUKS1** (stock GRUB can't unlock LUKS2/Argon2id)
- **systemd-boot → LUKS2** (initramfs decrypts root → LUKS2/Argon2id is safe and stronger)

You never choose the LUKS version directly, so the unbootable combo (LUKS2 on stock GRUB)
is impossible by construction. That guard is the point of v1.

### Settings it writes (`<config-dir>/modules/`)

| File | Setting | Behaviour |
|---|---|---|
| `bootloader.conf` | `efiBootLoader` | your choice: `systemd-boot` or `grub` |
| `partition.conf` | `luksGeneration` | derived from the bootloader |
| `partition.conf` | `enableLuksAutomatedPartitioning` | `true` when encryption is on |

Edits are comment-preserving single-line replacements — the heavily-commented upstream
`.conf` files are left otherwise untouched.

## Usage

```bash
calamares-tweak-tool                 # edit the real /etc/calamares (needs root to save)
sudo -E calamares-tweak-tool         # … with write access on the live ISO
calamares-tweak-tool --dev           # edit the bundled sample config (runs anywhere)
calamares-tweak-tool --config-dir /path/to/etc/calamares
```

The **Launch installer** button runs `/usr/bin/calamares_polkit -d -style kvantum` —
exactly the same command as the Kiro live launcher (`cal-kiro.desktop`).

## Status

v1 — encryption ↔ bootloader pairing. Everything else (filesystem, swap, kernel params,
timezone, shell, groups, services, btrfs, presets, …) is parked for v2.
