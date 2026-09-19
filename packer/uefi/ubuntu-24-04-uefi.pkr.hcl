packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.0.0"
    }
    vagrant = {
      source  = "github.com/hashicorp/vagrant"
      version = ">= 1.0.0"
    }
  }
}

# ─── Variables ───────────────────────────────────────────────────────────────

variable "iso_url" {
  type    = string
  default = "/data/ISO/Linux/ubuntu-24.04.4-server-amd64.iso"
  # default = "http://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-live-server-amd64.iso"
}

variable "iso_checksum" {
  type    = string
  default = "e907d92eeec9df64163a7e454cbc8d7755e8ddc7ed42f99dbc80c40f1a138433"
}

variable "ssh_username" {
  type    = string
  default = "vagrant"
}

variable "ssh_password" {
  type      = string
  default   = "vagrant"
  sensitive = true
}

variable "disk_size" {
  type    = string
  default = "32768M"
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = number
  default = 4096
}

# Path to OVMF firmware files (adjust to match your distro's package location).
# Fedora/RHEL:  /usr/share/edk2/x64/OVMF_CODE.fd  /usr/share/edk2/x64/OVMF_VARS.fd
# Debian/Ubuntu: /usr/share/OVMF/OVMF_CODE_4M.fd   /usr/share/OVMF/OVMF_VARS_4M.fd
variable "ovmf_code" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_CODE.fd"
}

variable "ovmf_vars" {
  type    = string
  default = "/usr/share/edk2/ovmf/OVMF_VARS.fd"
}

# ─── Builder ─────────────────────────────────────────────────────────────────

source "qemu" "ubuntu-24-04-uefi" {
  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"

  # ── UEFI firmware ──────────────────────────────────────────────────────────
  # OVMF_CODE is opened read-only; OVMF_VARS is copied to a temp file by
  # QEMU so each build starts with a clean NVRAM state.
  qemuargs = [
    ["-cpu", "host"],
    ["-machine", "q35,accel=kvm"],
    ["-global", "driver=cfi.pflash01,property=secure,value=off"],
  ]
  efi_boot          = true
  efi_firmware_code = var.ovmf_code
  efi_firmware_vars = var.ovmf_vars
  
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # ── Boot command ───────────────────────────────────────────────────────────
  # UEFI GRUB presents a graphical menu. We press 'e' to edit the first entry,
  # navigate to the end of the linux line, append kernel parameters, then
  # Ctrl-X to boot.
  boot_wait = "5s"
#  boot_command     = ["<wait>e<wait5>", "<down><wait><down><wait><down><wait2><end><wait5>", "<bs><bs><bs><bs><wait> autoinstall ds=\"nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\" ---<wait><f10>"]

  boot_command = [
    "<wait3>c<wait3>",
    "search --file --set=root /casper/vmlinuz<enter><wait3>",
    "linux /casper/vmlinuz autoinstall ds=nocloud quiet fsck.mode=skip noprompt ---<enter><wait3>",
    "initrd /casper/initrd<enter><wait3>",
    "boot<enter>"
  ]

  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size

  disk_cache       = "writeback"
  disk_compression = false
  disk_image       = false
  disk_interface   = "virtio"
  format           = "qcow2"
  net_device       = "virtio-net"
  headless         = true
  cd_files = [
    "meta-data",
    "user-data"
  ]
  cd_label         = "CIDATA"
  output_directory = "output-ubuntu-24-04-uefi"

  ssh_username            = var.ssh_username
  ssh_password            = var.ssh_password
  ssh_port                = 22
  ssh_timeout             = "120m"
  ssh_read_write_timeout  = "600s"
  temporary_key_pair_type = "ed25519"

  shutdown_command = "sudo shutdown -h now"

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  sources = ["source.qemu.ubuntu-24-04-uefi"]

  # Provisioner 1: System upgrade + base packages
  provisioner "shell" {
    inline = [
      "set -eu",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get remove --purge usbmuxd usb-modeswitch* modemmanager open-vm-tools -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y",
    ]
  }

  # Provisioner 2: Configure APT sources (DEB822 format)
  provisioner "shell" {
    inline = [
      "set -eu",
      "sudo rm -rf /etc/apt/sources.list*",
      "sudo mkdir -p /etc/apt/sources.list.d",
      "printf 'Components: main universe restricted multiverse\\nEnabled: yes\\nX-Repolib-Name: ubuntu\\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\\nSuites: noble noble-updates noble-backports\\nTypes: deb\\nURIs: http://archive.ubuntu.com/ubuntu\\n' | sudo tee /etc/apt/sources.list.d/ubuntu.sources > /dev/null",
      "printf 'Components: main universe restricted multiverse\\nEnabled: yes\\nX-Repolib-Name: ubuntu-security\\nSigned-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg\\nSuites: noble-security\\nTypes: deb\\nURIs: http://security.ubuntu.com/ubuntu\\n' | sudo tee /etc/apt/sources.list.d/ubuntu-security.sources > /dev/null",
    ]
  }

  # Post-processor 1: Image cleanup and sysprep
  post-processor "shell-local" {
    inline = [
      "set -eu",
      "export _IMAGE=\"output-ubuntu-24-04-uefi/packer-ubuntu-24-04-uefi\"",
      "export LIBGUESTFS_BACKEND=direct",
      "sudo qemu-img convert -f qcow2 -O qcow2 \"$_IMAGE\" \"$_IMAGE.convert\" && sudo rm -rf \"$_IMAGE\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-sysprep --operations defaults,machine-id,-ssh-userdir,-customize -a \"$_IMAGE.convert\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-customize --no-network -a \"$_IMAGE.convert\" --delete \"/var/lib/*/random-seed\" --delete \"/var/lib/wicked/*\" --firstboot-command \"ssh-keygen -A && systemctl restart sshd.service && grub-editenv - set boot_success=1 && grub-editenv - unset recordfail\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-sparsify --in-place \"$_IMAGE.convert\"",
      "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$_IMAGE.convert\" \"$_IMAGE\"",
      "sudo rm -rf \"$_IMAGE.convert\""
    ]
  }

  # Post-processor 2: Package as Vagrant box
  post-processor "vagrant" {
    compression_level   = 9
    keep_input_artifact = true
    output              = "output-vagrant/package-uefi.box"
    provider_override   = "libvirt"
  }
}
