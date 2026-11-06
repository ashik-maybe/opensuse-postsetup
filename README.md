# openSUSE Post-Setup Scripts

Baseline software and tuning for openSUSE Leap / Tumbleweed (GNOME and KDE).
Every script is independent. Run any script alone. Safe to re-run.

## Fast Bootstrap (No Git)

If `zypper` is slow, run this to optimise throughput and install Git:

```bash
echo -e "[main]\ndownload.max_concurrent_connections = 10\ndeltarpm = false" | sudo tee -a /etc/zypp/zypp.conf
sudo env ZYPP_CURL2=1 zypper ref
sudo zypper in -y git-core
```

**Reboot** after fast bootstrap to apply multimedia libraries and zRAM.

## Install

```bash
git clone https://github.com/ashik-maybe/opensuse-postsetup.git --depth=1
cd opensuse-postsetup
sudo ./opensuse-postinstall.sh
```

`opensuse-postinstall.sh` enables Packman, installs codecs, optimises
zypper for speed, and applies system tuning. Run it first for the full
baseline. Run it alone if you only want the baseline.

## Scripts

| Script | Purpose | Needs |
| --- | --- | --- |
| `opensuse-postinstall.sh` | Baseline, Packman codecs, zypper speed tuning, zRAM | root |
| `setup-intel-drivers.sh` | Intel VA-API, OpenCL, Vulkan, GPU tools | root |
| `remove_gnome_bloat_opensuse.sh` | Remove unused GNOME packages, locks them. Destructive. | `sudo` |
| `remove_kde_bloat_opensuse.sh` | Disable Baloo, Akonadi, Telepathy, PackageKit. No package removal. | `sudo` |
| `scripts/setup-gearlever.sh` | Install Flatpak, Flathub, FUSE, Gear Lever | `sudo` for zypper |
| `scripts/browsers/install-brave.sh` | Install Brave Browser from the official repo | `sudo` for zypper |
| `scripts/browsers/install-chrome.sh` | Install Google Chrome from the official repo | `sudo` for zypper |
| `scripts/dev-tools/install-codium.sh` | Install VSCodium | `sudo` for zypper |
| `scripts/dev-tools/setup-git-config.sh` | Install Git, user name/email, aliases, SSH key | user |

Each script accepts `--dry-run` (no changes) and `--yes` (no prompts).
Hardened zypper settings are merged key-by-key with a `.bak` backup.
Existing `zypp.conf` values are never lost.

## Zypper Speed Notes

- `download.max_concurrent_connections = 10` parallel downloads
- `deltarpm = false` faster installs, more bandwidth
- `repo.refresh.minimal-age = 3600` skips redundant refreshes
- `solver.onlyRequires = true` smaller solver graph
- `ZYPP_CURL2=1` curl backend for every refresh and install
- Scripts refresh only the repo they need, not every repo

## Notes

- Scripts target openSUSE Leap and Tumbleweed.
- `remove_gnome_bloat_opensuse.sh` deletes packages. Run `--dry-run` first.
- `remove_kde_bloat_opensuse.sh` removes no packages. It disables services.
