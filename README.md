# Universal Linux Provisioning

Minimalist, interactive provisioning scripts and dotfiles for **Debian/Ubuntu (`apt`)**, **Fedora/RHEL (`dnf`)**, and **Arch Linux (`pacman`)**.

## Quick Install (One-Liner)

### Recommended (`curl`)
```bash
curl -fsSL https://raw.githubusercontent.com/NGxID18/LinuxSetup/main/install.sh | bash
```

### Alternative (`wget`)
```bash
wget -qO- https://raw.githubusercontent.com/NGxID18/LinuxSetup/main/install.sh | bash
```

## Manual Usage

```bash
git clone https://github.com/NGxID18/LinuxSetup.git
cd LinuxSetup
./install.sh
```

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
