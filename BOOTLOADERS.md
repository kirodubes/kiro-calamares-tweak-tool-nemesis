# Bootloader dropdown — choices & study

Study behind the CTT's bootloader picker (`BOOTLOADERS` + `LUKS_FOR` in `confedit.py`,
surfaced as the radio cards in `Tweaker.qml`). Records what we ship, what we considered,
and the encryption interaction — so the next person doesn't re-investigate it.

## Decision (2026-06-09)

Bootloaders offered: **`systemd-boot, grub`**.

**`limine` was investigated and deliberately NOT added** — not because of encryption
(that's clean, see below), but because Kiro's shipped Calamares can't install it. Adding
limine is a Calamares-base change, not a CTT change. Recorded here for when/if we decide
to bring limine support into the Calamares fork.

## How a bootloader choice actually works

A filesystem is just a string Calamares hands to `mkfs`. A bootloader is different: the
CTT only writes `efiBootLoader: "<name>"` into `bootloader.conf`. For that to mean
anything, **Calamares' `bootloader` module code must know how to install that value**. So
the gate for any new bootloader is the Calamares module, not the CTT dropdown.

## What we ship

| Bootloader | `LUKS_FOR` | Notes |
|------------|-----------|-------|
| systemd-boot | luks2 | Default. Reads kernel+initramfs from the FAT ESP; initramfs unlocks LUKS2 root. Single passphrase prompt. |
| grub | luks2 | GRUB 2.14+ unlocks LUKS2/Argon2id directly (proven on real BIOS+UEFI — see `GRUB+LUKS2.md`), so the old grub→luks1 forcing is retired. |

Both map to **luks2**; the LUKS generation stays *derived from the bootloader*, never a
free picker (see `confedit.py` / project CLAUDE.md).

## Considered but excluded

### limine — investigated, blocked on the Calamares base

**Why it's attractive:** modern, fast, simple config (`limine.conf`), good Snapper/snapshot
boot-entry integration, increasingly common on Arch-based distros.

**Why it's blocked:** Kiro builds Calamares from the codeberg fork
(`source=git+https://codeberg.org/erikdubois/calamares` in the PKGBUILD). That tree —
like upstream — supports `grub`, `systemd-boot`, `refind`, `sb-shim` and has **zero limine
support** (confirmed in the built module under `KIRO-PKG-BUILD-CALAMARES`). The
**CachyOS Calamares fork** (`~/Documents/cachyos-calamares`) *does* implement it:
`install_limine()`, `update_limine_config()`, `add_additional_entries_limine()`, and an
`elif efi_boot_loader == "limine"` branch in the bootloader dispatch.

So writing `efiBootLoader: "limine"` from the CTT today would hand Kiro's Calamares a value
it ignores/errors on → an unbootable install. Adding limine therefore requires, in order:

1. **Backport limine support from cachyos-calamares into the codeberg Calamares fork**
   (the bootloader module + any partition-module touch-ups). This is the real work.
2. **Ship `limine` and its support chain on the ISO** — it is *not* in
   `kiro-iso/archiso/packages.x86_64` (needs `limine` + the mkinitcpio/entry-tool hooks
   the CachyOS path expects: `/etc/default/limine`, `limine-install` / `limine bios-install`,
   `ENABLE_LIMINE_FALLBACK`, optional `limineSplashLogo`).
3. **Then** the CTT side is trivial: add `"limine"` to `BOOTLOADERS`, a `LUKS_FOR["limine"]
   = "luks2"` entry, and a third radio card in `Tweaker.qml`.

**Verdict:** hold. limine is a deliberate Calamares-fork decision; the CTT edit is the easy
10-minute follow-on once the base supports it. Not worth touching the CTT before then.

### Encryption with limine — clean, NOT the blocker

Limine has **no LUKS support of its own** — it cannot read an encrypted `/boot`. So it
follows the **systemd-boot model exactly**: kernel + initramfs live on the **unencrypted
ESP (FAT)**, and the **initramfs** unlocks the LUKS2 root from the kernel cmdline. The
CachyOS implementation wires precisely this — the crypt params (`rd.luks.uuid=…` /
`cryptdevice=UUID=…:<mapper>` + `root=/dev/mapper/<mapper>`) flow into
`/etc/default/limine`'s `KERNEL_CMDLINE`.

Consequences:
- **LUKS2/Argon2id is fine.** Limine never touches the LUKS partition, so the KDF is
  irrelevant to it — same as systemd-boot. `LUKS_FOR["limine"]` would just be `luks2`.
- **Single passphrase prompt** — nicer than the GRUB-with-encrypted-`/boot` double unlock.
- **One hard rule:** `/boot` must stay unencrypted on the ESP. That's already Kiro's ESP
  layout, so no conflict.

So encryption is a non-issue; the only thing standing between us and limine is Calamares
module support + the ISO package chain.

## Out of scope / not considered
- **refind, sb-shim** — Calamares supports them, but Kiro deliberately offers only the two
  mainstream choices; not exposed in the CTT.
