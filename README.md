# Universal Linux Provisioning

Minimalist, interactive `archinstall`-inspired provisioning scripts and dotfiles for modern Linux distributions.

## Install (One-Liner)

### Recommended (`curl`)
```bash
curl -fsSL https://raw.githubusercontent.com/NGxID18/LinuxSetup/main/install.sh | bash
```

### Alternative (`wget`)
```bash
wget -qO- https://raw.githubusercontent.com/NGxID18/LinuxSetup/main/install.sh | bash
```

## Supported Distributions

- **openSUSE** (Leap, Tumbleweed) — `zypper`
- **Fedora** — `dnf`
- **Enterprise Linux** (RHEL, Rocky Linux, AlmaLinux, CentOS, Oracle Linux) — `dnf`
- **Debian** — `apt`
- **Ubuntu** — `apt`
- **Arch Linux** & **CachyOS** — `pacman`

## Interactive Workflow

1. **Repository Menu**: Auto-detects active system repositories (with two-way sync) and lets you toggle official, third-party, community, AUR helper, and Flathub repositories per distro.
2. **GPU Driver Menu**: Modular per-vendor driver scripts (`driver/{nvidia,amd,intel}.sh`) that automatically adapt available options to the selected repositories.
3. **Desktop Environment / GUI Menu**: Extensible menu auto-discovered from `de/*.sh` (currently minimal GNOME Desktop & Wallpapers).
4. **Applications Menu**: Displays repository-gated native presets, universal Flathub presets, and live package search (`/ <query>`, `sf <query>`).
5. **System & CLI Modules**: Modular `system/{cockpit,cli,zram}.sh` scripts for Cockpit Web Console, CLI stack (Fastfetch, Kitty, Zsh), zRAM swap, and installation verification.

## Structure

```text
.
├── install.sh
├── Wallpapers/
├── config/
│   ├── fastfetch/config.jsonc
│   ├── kitty/
│   └── shell/.zshrc
└── script/
    ├── setup.sh
    ├── verify.sh
    ├── lib/
    │   ├── tui.sh
    │   ├── env.sh
    │   ├── hardware.sh
    │   ├── repo-detect.sh
    │   ├── menu-repo.sh
    │   ├── menu-system.sh
    │   └── menu-apps.sh
    ├── common/
    │   ├── flatpak.sh
    │   ├── gnome-config.sh
    │   ├── cli-config.sh
    │   ├── cockpit-config.sh
    │   ├── zram-config.sh
    │   └── 5060tune.sh
    └── distro/
        └── <arch|cachyos|debian|el|fedora|leap|tumbleweed|ubuntu>/
            ├── repo.sh
            ├── apps.sh
            ├── driver/
            │   ├── nvidia.sh
            │   ├── amd.sh
            │   └── intel.sh
            ├── de/
            │   └── gnome.sh
            └── system/
                ├── cockpit.sh
                ├── cli.sh
                └── zram.sh
```
