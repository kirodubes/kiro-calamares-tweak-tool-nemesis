"""Read and write the handful of Calamares settings v1 cares about, editing the
live .conf files in place with comment-preserving single-line replacements (never a
YAML round-trip — that would strip the heavily-commented upstream files)."""
import os
import re
from pathlib import Path

# LUKS generation is luks2 for both bootloaders: GRUB 2.14+ and systemd-boot both unlock
# LUKS2/Argon2id at boot (proven on real BIOS + UEFI installs). Argon2id is the stronger KDF.
LUKS_FOR = {"grub": "luks2", "systemd-boot": "luks2"}

BOOTLOADERS = ("systemd-boot", "grub")


def _get_scalar(text, key):
    """First uncommented `key: value` value (quotes stripped), or None."""
    m = re.search(rf'^[ \t]*{re.escape(key)}:[ \t]*(.+?)[ \t]*$', text, re.M)
    return m.group(1).strip().strip('"').strip("'") if m else None


def _set_scalar(text, key, value):
    """Replace the value of the first uncommented `key:` line, preserving the key and
    its trailing spacing. Returns (new_text, replaced_count)."""
    pat = re.compile(rf'^([ \t]*{re.escape(key)}:[ \t]*).*$', re.M)
    return pat.subn(lambda m: m.group(1) + value, text, count=1)


class CalamaresConfig:
    """The two files v1 touches, under <config_dir>/modules/."""

    def __init__(self, config_dir):
        self.config_dir = Path(config_dir)
        self.partition_path = self.config_dir / "modules" / "partition.conf"
        # The bootloader module is the custom "kiro_bootloader" now; fall back to the stock
        # "bootloader" name so the tool still reads an older config layout.
        modules = self.config_dir / "modules"
        self.bootloader_path = next(
            (modules / n for n in ("kiro_bootloader.conf", "bootloader.conf") if (modules / n).is_file()),
            modules / "kiro_bootloader.conf",
        )

    def exists(self):
        return self.partition_path.is_file() and self.bootloader_path.is_file()

    def writable(self):
        return self.exists() and all(
            os.access(p, os.W_OK) for p in (self.partition_path, self.bootloader_path)
        )

    @staticmethod
    def derived_luks(bootloader):
        return LUKS_FOR.get(bootloader, "luks2")

    def read(self):
        """Current state as {bootloader, luksGeneration, encryption}."""
        bt = self.bootloader_path.read_text()
        pt = self.partition_path.read_text()
        bootloader = _get_scalar(bt, "efiBootLoader") or "systemd-boot"
        return {
            "bootloader": bootloader,
            "luksGeneration": _get_scalar(pt, "luksGeneration") or "luks2",
            "encryption": (_get_scalar(pt, "enableLuksAutomatedPartitioning") or "false").lower() == "true",
        }

    def apply(self, bootloader, encryption):
        """Write the bootloader, the derived luksGeneration and the encryption switch."""
        if bootloader not in BOOTLOADERS:
            raise ValueError(f"unknown bootloader: {bootloader}")

        bt = self.bootloader_path.read_text()
        bt, nb = _set_scalar(bt, "efiBootLoader", f'"{bootloader}"')

        pt = self.partition_path.read_text()
        pt, nl = _set_scalar(pt, "luksGeneration", self.derived_luks(bootloader))
        pt, ne = _set_scalar(pt, "enableLuksAutomatedPartitioning", "true" if encryption else "false")

        missing = [k for k, n in (("efiBootLoader", nb), ("luksGeneration", nl),
                                  ("enableLuksAutomatedPartitioning", ne)) if n == 0]
        if missing:
            raise KeyError(f"settings not found in config: {', '.join(missing)}")

        self.bootloader_path.write_text(bt)
        self.partition_path.write_text(pt)
