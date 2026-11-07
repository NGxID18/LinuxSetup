# Universal Linux Provisioning

Minimalist, automated provisioning scripts and dotfiles for modern Linux distributions.

## Install (One-Liner)

### Recommended (`curl`)
```bash
curl -fsSL https://raw.githubusercontent.com/NGxID18/LinuxSetup/main/install.sh | bash
```

### Alternative (`wget`)
```bash
wget -qO- https://raw.githubusercontent.com/NGxID18/LinuxSetup/main/install.sh | bash
```

## Tested Distributions

- **openSUSE** (Leap 16, Tumbleweed) — `zypper`
- **Fedora** (44, 45) — `dnf`
- **Enterprise Linux** (RHEL 10, Rocky Linux 10, AlmaLinux 10) — `dnf`
- **Debian** (13 Trixie) — `apt`
- **Ubuntu** (24.04 LTS – 26.10) — `apt`
- **Arch Linux** & **CachyOS** — `pacman`

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
    ├── repository.sh
    ├── verify.sh
    ├── DE/
    │   └── gnome/
    │       └── gnome.sh
    ├── apps/
    │   ├── main.sh
    │   └── cockpit.sh
    ├── zram/
    │   └── zram.sh
    ├── driver/
    │   ├── nvidia/
    │   │   ├── nvidia.sh
    │   │   └── 5060tune.sh
    │   ├── amd/
    │   │   └── amd.sh
    │   └── intel/
    │       └── intel.sh
    └── cli/
        ├── fastfetch.sh
        ├── terminal.sh
        └── shell.sh
```
