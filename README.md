# Cockpit Installer

Minimal bash script to install Cockpit and default modules (`storaged`, `networkmanager`) on Linux.

## Install

### One-liner (curl)
```bash
curl -fsSL https://raw.githubusercontent.com/NGxID18/LinuxSetup/Cockpit/install.sh | bash
```

### One-liner (wget)
```bash
wget -qO- https://raw.githubusercontent.com/NGxID18/LinuxSetup/Cockpit/install.sh | bash
```

### Manual
```bash
git clone -b Cockpit https://github.com/NGxID18/LinuxSetup.git
cd LinuxSetup
./install.sh
```

Pass `-y` for non-interactive / unattended installation.

## Supported Distros

- **openSUSE** (Leap / Tumbleweed)
- **Fedora / RHEL**
- **Debian / Ubuntu**
- **Arch Linux**

## Included Packages

- `cockpit`
- `cockpit-storaged` (`udisks2`)
- `cockpit-networkmanager`
- `cockpit-selinux` (Fedora / RHEL only)

Enables `cockpit.socket` and opens port `9090` in `firewalld` or `ufw` if active.

## Access

Open your browser:
- `https://localhost:9090`
- `https://<server-ip>:9090`

Log in using your system username and password.
