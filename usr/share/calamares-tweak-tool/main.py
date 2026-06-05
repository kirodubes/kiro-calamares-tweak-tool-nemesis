#!/usr/bin/env python
"""Calamares Tweak Tool — a dev/expert PySide6 panel that flips the live ISO's
Calamares encryption + bootloader settings before you launch the installer. v1 pairs
the bootloader with the only safe LUKS generation, so an unbootable combo (luks2 on
stock GRUB) is impossible by construction."""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

from confedit import BOOTLOADERS, FILESYSTEMS, CalamaresConfig
from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

DEFAULT_CONFIG_DIR = "/etc/calamares"
SAMPLE_CONFIG_DIR = Path(__file__).resolve().parent / "sample" / "etc" / "calamares"
# Mirror the Kiro live launcher exactly (cal-kiro.desktop): the calamares_polkit
# wrapper runs `pkexec --disable-internal-agent /usr/bin/calamares`, and -d -style
# kvantum give the debug session.log + the KiroDark theme.
LAUNCH_CMD = ["/usr/bin/calamares_polkit", "-d", "-style", "kvantum"]


def _notify(msg):
    """Best-effort desktop notification on apply (transparency). Skipped as root —
    notify-send can't reach the user bus there — and when notify-send is absent."""
    if os.geteuid() != 0 and shutil.which("notify-send"):
        subprocess.Popen(["notify-send", "Calamares Tweak Tool", msg])


class Backend(QObject):
    stateChanged = Signal()
    statusChanged = Signal()
    saveTickChanged = Signal()

    def __init__(self, config_dir):
        super().__init__()
        self._cfg = CalamaresConfig(config_dir)
        self._bootloader = "systemd-boot"
        self._encryption = False
        self._filesystem = "ext4"
        self._force_luks2 = False
        self._status = ""
        self._save_tick = 0
        self.reload()

    # ── exposed state ───────────────────────────────────────────────────
    @Property(str, constant=True)
    def configDir(self):
        return str(self._cfg.config_dir)

    @Property(bool, constant=True)
    def configExists(self):
        return self._cfg.exists()

    @Property(bool, constant=True)
    def writable(self):
        return self._cfg.writable()

    @Property(bool, notify=stateChanged)
    def forceLuks2(self):
        return self._force_luks2

    @Property("QStringList", constant=True)
    def bootloaders(self):
        return list(BOOTLOADERS)

    @Property("QStringList", constant=True)
    def filesystems(self):
        return list(FILESYSTEMS)

    @Property(str, notify=stateChanged)
    def bootloader(self):
        return self._bootloader

    @Property(str, notify=stateChanged)
    def filesystem(self):
        return self._filesystem

    @Property(bool, notify=stateChanged)
    def encryption(self):
        return self._encryption

    @Property(str, notify=stateChanged)
    def luksGeneration(self):
        return self._cfg.derived_luks(self._bootloader, self._force_luks2)

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(int, notify=saveTickChanged)
    def saveTick(self):
        return self._save_tick

    def _set_status(self, text):
        self._status = text
        self.statusChanged.emit()

    # ── slots ───────────────────────────────────────────────────────────
    @Slot()
    def reload(self):
        if self._cfg.exists():
            cur = self._cfg.read()
            self._bootloader = cur["bootloader"] if cur["bootloader"] in BOOTLOADERS else "systemd-boot"
            self._encryption = cur["encryption"]
            self._filesystem = cur["filesystem"] if cur["filesystem"] in FILESYSTEMS else "ext4"
            self._set_status(f"Loaded from {self._cfg.config_dir}")
        else:
            self._set_status(f"No Calamares config at {self._cfg.config_dir}")
        self.stateChanged.emit()

    @Slot(str)
    def setBootloader(self, value):
        if value in BOOTLOADERS and value != self._bootloader:
            self._bootloader = value
            self.stateChanged.emit()

    @Slot(bool)
    def setEncryption(self, value):
        if value != self._encryption:
            self._encryption = bool(value)
            self.stateChanged.emit()

    @Slot(str)
    def setFilesystem(self, value):
        if value in FILESYSTEMS and value != self._filesystem:
            self._filesystem = value
            self.stateChanged.emit()

    @Slot(bool)
    def setForceLuks2(self, value):
        if bool(value) != self._force_luks2:
            self._force_luks2 = bool(value)
            self.stateChanged.emit()

    @Slot()
    def apply(self):
        luks = self._cfg.derived_luks(self._bootloader, self._force_luks2)
        try:
            self._cfg.apply(self._bootloader, self._encryption, self._filesystem, self._force_luks2)
        except PermissionError:
            self._set_status(f"Permission denied — relaunch as root to edit {self._cfg.config_dir}")
            return
        except (OSError, KeyError, ValueError) as exc:
            self._set_status(f"Failed: {exc}")
            return
        enc = "on" if self._encryption else "off"
        msg = f"Saved: {self._bootloader} · {self._filesystem} · encryption {enc} · {luks}"
        self._set_status(msg)
        self._save_tick += 1
        self.saveTickChanged.emit()
        _notify(msg)

    @Slot()
    def launchInstaller(self):
        try:
            subprocess.Popen(LAUNCH_CMD)
            self._set_status("Launching Calamares…")
        except OSError as exc:
            self._set_status(f"Could not launch Calamares: {exc}")


def main():
    ap = argparse.ArgumentParser(prog="calamares-tweak-tool")
    ap.add_argument("--config-dir", default=None,
                    help=f"Calamares config root to edit (default {DEFAULT_CONFIG_DIR}, "
                         "or the bundled sample under --sample)")
    ap.add_argument("--sample", action="store_true",
                    help="edit the bundled sample config instead of /etc/calamares "
                         "(inspect/test the UI off the live ISO, no root needed)")
    args = ap.parse_args()

    # --config-dir always wins; --sample targets the bundled copy; otherwise the live config.
    if args.config_dir is not None:
        config_dir = Path(args.config_dir)
    elif args.sample:
        config_dir = SAMPLE_CONFIG_DIR
    else:
        config_dir = Path(DEFAULT_CONFIG_DIR)

    here = Path(__file__).resolve().parent

    app = QGuiApplication(sys.argv)
    app.setOrganizationName("kiro")
    app.setApplicationName("calamares-tweak-tool")
    app.setWindowIcon(QIcon(str(here / "assets" / "logo.png")))
    backend = Backend(config_dir)

    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    ctx.setContextProperty("backend", backend)
    ctx.setContextProperty("logoPath", QUrl.fromLocalFile(str(here / "assets" / "logo.png")).toString())
    engine.load(QUrl.fromLocalFile(str(here / "Tweaker.qml")))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
