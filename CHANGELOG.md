# Changelog

## 2026.06.11

### What Changed
Fixed **Calamares Tweak Tool not launching from the desktop menu** (found on the live
Budgie/Wayland ISO). The `.desktop` ran `Exec=sudo calamares-tweak-tool` with
`Terminal=false`. Bare `sudo` from a menu launch fails two ways: on a normal install it
has no TTY/askpass for the password prompt (so it only worked off a cached sudo ticket —
run once in a terminal, menu works until the ticket expires, then breaks again); and on
the live ISO, where `liveuser` has passwordless sudo, `sudo`'s `env_reset` strips
`DISPLAY`/`WAYLAND_DISPLAY`/`XAUTHORITY`, so the Qt app can't reach the display.
`/etc/calamares` is `root:root`, so escalation is genuinely required (liveuser is uid
1000, not root). Switched to polkit (`pkexec`) — the mechanism the tool already uses to
launch Calamares (`calamares_polkit`) and the one ATT uses — passing the display env
through explicitly.

### Technical Details
- **`usr/share/applications/calamares-tweak-tool.desktop`** — dropped `sudo`; now
  `Exec=calamares-tweak-tool`.
- **`usr/bin/calamares-tweak-tool`** — runs directly if already root (`sudo -E`);
  otherwise escalates via `pkexec env …`. Two menu-launch bugs, both proven on the live
  Budgie/Wayland ISO via the real `gtk-launch` path:
  **(1)** the wrapper must **not** `exec` pkexec — a menu launcher (gtk-launch/budgie)
  fires and exits immediately, so with `exec` pkexec's parent is already dead and it aborts
  with *"Refusing to render service to dead parents"*; keeping the shell alive as pkexec's
  parent fixes it (the reason ATT avoids `exec` too). **(2)** Wayland is detected by
  `$XDG_SESSION_TYPE` / the `wayland-0` socket, not just `$WAYLAND_DISPLAY` — a menu launch
  may not propagate that var, dropping the app onto the X11 branch. Wayland branch forces
  `QT_QPA_PLATFORM=wayland` + `LIBGL_ALWAYS_SOFTWARE=1`, no xcb fallback (as root xcb has no
  X cookie and coredumps; VM EGL leaves the window unpainted). X11 branch passes only
  `DISPLAY`/`XAUTHORITY`, default xcb — zero behavioural change on X11.

### Files Modified
- `usr/share/applications/calamares-tweak-tool.desktop`
- `usr/bin/calamares-tweak-tool`

## 2026.06.09

### What Changed
Added **f2fs** to the root-filesystem dropdown, after ext4 (order now `ext4, f2fs, xfs,
jfs, btrfs`). f2fs is a valid expert choice: `f2fs-tools` ships on the ISO, mount.conf's
`default` mountOptions entry covers it, and Calamares formats it via `defaultFileSystemType`.

### Technical Details
- **`confedit.py`** — `FILESYSTEMS = ("ext4", "f2fs", "xfs", "jfs", "btrfs")`; header
  comment updated (now "five mkfs tools on the ISO"). No QML/main.py change needed — the
  dropdown binds to `backend.filesystems`, which returns the tuple. Verified f2fs
  round-trips through `apply()`/`read()` against the sample config.

### Files Modified
- `usr/share/calamares-tweak-tool/confedit.py`

### Also — follow the renamed bootloader module (`kiro_bootloader`)

**What Changed** — Calamares' bootloader module was renamed from the stock `bootloader` to the
custom **`kiro_bootloader`**, so its config is now `modules/kiro_bootloader.conf`. The tool still
hardcoded `modules/bootloader.conf`, so on the live ISO `exists()` returned false → the red
"No Calamares config found at /etc/calamares" banner and every control greyed out (Calamares
itself still launched fine). Now resolved.

**Technical Details** — `confedit.py` resolves `bootloader_path` by preferring
`kiro_bootloader.conf` and falling back to `bootloader.conf`, so it reads either layout. The
`efiBootLoader` key is unchanged, so `read()` / `apply()` work as-is. Verified `exists()` → true
and `read()` against the live `kiro-calamares-config`.

### Also — removed the unused `--sample` feature

**What Changed** — Deleted the bundled `sample/etc/calamares/` config tree, the `--sample` CLI
flag and `SAMPLE_CONFIG_DIR` (`main.py`), and the "try --sample for the bundled sample" hint on
the no-config banner (`Tweaker.qml`).

**Why** — `--sample` let the tool edit a bundled dummy config off a live ISO; it was never used
and the bundled copy silently drifted from the real config (it still carried the pre-rename
`bootloader.conf`, which is what masked the `kiro_bootloader` break). Removing it deletes the
maintenance trap; the tool now only ever edits the live `/etc/calamares` (or an explicit
`--config-dir`).

## 2026.06.07

### What Changed
The NEMESIS experiment is concluded: **GRUB 2.14 unlocks LUKS2/Argon2id on real
hardware**, so the fork now sets **luks2 for both bootloaders** and drops every luks1-era
claim. Removed the "Force LUKS2 on GRUB" override (its whole reason — testing the
grub+luks2 combo — is answered), purged the false "GRUB can't unlock LUKS2 / may produce
an unbootable system / forced to LUKS1" text, and made the window taller so the Apply row
is no longer clipped.

### Technical Details
- **`confedit.py`** — `LUKS_FOR = {"grub": "luks2", "systemd-boot": "luks2"}`;
  `derived_luks(bootloader)` drops the `force_luks2` param and the luks1 fallback;
  `apply()` drops `force_luks2`; `read()` luksGeneration fallback `luks1 → luks2`;
  header comment rewritten (no invariant/footgun narrative).
- **`main.py`** — removed `_force_luks2`, the `forceLuks2` Property and `setForceLuks2`
  slot; `luksGeneration`/`apply` no longer pass the override; module docstring rewritten.
- **`Tweaker.qml`** — window `height 700 → 670` (trimmed once the override card was gone);
  deleted the red NEMESIS override card and
  the `forcedGrubLuks2`/`isLuks2` helper properties; the LUKS readout is now a single
  truthful luks2 card: "Both GRUB (2.14+) and systemd-boot unlock LUKS2/Argon2id at boot."
- **`sample/.../partition.conf`** — `luksGeneration: luks1 → luks2`.

### Files Modified
- `usr/share/calamares-tweak-tool/confedit.py`
- `usr/share/calamares-tweak-tool/main.py`
- `usr/share/calamares-tweak-tool/Tweaker.qml`
- `usr/share/calamares-tweak-tool/sample/etc/calamares/modules/partition.conf`
- `CLAUDE.md`, `CHANGELOG.md`

## 2026.06.05

### What Changed
Forked the stable CTT into the **NEMESIS** experimental package
(`kiro-calamares-tweak-tool-nemesis`, which `replaces`/`conflicts` the stable one) and
added the one thing the stable tool forbids by design: a **Force LUKS2 on GRUB**
override, so we can deliberately write the `grub` + `luks2` combo and test whether the
current GRUB on Arch can actually unlock it. Because the whole package is dev-only, the
override is always available — no gating flag.

Research that motivated this: **Arch core now ships `grub 2:2.14-1` (updated 2026-01-16),
and GRUB 2.14 added Argon2i/Argon2id KDF support for LUKS2.** The "LUKS2-on-stock-GRUB →
unbootable" footgun the stable CTT exists to prevent is, as of Jan 2026, very likely
*fixed upstream* — this package is the harness to prove that on a real Kiro install before
the stable tool's invariant is relaxed.

### Technical Details
- **`confedit.py`** — `derived_luks(bootloader, force_luks2=False)` and
  `apply(..., force_luks2=False)` gained an optional override; when `force_luks2` is set,
  `luksGeneration` is written as `luks2` regardless of bootloader. The `LUKS_FOR`
  invariant is otherwise unchanged — the override is the only way past it.
- **`main.py`** — `Backend` exposes `forceLuks2` (notify) + `setForceLuks2()` and threads
  it into `luksGeneration`/`apply()`. Dropped the old `--dev` flag (redundant — the whole
  app is dev); the config target is now `/etc/calamares` by default, `--sample` for the
  bundled copy, `--config-dir` to override. `--config-dir`/`--sample`/default precedence
  fixed so a config path always wins (the stable tool's `--dev` silently ignored
  `--config-dir`, which would have blocked a real install test).
- **`Tweaker.qml`** — new red **"NEMESIS · FORCE LUKS2 ON GRUB"** override card with a
  switch + an inline ⚠ when grub+luks2 is active; the LUKS readout turns red and explains
  the forced combo instead of the usual green/amber. Window title marked `— NEMESIS`.
- Verified: ruff clean; headless functional test of `force_luks2` (grub→luks2, normal
  grub→luks1, systemd-boot→luks2); offscreen QML load smoke test passes.

### How to test (live ISO VM)
1. Build `kiro-calamares-tweak-tool-nemesis` into `kiro_repo`, bake the `-nemesis` ISO.
2. In the live session: `sudo -E calamares-tweak-tool` → pick **grub**, encryption **on**,
   flip **Force LUKS2 on GRUB** → Apply → confirm `partition.conf` shows `luksGeneration:
   luks2`. Launch installer, do a full encrypted install, reboot.
3. Verdict = does GRUB show the LUKS unlock prompt and boot. If yes, GRUB 2.14 Argon2id is
   confirmed and the stable CTT's grub→luks1 invariant can be revisited.

### Files Modified
- `usr/share/calamares-tweak-tool/confedit.py`
- `usr/share/calamares-tweak-tool/main.py`
- `usr/share/calamares-tweak-tool/Tweaker.qml`
- `CHANGELOG.md`, `CLAUDE.md`

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
