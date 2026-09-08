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
  default = "/data/ISO/Linux/debian-13.6.0-amd64-netinst.iso"
}

variable "iso_checksum" {
  type    = string
  default = "65273beed27b2df543b68b65630ba525cfbad8df2b12035732b2dff87d6664e7"
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

source "qemu" "debian-13" {
  accelerator = "kvm"
  qemu_binary = "qemu-system-x86_64"
  qemuargs    = [["-cpu", "host"], ["-machine", "q35,accel=kvm"]]

  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  # DVD ISO: isolinux needs ~10s to initialise before the menu appears
  boot_wait = "3s"
  boot_command = [
    "<esc><esc><esc><esc><esc><esc><esc><esc><esc><esc><wait5>",
    "/install.amd/vmlinuz <wait> ",
    "initrd=/install.amd/initrd.gz <wait> ",
    "fb=false <wait> ",
    "auto-install/enable=true <wait> ",
    "cdrom-checker/start=false <wait> ",
    "debconf/priority=critical <wait> ", 
    "console-setup/ask_detect=false <wait> ",
    "debconf/frontend=noninteractive <wait> ",
    "net.ifnames=0 biosdevname=0 systemd.unified_cgroup_hierarchy=1 <wait>",
    "preseed/url=http://{{.HTTPIP}}:{{.HTTPPort}}/preseed.cfg <wait> ",
    "---<enter>",
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
  http_directory   = "${path.root}"
  output_directory = "output-debian-13"

  ssh_username                 = var.ssh_username
  ssh_password                 = var.ssh_password
  ssh_port                     = 22
  ssh_timeout                  = "120m"
  ssh_read_write_timeout       = "600s"
  temporary_key_pair_type      = "ed25519"
  # sh_disable_agent_forwarding = true

  shutdown_command = "sudo shutdown -h now"

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  name        = "debian-13"
  description = "Debian 13 (Trixie) Vagrant/libvirt base image"
  sources     = ["source.qemu.debian-13"]

  # Provisioner 1: System upgrade + base packages
  provisioner "shell" {
    inline = [
      "set -eu",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y",
      "sudo apt-get clean -y",
      "sudo apt-get autoremove -y --purge",
    ]
  }

  # Provisioner 2: Configure APT sources (DEB822 format)
  provisioner "shell" {
    inline = [
      "set -eu",
      "sudo rm -rf /etc/apt/sources.list*",
      "sudo mkdir -p /etc/apt/sources.list.d",
      "printf \"Components: main contrib non-free non-free-firmware\\nEnabled: yes\\nX-Repolib-Name: debian\\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\\nSuites: trixie trixie-updates\\nTypes: deb\\nURIs: http://deb.debian.org/debian\\n\" | sudo tee /etc/apt/sources.list.d/debian.sources > /dev/null",
      "printf \"Components: main contrib non-free non-free-firmware\\nEnabled: yes\\nX-Repolib-Name: debian-security\\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\\nSuites: trixie-security\\nTypes: deb\\nURIs: http://deb.debian.org/debian-security\\n\" | sudo tee /etc/apt/sources.list.d/debian-security.sources > /dev/null",
    ]
  }

  # Post-processor 1: Image cleanup and sysprep
  post-processor "shell-local" {
    inline = [
      "set -eu",
      "export _IMAGE=\"output-debian-13/packer-debian-13\"",
      "export LIBGUESTFS_BACKEND=direct",
      "sudo qemu-img convert -f qcow2 -O qcow2 \"$_IMAGE\" \"$_IMAGE.convert\" && sudo rm -rf \"$_IMAGE\"",
      "sudo chmod a+r /boot/vmlinuz*",
      "sudo LIBGUESTFS_BACKEND=direct virt-sysprep --operations defaults,machine-id,-ssh-userdir,-customize -a \"$_IMAGE.convert\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-customize --no-network -a \"$_IMAGE.convert\" --delete \"/var/lib/*/random-seed\" --firstboot-command \"ssh-keygen -A && systemctl restart sshd.service\"",
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
