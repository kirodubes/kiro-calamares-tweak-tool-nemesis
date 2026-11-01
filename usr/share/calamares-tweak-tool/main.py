#!/usr/bin/env python
"""Calamares Tweak Tool — a dev/expert PySide6 panel that flips the live ISO's
Calamares encryption + bootloader settings before you launch the installer. Encryption
uses LUKS2/Argon2id, which both GRUB (2.14+) and systemd-boot unlock at boot."""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

import ctt_i18n
from confedit import BOOTLOADERS, CalamaresConfig
from ctt_i18n import _
from PySide6.QtCore import Property, QObject, QUrl, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon
from PySide6.QtQml import QQmlApplicationEngine

DEFAULT_CONFIG_DIR = "/etc/calamares"
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
        self._status = ""
        self._saved = False
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

    @Property("QStringList", constant=True)
    def bootloaders(self):
        return list(BOOTLOADERS)

    @Property(str, notify=stateChanged)
    def bootloader(self):
        return self._bootloader

    @Property(bool, notify=stateChanged)
    def encryption(self):
        return self._encryption

    @Property(str, notify=stateChanged)
    def luksGeneration(self):
        return self._cfg.derived_luks(self._bootloader)

    @Property(str, notify=statusChanged)
    def status(self):
        return self._status

    @Property(bool, notify=statusChanged)
    def saved(self):
        return self._saved

    @Property(int, notify=saveTickChanged)
    def saveTick(self):
        return self._save_tick

    def _set_status(self, text, saved=False):
        self._status = text
        self._saved = saved
        self.statusChanged.emit()

    # ── slots ───────────────────────────────────────────────────────────
    @Slot()
    def reload(self):
        if self._cfg.exists():
            cur = self._cfg.read()
            self._bootloader = cur["bootloader"] if cur["bootloader"] in BOOTLOADERS else "systemd-boot"
            self._encryption = cur["encryption"]
            self._set_status(_("Loaded from {path}").format(path=self._cfg.config_dir))
        else:
            self._set_status(_("No Calamares config at {path}").format(path=self._cfg.config_dir))
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

    @Slot()
    def apply(self):
        luks = self._cfg.derived_luks(self._bootloader)
        try:
            self._cfg.apply(self._bootloader, self._encryption)
        except PermissionError:
            self._set_status(_("Permission denied: relaunch as root to edit {path}").format(path=self._cfg.config_dir))
            return
        except (OSError, KeyError, ValueError) as exc:
            self._set_status(_("Failed: {error}").format(error=exc))
            return
        if self._encryption:
            msg = _("Saved: {bootloader}, encryption on, {luks}").format(bootloader=self._bootloader, luks=luks)
        else:
            msg = _("Saved: {bootloader}, encryption off, {luks}").format(bootloader=self._bootloader, luks=luks)
        self._set_status(msg, saved=True)
        self._save_tick += 1
        self.saveTickChanged.emit()
        _notify(msg)

    @Slot()
    def launchInstaller(self):
        try:
            subprocess.Popen(LAUNCH_CMD)
            self._set_status(_("Launching Calamares…"))
        except OSError as exc:
            self._set_status(_("Could not launch Calamares: {error}").format(error=exc))


class I18n(QObject):
    """Translations for the QML side, plus the header's language dropdown."""

    pendingChanged = Signal()

    def __init__(self):
        super().__init__()
        self._codes = [None, *ctt_i18n.available()]
        self._pending = False

    @Slot(str, result=str)
    def t(self, text):
        return _(text)

    @Property("QStringList", constant=True)
    def languageLabels(self):
        system = _("System ({language})").format(language=ctt_i18n.name(ctt_i18n.SYSTEM))
        return [system, *(ctt_i18n.name(c) for c in self._codes[1:])]

    @Property(int, constant=True)
    def languageIndex(self):
        chosen = ctt_i18n.chosen()
        return self._codes.index(chosen) if chosen in self._codes else 0

    @Property(bool, notify=pendingChanged)
    def pending(self):
        return self._pending

    @Slot(int)
    def chooseLanguage(self, index):
        try:
            ctt_i18n.save_choice(self._codes[index])
        except OSError:
            return
        self._pending = True
        self.pendingChanged.emit()

    @Slot()
    def restart(self):
        ctt_i18n.restore_environment()
        os.execv(sys.executable, [sys.executable, os.path.abspath(sys.argv[0]), *sys.argv[1:]])


def main():
    ap = argparse.ArgumentParser(prog="calamares-tweak-tool")
    ap.add_argument("--config-dir", default=None,
                    help=f"Calamares config root to edit (default {DEFAULT_CONFIG_DIR})")
    args = ap.parse_args()

    config_dir = Path(args.config_dir) if args.config_dir is not None else Path(DEFAULT_CONFIG_DIR)

    here = Path(__file__).resolve().parent

    app = QGuiApplication(sys.argv)
    app.setOrganizationName("kiro")
    app.setApplicationName("calamares-tweak-tool")
    app.setWindowIcon(QIcon(str(here / "assets" / "logo.png")))
    backend = Backend(config_dir)

    engine = QQmlApplicationEngine()
    ctx = engine.rootContext()
    i18n = I18n()
    ctx.setContextProperty("backend", backend)
    ctx.setContextProperty("i18n", i18n)
    ctx.setContextProperty("logoPath", QUrl.fromLocalFile(str(here / "assets" / "logo.png")).toString())
    engine.load(QUrl.fromLocalFile(str(here / "Tweaker.qml")))
    if not engine.rootObjects():
        return 1
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
