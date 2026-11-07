#!/usr/bin/env bash
set -euo pipefail

echo "==> Installing NVIDIA driver, matching kernel headers & CUDA ($PKG | ${DISTRO:-$PKG})..."
case "$PKG" in
    apt)
        CURRENT_KERNEL="$(uname -r)"
        case "${DISTRO:-debian}" in
            ubuntu)
                sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                    "linux-headers-${CURRENT_KERNEL}" \
                    linux-headers-generic \
                    dkms \
                    build-essential \
                    || sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-generic dkms build-essential

                if command -v ubuntu-drivers >/dev/null 2>&1; then
                    sudo ubuntu-drivers install 2>/dev/null || sudo ubuntu-drivers autoinstall
                else
                    sudo DEBIAN_FRONTEND=noninteractive apt install -y nvidia-driver
                fi
                ;;

            debian|*)
                sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                    "linux-headers-${CURRENT_KERNEL}" \
                    linux-headers-amd64 \
                    dkms \
                    build-essential \
                    firmware-misc-nonfree \
                    || sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-headers-amd64 dkms build-essential firmware-misc-nonfree

                # Prefer Open Kernel DKMS for modern GPUs (Turing/Ampere/Ada/Blackwell), fallback to proprietary
                sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                    nvidia-kernel-open-dkms \
                    nvidia-driver \
                    nvidia-smi \
                    nvidia-settings \
                    || sudo DEBIAN_FRONTEND=noninteractive apt install -y \
                        nvidia-driver \
                        nvidia-smi
                ;;
        esac

        sudo DEBIAN_FRONTEND=noninteractive apt install -y \
            nvidia-persistenced \
            nvidia-cuda-toolkit \
            nvidia-vaapi-driver

        sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
        sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
        sudo update-initramfs -u
        ;;

    dnf)
        CURRENT_KERNEL="$(uname -r)"

        # Install matching kernel development headers & build dependencies for akmods
        sudo dnf install -y \
            "kernel-devel-${CURRENT_KERNEL}" \
            kernel-devel \
            kernel-headers \
            kmodtool \
            akmods \
            || sudo dnf install -y kernel-devel kernel-headers kmodtool akmods

        case "${DISTRO:-fedora}" in
            fedora)
                sudo dnf install -y rpmfusion-nonfree-release-tainted 2>/dev/null || true

                # Install NVIDIA Open driver, CUDA, VA-API acceleration, settings & power services
                sudo dnf install -y \
                    akmod-nvidia-open \
                    xorg-x11-drv-nvidia-cuda \
                    xorg-x11-drv-nvidia-power \
                    nvidia-settings \
                    nvidia-persistenced \
                    libva-nvidia-driver \
                    || sudo dnf install -y \
                        akmod-nvidia-open \
                        xorg-x11-drv-nvidia-cuda \
                        nvidia-persistenced \
                    || sudo dnf install -y \
                        akmod-nvidia \
                        xorg-x11-drv-nvidia-cuda \
                        nvidia-persistenced
                ;;

            rhel|*)
                sudo dnf install -y \
                    akmod-nvidia-open \
                    xorg-x11-drv-nvidia-cuda \
                    nvidia-persistenced \
                    || sudo dnf install -y \
                        akmod-nvidia \
                        xorg-x11-drv-nvidia-cuda \
                        nvidia-persistenced
                ;;
        esac

        # Enable power management & persistence services
        sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
        sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
        sudo systemctl enable nvidia-powerd.service 2>/dev/null || true

        # Force build kernel module and regenerate dracut initramfs
        sudo akmods --force || true
        sudo dracut --force || true

        # Secure Boot notice if enabled
        if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
            echo "==> [NOTICE] UEFI Secure Boot is active."
            echo "    If module loading is rejected, enroll MOK key using:"
            echo "    sudo kmodgenca && sudo mokutil --import /etc/pki/akmods/certs/public_key.der"
        fi
        ;;

    zypper)
        # Install matching openSUSE kernel headers
        sudo zypper --non-interactive --gpg-auto-import-keys install -y kernel-default-devel kernel-devel 2>/dev/null \
            || sudo zypper --non-interactive --gpg-auto-import-keys install -y kernel-devel || true

        # Add official openSUSE NVIDIA repo per distribution
        case "${DISTRO:-tumbleweed}" in
            tumbleweed)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y openSUSE-repos-Tumbleweed-NVIDIA 2>/dev/null || true
                if ! zypper repos 2>/dev/null | grep -qi "nvidia"; then
                    sudo zypper addrepo --refresh https://download.nvidia.com/opensuse/tumbleweed NVIDIA 2>/dev/null || true
                fi
                ;;

            leap|*)
                sudo zypper --non-interactive --gpg-auto-import-keys install -y openSUSE-repos-Leap-NVIDIA 2>/dev/null || true
                if ! zypper repos 2>/dev/null | grep -qi "nvidia"; then
                    sudo zypper addrepo --refresh 'https://download.nvidia.com/opensuse/leap/$releasever' NVIDIA 2>/dev/null || true
                fi
                ;;
        esac

        sudo zypper --non-interactive --gpg-auto-import-keys refresh

        # Prefer modern signed open kernel driver with automatic license agreement (-l / --auto-agree-with-licenses)
        sudo zypper --non-interactive --gpg-auto-import-keys install -y --auto-agree-with-licenses \
            nvidia-open-driver-G06-signed-kmp-meta \
            nvidia-userspace-meta-G06 \
            nvidia-compute-utils-G06 \
            nvidia-persistenced \
            nvidia-settings 2>/dev/null \
            || sudo zypper --non-interactive --gpg-auto-import-keys install -y --auto-agree-with-licenses \
                nvidia-open-driver-G06-signed-kmp-default \
                nvidia-compute-utils-G06 \
                nvidia-video-G06 \
                nvidia-gl-G06 \
                nvidia-persistenced 2>/dev/null \
            || sudo zypper --non-interactive --gpg-auto-import-keys install -y --auto-agree-with-licenses \
                nvidia-driver-G06-kmp-meta \
                nvidia-userspace-meta-G06 \
                nvidia-compute-utils-G06 \
                nvidia-persistenced \
                nvidia-settings 2>/dev/null \
            || sudo zypper --non-interactive --gpg-auto-import-keys install -y --auto-agree-with-licenses \
                x11-video-nvidiaG06 \
                nvidia-computeG06 \
                nvidia-persistenced

        sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
        sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
        sudo dracut --force 2>/dev/null || true

        # Secure Boot notice if enabled
        if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
            echo "==> [NOTICE] UEFI Secure Boot is active on openSUSE."
            echo "    If MokManager appears upon reboot, select 'Enroll MOK' to authorize the driver signature."
        fi
        ;;

    pacman)
        HEADERS=(dkms)
        for k in linux linux-zen linux-lts linux-hardened linux-cachyos; do
            if pacman -Qq "$k" >/dev/null 2>&1; then
                HEADERS+=("${k}-headers")
            fi
        done
        if [ "${#HEADERS[@]}" -eq 1 ]; then
            HEADERS+=(linux-headers)
        fi

        case "${DISTRO:-arch}" in
            cachyos)
                sudo pacman -S --needed --noconfirm \
                    "${HEADERS[@]}" \
                    nvidia-open-dkms \
                    nvidia-utils \
                    opencl-nvidia \
                    libva-nvidia-driver \
                    nvidia-settings \
                    cuda \
                    cudnn
                ;;

            arch|*)
                sudo pacman -S --needed --noconfirm \
                    "${HEADERS[@]}" \
                    nvidia-open-dkms \
                    nvidia-utils \
                    opencl-nvidia \
                    libva-nvidia-driver \
                    nvidia-settings \
                    cuda \
                    cudnn
                ;;
        esac

        sudo systemctl enable nvidia-persistenced.service 2>/dev/null || true
        sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service 2>/dev/null || true
        sudo mkinitcpio -P
        ;;
esac
