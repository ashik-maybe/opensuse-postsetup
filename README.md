# openSUSE Post-Setup Scripts

Install baseline software on openSUSE Leap and Tumbleweed.
Each script runs alone. Each script is safe to re-run.

## Fast Bootstrap

Use when `zypper` is slow and Git is missing.

1. Back up `/etc/zypp/zypp.conf` to `/etc/zypp/zypp.conf.bak`.
2. Append missing keys to `/etc/zypp/zypp.conf`.
   Set `download.max_concurrent_connections = 10`.
   Set `deltarpm = false`.
3. Run refresh with the curl backend.
   Run `sudo env ZYPP_CURL2=1 zypper ref`.
4. Install Git.
   Run `sudo zypper in -y git-core`.
5. Reboot.

## Install

1. Clone the repository.
   Run `git clone https://github.com/ashik-maybe/opensuse-postsetup.git --depth=1`.
2. Enter the directory.
   Run `cd opensuse-postsetup`.
3. Run the baseline script.
   Run `sudo ./opensuse-postinstall.sh`.

The baseline script runs in this order:

1. Create a snapper snapshot.
2. Enable Packman Essentials.
3. Install multimedia codecs.
4. Optimise zypper and install `zram-generator`.
5. Enable `fstrim.timer` and mask PackageKit.
6. Run a full update and clean the cache.

## Scripts

| Script | Purpose | Needs |
| --- | --- | --- |
| `opensuse-postinstall.sh` | Baseline setup, Packman codecs, zypper tuning | root |
| `setup-intel-drivers.sh` | Intel VA-API, OpenCL, Vulkan, GPU tools | root |
| `remove_gnome_bloat_opensuse.sh` | Remove GNOME packages and lock them | sudo |
| `remove_kde_bloat_opensuse.sh` | Disable Baloo, Akonadi, Telepathy, PackageKit | sudo |
| `scripts/setup-gearlever.sh` | Install Flatpak, Flathub, FUSE, Gear Lever | sudo |
| `scripts/browsers/install-brave.sh` | Install Brave Browser | sudo |
| `scripts/browsers/install-chrome.sh` | Install Google Chrome | sudo |
| `scripts/dev-tools/install-codium.sh` | Install VSCodium | sudo |
| `scripts/dev-tools/setup-git-config.sh` | Install Git, user name, user email, SSH key | user |

Every script accepts these flags:

- `--dry-run` prints steps and changes nothing.
- `--yes` skips each confirmation prompt.
- `--help` prints usage.

Every script installs its own dependencies.
No script requires another script first.

## Modules

Every script contains its own modules.
No script imports another script.
No shared library exists in this repository.

Inside every script, blocks appear in this order:

1. `CONFIG` holds packages, URLs, and paths.
2. `HELPERS` holds `log`, `ok`, `warn`, `die`, `run`, and the zypper wrapper.
3. `GUARDS` holds `parse_args`, `require_root`, and `confirm`.
4. `MODULES` holds one function per task.
5. `MAIN` calls each module once.

Each module carries a marker:

```bash
# === MODULE: step_repo v1 ===
# === END MODULE: step_repo ===
```

Upgrade only the module that changed.
Bump the `vN` number when behaviour changes.

## Zypper Speed

Every script uses these settings:

- `download.max_concurrent_connections = 10` allows parallel downloads.
- `deltarpm = false` makes installs faster.
- `repo.refresh.minimal-age = 3600` skips redundant refreshes.
- `solver.onlyRequires = true` shrinks the solver graph.
- `ZYPP_CURL2=1` uses the curl backend for each refresh and install.
- Each script refreshes only the repository it needs.

The baseline script merges settings into `/etc/zypp/zypp.conf`.
The script creates a `.bak` backup before it changes the file.
Existing values survive a re-run.

## Notes

- Target releases: openSUSE Leap and Tumbleweed.
- `remove_gnome_bloat_opensuse.sh` deletes packages.
  Run `--dry-run` before it.
- `remove_kde_bloat_opensuse.sh` deletes no packages.
  It disables services only.
- Exit codes: `0` means ok, `1` means error, `2` means aborted.
