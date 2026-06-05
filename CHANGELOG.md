# Changelog

## 2026.06.04

### What Changed
The window/titlebar icon (top-left corner of the window border drawn by the WM) is now
the Kiro **K** logo instead of the generic default — the app never set a window icon.

### Technical Details
`main.py` now calls `app.setWindowIcon(QIcon(...))` with the existing
`assets/logo.png` (the same Kiro K already shown in the in-app header). Imported `QIcon`
alongside `QGuiApplication`, and hoisted the `here = Path(__file__)...` line above the
`QGuiApplication` construction so the icon path is available when the app is created and
before any window is shown.

### Files Modified
- `usr/share/calamares-tweak-tool/main.py`

## 2026.06.03

### What Changed
First cut of the **Calamares Tweak Tool (CTT)** — a dev/expert PySide6 panel for the
Kiro live ISO that edits the Calamares encryption + bootloader settings before the
installer is launched, collapsing the "rebuild the ISO to test a one-line config change"
loop. v1 scope is the encryption ↔ bootloader pairing only.

Same-day refinements:
- Packaged as **`kiro-calamares-tweak-tool`** (kiro- prefix per the package-naming
  convention); the binary and `/usr/share` paths stay unprefixed `calamares-tweak-tool`.
- **Menu visibility:** dropped `NoDisplay=true` from the `.desktop` so the tool actually
  appears in the application menu (`Categories=System;Settings;Utility;`).
- **Correct launch command:** the Launch button now runs
  `/usr/bin/calamares_polkit -d -style kvantum` (the exact `cal-kiro.desktop` command,
  via the `calamares_polkit` wrapper = `pkexec --disable-internal-agent calamares`),
  instead of a bare `pkexec calamares` that skipped the wrapper and the KiroDark style.
- **Encryption is independent of the bootloader.** The bootloader still derives the LUKS
  *version* (luks1/luks2), but the encryption switch alone drives
  `enableLuksAutomatedPartitioning` — it's no longer auto-forced on when a bootloader is
  picked (that briefly left it stuck on `true`).
- **Visually-apparent encryption reminder** banner above the buttons so the setting isn't
  forgotten: amber when OFF ("Encryption is OFF — turn the switch on, or the installer
  won't offer to encrypt"), green when ON ("don't forget to tick 'Encrypt system' + set a
  passphrase in the installer").
- **v2 — filesystem dropdown:** a ComboBox sets the root `defaultFileSystemType` —
  **ext4 / xfs / jfs / btrfs**. (The config was simplified to keep only that one key;
  `availableFileSystemTypes` was removed, so CTT no longer writes it. jfs is legacy/niche
  and was briefly pulled — the logredo/fsck it showed traced to unclean-shutdown debugging,
  not jfs itself — so it's kept: this is an expert tool, the choice is the user's.)
  btrfs reuses the subvolume layout + zstd already wired in `mount.conf`; the others
  use the `default` mountOptions. All four mkfs tools (e2fsprogs / xfsprogs / jfsutils /
  btrfs-progs) confirmed present on the ISO pkglist. FILESYSTEM card sits at the top
  (foundational disk choice) above BOOTLOADER and ENCRYPTION.
- **Themes (day/night) ported from kiro-keybindings:** a ☾/☀ mode toggle + swatch picker
  in the header, 7 dark + 7 light palettes (Kiro/Arc/Nord/Dracula/Gruvbox/Catppuccin/Neon/
  Solarized), choice persisted via `Settings`. CTT's semantic `warn`/`danger` colours and
  the tinted LUKS/reminder boxes are now mode-derived so they read correctly in both.
- **Prominent "Saved" confirmation.** The save result used to be a tiny grey status line
  that was easy to miss. It's now a centered green pill (brand green `accentB`, a ✓ glyph,
  bigger bold text) that **pulses on every Apply** — a one-shot scale-up + flash so even a
  re-save with identical settings visibly blinks. Only `Saved:` messages get the pill;
  other statuses (`Failed:`, `Launching…`, read-only) stay as the plain subtle line.

### Technical Details
- **`confedit.py`** — `CalamaresConfig` reads/writes `bootloader.conf` (`efiBootLoader`)
  and `partition.conf` (`luksGeneration`, `enableLuksAutomatedPartitioning`) with
  comment-preserving regex line replacements, never a YAML round-trip. The v1 invariant
  lives here: `LUKS_FOR = {"grub": "luks1", "systemd-boot": "luks2"}`, so the LUKS
  generation is always derived from the bootloader — the unbootable LUKS2-on-stock-GRUB
  combo can't be expressed.
- **`main.py`** — PySide6 `Backend` QObject exposing bootloader / encryption / derived
  `luksGeneration` / writability to QML; `apply()` writes the files, `launchInstaller()`
  runs `pkexec calamares` (mirrors the live ISO's `calamares.desktop`). `--config-dir`
  (default `/etc/calamares`) and `--dev` (bundled sample) make it testable anywhere.
- **`Tweaker.qml`** — Kiro dark theme; bootloader radio, encryption switch, and a live
  LUKS readout that turns green (LUKS2/systemd-boot) or amber (LUKS1/GRUB) with the
  reason, surfacing the guard. Apply disabled when the config isn't writable.
- Toolkit is PySide6/Qt6 (matches kiro-keybindings): Calamares already pulls the Qt6
  runtime onto the live ISO, so CTT only adds the binding layer.
- Dev-hidden `.desktop` (`NoDisplay=true`) — kept off the default live desktop.
- **Saved-pill pulse** is driven by a `saveTick` int property on `Backend`, incremented +
  emitted on each successful `apply()`. QML restarts a `SequentialAnimation` on
  `onSaveTickChanged`, so the pulse re-fires even when the saved text is unchanged (a plain
  text-change trigger would not). The flash uses an opacity-pulsed overlay `Rectangle` so
  the pill's `color` binding stays intact across theme switches.

### Files Modified
- `usr/share/calamares-tweak-tool/confedit.py`
- `usr/share/calamares-tweak-tool/main.py`
- `usr/share/calamares-tweak-tool/Tweaker.qml`
- `usr/share/calamares-tweak-tool/sample/etc/calamares/modules/{partition,bootloader}.conf`
- `usr/bin/calamares-tweak-tool`
- `usr/share/applications/calamares-tweak-tool.desktop`
- `up.sh`, `setup.sh`, `README.md`, `CHANGELOG.md`, `CLAUDE.md`, `LICENSE`
