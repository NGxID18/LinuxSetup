# Cockpit Web Console Auto-Installer

Automated, lightweight, and universal installer for **Cockpit Web Console** and its companion modules across **Debian/Ubuntu (`apt`)**, **Fedora/RHEL (`dnf`)**, and **Arch Linux (`pacman`)**.

This branch (`Cockpit`) focuses exclusively on Cockpit, its management modules, performance monitoring, and filesystem utilities without altering desktop environments, drivers, or general system dotfiles.

---

## Quick Install (One-Liner)

### Recommended (`curl`)
```bash
curl -fsSL https://raw.githubusercontent.com/NGxID18/LinuxSetup/Cockpit/install.sh | bash
```

### Alternative (`wget`)
```bash
wget -qO- https://raw.githubusercontent.com/NGxID18/LinuxSetup/Cockpit/install.sh | bash
```

### Non-Interactive (Unattended)
```bash
curl -fsSL https://raw.githubusercontent.com/NGxID18/LinuxSetup/Cockpit/install.sh | bash -s -- -y
```

---

## Manual Usage

```bash
git clone -b Cockpit https://github.com/NGxID18/LinuxSetup.git
cd LinuxSetup
./install.sh
```

---

## Included Features & Modules

| Module / Component | Description |
| :--- | :--- |
| **Cockpit Core** | Lightweight web-based graphical interface for Linux systems. |
| **Storage Management** | Disk, partition, RAID, LVM2, and Btrfs tools via `cockpit-storaged` and `udisks2`. |
| **Containers** | Podman container management via `cockpit-podman`. |
| **Virtual Machines** | KVM / QEMU virtual machine management via `cockpit-machines`. |
| **File Browser** | File navigation and management via `cockpit-files`. |
| **Network Management** | Network interfaces, bridges, and bonding via `cockpit-networkmanager`. |
| **Software Updates** | OS update manager via `cockpit-packagekit` (and `cockpit-pacman` on Arch). |
| **Metrics & Performance** | Historical CPU/RAM/Disk performance charts via Performance Co-Pilot (`pcp`). |
| **Btrfs Manager** | Custom Btrfs snapshot & subvolume manager ([NGxID18/btrfs-manager](https://github.com/NGxID18/btrfs-manager)). |
| **Firewall Setup** | Automatically opens TCP port `9090` in `firewalld` or `ufw` if active. |

---

## Repository Structure

```text
.
├── README.md
├── install.sh
└── script/
    ├── repository.sh   # Configures repository prerequisites
    ├── cockpit.sh      # Installs Cockpit, modules, permissions & services
    └── verify.sh       # Verifies installed packages, sockets, and access URLs
```

---

## Accessing Cockpit

Once installation is complete:
1. Open your web browser and navigate to:
   * **Local:** `https://localhost:9090`
   * **Remote:** `https://<server-ip>:9090`
2. Accept the self-signed SSL certificate notice (if first time).
3. Log in using your existing Linux user account and password.
