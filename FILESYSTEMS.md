# Root-filesystem dropdown — choices & study

Study behind the CTT's root-filesystem picker (`FILESYSTEMS` in `confedit.py`,
surfaced as the FILESYSTEM dropdown in `Tweaker.qml`). Records what we ship, what we
considered, and why — so the next person doesn't re-litigate it.

## Decision (2026-06-09)

Dropdown order: **`ext4, f2fs, xfs, jfs, btrfs`**.

`f2fs` was added (after ext4). `nilfs2` was studied and **deliberately left out** for
now. Everything else available on the ISO is not a sensible root-filesystem choice (see
below).

## Inclusion rule

A filesystem belongs in the dropdown only if **all three** hold:

1. Its `mkfs` tool ships on the live ISO (`kiro-iso/archiso/packages.x86_64`).
2. Calamares/KPMcore can create it as `defaultFileSystemType`.
3. It is a real Linux **root** filesystem (not a boot/data/interchange FS).

Because Kiro's Calamares **clones the live airootfs to the target** (packages.conf only
`try_remove`s a few ISO-only packages — no fresh pacstrap), any mkfs/utility on the ISO
also lands on the installed system. So "on the ISO" = "available on the installed box too".

## What we ship

| FS | ISO tool | Notes |
|----|----------|-------|
| ext4 | `e2fsprogs` | Default. Boring, bulletproof, the safe pick. |
| f2fs | `f2fs-tools` | **Added 2026-06-09.** Flash-friendly log-structured FS; good on SSD/NVMe. Uses mount.conf's `default` mountOptions (`defaults, noatime`). |
| xfs | `xfsprogs` | Mature, great for large files / parallel I/O. |
| jfs | `jfsutils` | Legacy/niche, kept on the "expert tool, the choice is the user's" logic. |
| btrfs | `btrfs-progs` | Fully wired in mount.conf (subvolume layout + zstd). Kiro's snapshot story (snapper) lives here. |

## Considered but excluded

### nilfs2 (`nilfs-utils`) — studied, left out for now
Log-structured CoW filesystem (NTT; mainline since 2.6.30). Headline feature is
**continuous automatic checkpointing** → promote any checkpoint to a read-only snapshot
(`lscp`/`chcp`), finer-grained than scheduled btrfs+snapper. SSD-friendly sequential
writes; crash-consistent (no traditional fsck). On Kiro it would actually work end to end:
`nilfs-utils` is on the ISO, so its GC daemon `nilfs_cleanerd` (auto-started by the mount
helper, required or the disk fills) lands on the installed system; systemd-boot reads the
FAT ESP so root-on-nilfs2 boots with the nilfs2 initramfs module.

**Why left out:** the honest caveat vs btrfs is that **nilfs2 has no extended-attribute /
ACL / SELinux-label support**, plus no subvolumes, no transparent compression, no data
checksums, and a far smaller testing base. btrfs already covers the CoW + snapshot need
for Kiro with none of those gaps. nilfs2's continuous-checkpoint angle is interesting
enough to revisit, but it isn't earning a slot today. *Decision: only do f2fs for now.*

### Not root-filesystem candidates (on the ISO, but excluded by rule 3)
- `dosfstools` (fat16/32), `exfatprogs` (exfat), `ntfs-3g` (ntfs), `udftools` (udf) —
  boot/data/interchange filesystems, not Linux roots.

### Not on the ISO (excluded by rule 1)
- **bcachefs** — `#bcachefs-tools` is commented out in `packages.x86_64`. Offering it
  would expose a filesystem Calamares can't format on this ISO.
- **reiserfs / reiser4** — no progs shipped.

### Out of scope by policy
- **zfs** — no root-on-ZFS in Kiro Calamares (out-of-tree maintenance risk); the btrfs
  stack covers desktop use. Standing decision, not revisited here.
- **ext2 / ext3** — `e2fsprogs` can make them, but they're strict subsets of ext4; just
  noise in a root-FS picker.
