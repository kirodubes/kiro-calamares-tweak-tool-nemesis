# GRUB + LUKS2 — can stock Arch GRUB unlock LUKS2/Argon2id?

**Research date:** 2026-06-05
**Question:** Can the version of GRUB currently shipped on Arch Linux boot from / unlock
a LUKS2-encrypted partition that uses the default Argon2id key derivation function (KDF)?

## Bottom line: YES — CONFIRMED on real BIOS metal (2026-06-05)

Stock Arch GRUB can now unlock LUKS2 with Argon2id. This **reverses** the long-standing
assumption that the Kiro stable Calamares Tweak Tool is built around (grub → luks1,
because "GRUB can't decrypt LUKS2/Argon2id"). That footgun was real, but it is **fixed
upstream** as of GRUB 2.14 (January 2026) — and we have now **proven it empirically** with
a full encrypted install + reboot on real hardware (not a VM).

## Empirical confirmation — worf, 2026-06-05

Tested with this `-nemesis` tool's **Force LUKS2 on GRUB** override on **worf**, an old
real **BIOS-only / GRUB-only** machine. A full-disk-encrypted Kiro install completed, and
on reboot **GRUB presented the passphrase prompt, unlocked the volume, and booted**.

On-disk header read from the running installed system (`cryptsetup luksDump /dev/sda1`):

```
Version:    2                 ← LUKS2
PBKDF:      argon2id           ← the default KDF GRUB historically could NOT do
Time cost:  4
Memory:     820722  (~800 MiB) ← memory-hard cost; GRUB still derived the key at boot
AF hash:    sha512
Cipher:     aes-xts-plain64
```

Environment: firmware **BIOS** (no `/sys/firmware/efi`), bootloader **`grub-install (GRUB)
2:2.14-1`**, whole disk is the LUKS2 volume with `/boot` *inside* it, root mounted from
`/dev/mapper/luks-…`. So the complete chain is proven: **GRUB 2.14, legacy BIOS, unlocking
a LUKS2/Argon2id full-disk-encrypted root** — including `/boot`, with ~800 MiB Argon2
memory cost. (The earlier worry about extreme Argon2 memory exceeding what GRUB has at boot
did not materialise at default cryptsetup costs.)

### One real gotcha found during the test (not a LUKS issue)

The first attempt **crashed at `grub-install`**, not because of LUKS2, but because of
**BIOS + GPT with no `bios_grub` partition**:

```
grub-install: error: embedding is not possible, but this is required for RAID and LVM install.
```

Kiro `partition.conf` hardcodes `defaultPartitionTableType: gpt`. On a legacy-BIOS box that
fails regardless of luks1/luks2 (GRUB needs a ~1 MiB `bios_grub` partition to embed
`core.img` on GPT). Switching to **`msdos` (MBR)** fixed it — GRUB then embeds in the
post-MBR gap, no `bios_grub` partition needed. **This is a real Kiro gap for BIOS users**
and is independent of the LUKS question.

## The facts

| Fact | Value | Source |
|---|---|---|
| GRUB version in Arch `core` | **`2:2.14-1`**, updated **2026-01-16** | [archlinux.org/packages](https://archlinux.org/packages/core/x86_64/grub/) |
| LUKS2 format support | since GRUB 2.06 (partial) | — |
| LUKS2 + **PBKDF2** only | GRUB 2.12 (`grub-install` could embed a core image to unlock LUKS2, PBKDF2 KDF only) | [mdleom](https://mdleom.com/blog/2022/11/27/grub-luks2-argon2/) |
| LUKS2 + **Argon2i/Argon2id** | **added in GRUB 2.14** | [UbuntuHandbook](https://ubuntuhandbook.org/index.php/2026/01/grub-boot-loader-2-14-released-with-argon2-tpm-2-0-key-protector/) |

## The distinction that matters

"LUKS2 supported" and "LUKS2-with-Argon2id supported" are **not the same thing**, and the
gap between them was the whole problem:

- **LUKS2's default KDF is Argon2id** (memory-hard, resists hardware-accelerated attacks).
- Historically GRUB's `cryptodisk`/`luks2` module supported **only PBKDF2**. A
  default-formatted LUKS2 volume was therefore **not** unlockable by GRUB.
- The documented workarounds (pre-2.14) were:
  - format `/boot` (or root) with `cryptsetup luksFormat --pbkdf pbkdf2 ...`, or
  - `cryptsetup luksConvertKey --pbkdf pbkdf2` an existing keyslot, or
  - use LUKS1 for the GRUB-read partition, or
  - install the AUR **`grub-improved-luks2-git`** patched package (UEFI only).

GRUB **2.14** closes that gap: it now ships Argon2i/Argon2id support in the mainline
release. Strong corroboration — the maintainer of the `grub-improved-luks2-git` patch has
**switched back to stock GRUB** now that the feature is upstream
([mdleom microblog](https://mdleom.com/microblog/2026/01/07/grub-2-14rc1-supports-luks2-argon2-disk-encryption/)).

## Remaining caveats (unchanged by 2.14)

- **`GRUB_ENABLE_CRYPTODISK=y`** in `/etc/default/grub` is still required for GRUB to embed
  cryptodisk support — this is a long-standing requirement, independent of the KDF, and
  Calamares sets it automatically when encryption is enabled.
- Argon2 is memory-hard *by design*; very large `--memory` cost values configured at
  `luksFormat` time could in principle exceed what GRUB has available at boot. Default
  cryptsetup costs are fine; this only matters if someone hand-tunes an extreme cost.
- "It works" = it actually boots. Confirm empirically before relaxing any Kiro default.

## What this means for Kiro

- The stable `kiro-calamares-tweak-tool` still has `LUKS_FOR = {"grub": "luks1", ...}`.
- This `-nemesis` fork's `force_luks2` override let us write `grub` + `luks2` and run the
  full encrypted install that proved the combo boots (see above).
- **Resolved (2026-06-05):** the grub→luks1 invariant can be relaxed — Kiro can move to
  LUKS2/Argon2id under GRUB, a single stronger encryption default across both bootloaders.
  Pending decision: when to flip the stable tool's `LUKS_FOR`.
- **Separately, fix the BIOS+GPT gap:** make `defaultPartitionTableType` `msdos` for
  legacy-BIOS installs (or have automated partitioning add a `bios_grub` partition on GPT),
  otherwise BIOS users hit the `grub-install` embedding failure regardless of LUKS version.

### Verification procedure (live ISO VM)

1. Boot the `kiro-iso-next` ISO (it ships `kiro-calamares-tweak-tool-nemesis`).
2. `sudo -E calamares-tweak-tool` → bootloader **grub**, encryption **on**, flip
   **Force LUKS2 on GRUB** → **Apply**.
3. Confirm `/etc/calamares/modules/partition.conf` shows `luksGeneration: luks2`.
4. **Launch installer**, do a full encrypted install, set a passphrase, reboot.
5. Verdict: does GRUB present the LUKS unlock prompt and boot the system?

## Sources

- [Arch Linux — grub package (2:2.14-1)](https://archlinux.org/packages/core/x86_64/grub/)
- [UbuntuHandbook — GRUB 2.14 released with Argon2 & TPM 2.0 key protector](https://ubuntuhandbook.org/index.php/2026/01/grub-boot-loader-2-14-released-with-argon2-tpm-2-0-key-protector/)
- [Tux Machines — GRUB 2.14 released with EROFS, Argon2 KDF, Shim Loader Protocol](https://news.tuxmachines.org/n/2026/01/14/GRUB_2_14_Released_with_EROFS_Argon2_KDF_and_Shim_Loader_Protoc.shtml)
- [mdleom — GRUB 2.14rc1 supports LUKS2 + Argon2 disk encryption](https://mdleom.com/microblog/2026/01/07/grub-2-14rc1-supports-luks2-argon2-disk-encryption/)
- [mdleom — Enable LUKS2 and Argon2 support for GRUB in Manjaro/Arch (pre-2.14 background)](https://mdleom.com/blog/2022/11/27/grub-luks2-argon2/)
- [GNU GRUB Manual 2.14 — cryptomount](https://www.gnu.org/software/grub/manual/grub/html_node/cryptomount.html)
