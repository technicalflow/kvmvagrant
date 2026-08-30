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
  # default = "/data/ISO/Linux/ubuntu-24.04.4-server-amd64.iso"
  default = "http://releases.ubuntu.com/24.04.4/ubuntu-24.04.4-live-server-amd64.iso"
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

# ─── Builder ─────────────────────────────────────────────────────────────────

source "qemu" "ubuntu-24-04" {
  accelerator  = "kvm"
  qemu_binary  = "qemu-system-x86_64"
  qemuargs     = [["-cpu", "host"]]

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  boot_wait = "1s"
  boot_command = [
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "<tab><tab><tab><tab><tab><tab><tab><tab><tab><tab><wait>",
    "c<wait5>",
    "set gfxpayload=keep<enter><wait5>",
    "linux /casper/vmlinuz <wait5>",
    "autoinstall quiet fsck.mode=skip noprompt <wait5>",
    "net.ifnames=0 biosdevname=0 systemd.unified_cgroup_hierarchy=1 <wait5>",
    "ds=\"nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/\" <wait5>",
    "---<enter><wait5>",
    "initrd /casper/initrd<enter><wait5>",
    "boot<enter>",
  ]

  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size

  disk_cache       = "writeback"
  disk_compression = true
  disk_image       = false
  disk_interface   = "virtio"
  format           = "qcow2"
  net_device       = "virtio-net"
  headless          = true
  http_directory    = "./"
  output_directory  = "output-ubuntu-24-04"

  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_port               = 22
  ssh_timeout            = "120m"
  ssh_read_write_timeout = "600s"

  shutdown_command = "sudo shutdown -h now"

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  sources = ["source.qemu.ubuntu-24-04"]

  # Provisioner 1: System upgrade + base packages
  provisioner "shell" {
    inline = [
      "set -eu",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get remove --purge usbmuxd usb-modeswitch* modemmanager open-vm-tools -y",
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
      "export _IMAGE=\"output-ubuntu-24-04/packer-ubuntu-24-04\"",
      "export LIBGUESTFS_BACKEND=direct",
      "sudo qemu-img convert -f qcow2 -O qcow2 \"$_IMAGE\" \"$_IMAGE.convert\" && sudo rm -rf \"$_IMAGE\"",
      "sudo chmod a+r /boot/vmlinuz*",
      "sudo LIBGUESTFS_BACKEND=direct virt-sysprep --operations defaults,machine-id,-ssh-userdir,-customize -a \"$_IMAGE.convert\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-customize --no-network -a \"$_IMAGE.convert\" --delete \"/var/lib/*/random-seed\" --delete \"/var/lib/wicked/*\" --firstboot-command \"ssh-keygen -A && systemctl restart sshd.service\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-sparsify --in-place \"$_IMAGE.convert\"",
      "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$_IMAGE.convert\" \"$_IMAGE\"",
      "sudo rm -rf \"$_IMAGE.convert\"",
    ]
  }

  # Post-processor 2: Package as Vagrant box
  post-processor "vagrant" {
    compression_level   = 9
    keep_input_artifact = true
    output              = "output-vagrant/package.box"
    provider_override   = "libvirt"
  }
}
