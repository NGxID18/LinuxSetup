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
- **Enterprise Linux** (AlmaLinux, RHEL, Rocky Linux, CentOS) — `dnf`
- **Debian** — `apt`
- **Ubuntu** — `apt`
- **Arch Linux** & **CachyOS** — `pacman`

## Interactive Workflow

1. **Repository Menu**: Toggle official, third-party, community, AUR helper, and Flathub repositories per distro.
2. **GPU Driver Menu**: Automatically adapts available driver options (e.g., `akmod-nvidia-open` vs `akmod-nvidia`) to the selected repositories.
3. **Applications Menu**: Displays repository-gated native presets, universal Flathub presets, and live package search (`/ <query>`, `sf <query>`).
4. **System & CLI Modules**: Optional minimal GNOME desktop, Cockpit Web Console, CLI stack (Fastfetch, Kitty, Zsh), zRAM swap, and installation verification.

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
    │   └── tui.sh
    ├── common/
    │   ├── flatpak.sh
    │   ├── gnome-config.sh
    │   ├── cli-config.sh
    │   ├── cockpit-config.sh
    │   ├── zram-config.sh
    │   └── 5060tune.sh
    └── distro/
        ├── almalinux/{repo.sh,driver.sh,apps.sh}
        ├── arch/{repo.sh,driver.sh,apps.sh}
        ├── cachyos/{repo.sh,driver.sh,apps.sh}
        ├── debian/{repo.sh,driver.sh,apps.sh}
        ├── fedora/{repo.sh,driver.sh,apps.sh}
        ├── leap/{repo.sh,driver.sh,apps.sh}
        ├── tumbleweed/{repo.sh,driver.sh,apps.sh}
        └── ubuntu/{repo.sh,driver.sh,apps.sh}
```
