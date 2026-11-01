# Universal Linux Provisioning

Minimalist provisioning scripts and dotfiles for **Debian/Ubuntu (`apt`)**, **RHEL/Fedora (`dnf`)**, and **Arch Linux (`pacman`)**.

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
    ├── gnome.sh
    ├── cockpit.sh
    ├── apps.sh
    ├── zram.sh
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

## Usage

```bash
./install.sh
```
