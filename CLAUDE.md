# calamares-tweak-tool — project notes

Dev/expert PySide6 panel for the Kiro **live ISO**. Edits the Calamares installer's
encryption + bootloader settings under `/etc/calamares`, then launches the installer.
Installer-side sibling of ATT. Design summary: `~/calamares-tweak-tool.md`.

## Layout
- `usr/bin/calamares-tweak-tool` — launcher (execs the Python entry).
- `usr/share/calamares-tweak-tool/main.py` — `Backend` QObject + QML engine, argparse.
- `usr/share/calamares-tweak-tool/confedit.py` — `CalamaresConfig`: read/write the conf
  files with comment-preserving line edits. Pure, no Qt — unit-testable.
- `usr/share/calamares-tweak-tool/Tweaker.qml` — the UI.
- `usr/share/calamares-tweak-tool/sample/` — bundled sample `/etc/calamares` for `--dev`.
- `usr/share/applications/*.desktop` — visible menu entry (Categories System;Settings;Utility).

## Conventions
- Python: ruff clean, max line 120.
- **The v1 invariant** is `LUKS_FOR` in `confedit.py` — LUKS generation is normally a
  function of the bootloader, never a free choice.
- **NEMESIS deviation (intentional):** this experimental fork keeps a single sanctioned
  escape hatch — the `force_luks2` override (`forceLuks2`/`setForceLuks2`, the red "Force
  LUKS2 on GRUB" card) — to deliberately write the `grub`+`luks2` combo and test whether
  current GRUB can unlock it. Do NOT "fix" this back to the stable invariant. Motivation:
  Arch ships `grub 2:2.14-1` (2026-01-16) and GRUB 2.14 added Argon2id KDF support, so the
  unbootable-combo premise may no longer hold. Still don't add a *free* LUKS picker — the
  override is the one allowed deviation. The stable `kiro-calamares-tweak-tool` keeps the
  invariant absolute.
- Never YAML-round-trip the conf files — they're heavily commented. Use `_set_scalar`.
- Brand colors: blue `#0195F7`, green `#2FC328`; dark bg `#0F172A`/`#020617`.

## Elevation model (v1 simplification)
CTT writes `/etc/calamares` directly and assumes it has permission. Run it elevated to
save (`sudo -E calamares-tweak-tool`, or the `pkexec` `.desktop`). When not writable,
Apply is disabled and a banner says so. `--config-dir` on a writable copy needs no root
(this is how it's tested). A self-elevating writer is possible later but out of v1.

## Packaging / placement
Package name is **`kiro-calamares-tweak-tool`** (kiro- prefix); binary + `/usr/share`
paths stay unprefixed `calamares-tweak-tool`. App repo: `~/KIRO-ISO-CALAMARES/kiro-
calamares-tweak-tool` (with the other Calamares/ISO repos), `kirodubes` org, baked into
the live ISO airootfs (installer-only side), NOT nemesis_repo. PKGBUILD recipe:
`~/KIRO-PKG-BUILD-CALAMARES/kiro-calamares-tweak-tool` (dir name must match pkgname for
build.sh's glob); runtime deps `pyside6`, `polkit`. Built into `kiro_repo` via that
recipe's `build.sh` (build.sh auto-bumps pkgrel).

## Status
v1 — encryption ↔ bootloader pairing. v2 backlog (filesystem, swap, kernel params,
timezone, shell, groups, services, btrfs, presets, schema-driven UI) in the design doc.
