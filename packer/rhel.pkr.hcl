packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.0.0"
    }
  }
}

# ─── Variables ───────────────────────────────────────────────────────────────

variable "iso_url" {
  type    = string
  default = "/data/ISO/Linux/rhel-10.1-x86_64-dvd.iso"
}

variable "iso_checksum" {
  type    = string
  default = "5925e05c32d8324a72e146a29293d60707571817769de73df63eab8dbd6d3196"
}

variable "REDHAT_USERNAME" {
  type    = string
  default = env("REDHAT_USERNAME")
}

variable "REDHAT_PASSWORD" {
  type      = string
  default   = env("REDHAT_PASSWORD")
  sensitive = true
}

variable "password" {
  type      = string
  default   = env("MADMIN_PASSWORD")
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

source "qemu" "rhel10" {
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
    "linux /images/pxeboot/vmlinuz <wait5>",
    "inst.stage2=cdrom quite text <wait5>",
    "net.ifnames=0 biosdevname=0 systemd.unified_cgroup_hierarchy=1 <wait5>",
    "inst.ks=http://{{.HTTPIP}}:{{.HTTPPort}}/ks.cfg <wait5>",
    "---<enter><wait5>",
    "initrd /images/pxeboot/initrd.img<enter><wait5>",
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
  headless         = true

  # Kickstart content served inline — no external ks.cfg file required
  http_content = {
    "/ks.cfg" = <<-KICKSTART
      cdrom

      lang en_US.UTF-8
      keyboard us
      timezone --utc Etc/UTC

      text
      skipx

      firstboot --disabled
      firewall --disabled
      selinux --permissive

      network --device eth0 --bootproto dhcp --hostname=rhel.localdomain

      zerombr
      clearpart --all --initlabel --disklabel=gpt
      part biosboot --size=1 --fstype=biosboot
      part /boot --size=2048 --fstype=ext4
      part / --grow --fstype=ext4
      bootloader --timeout=1 --append="net.ifnames=0 biosdevname=0 systemd.unified_cgroup_hierarchy=1"

      services --enabled=sshd --disabled=cloud-init,cloud-init-local,cloud-config,cloud-final

      rootpw --plaintext ${var.REDHAT_PASSWORD}
      user --name=${var.REDHAT_USERNAME} --password=${var.REDHAT_PASSWORD} --plaintext --groups=wheel
      group --name=madmin --gid=1001
      user --name=madmin --password=${var.password} --plaintext --uid=1001 --gid=1001 --groups=madmin,wheel --homedir=/home/madmin --shell=/bin/bash
      authselect --useshadow --passalgo=sha512

      reboot

      %packages
      -sssd
      @core
      ca-certificates
      curl
      e2fsprogs
      iproute
      openssh-server
      python3
      qemu-guest-agent
      rsync
      sudo
      yum-utils
      %end

      %post --interpreter=/bin/bash
      # Allow wheel group passwordless sudo
      echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd
      chmod 0440 /etc/sudoers.d/wheel-nopasswd

      # Explicit passwordless sudo for madmin (redundant with wheel, but self-documenting)
      echo "madmin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/madmin
      chmod 0440 /etc/sudoers.d/madmin

      # madmin SSH directory
      mkdir -p /home/madmin/.ssh
      chmod 0700 /home/madmin/.ssh
      chown -R madmin:madmin /home/madmin

      # SSH hardening
      sed -ie "s/^[#[:space:]]*UseDNS.*$/UseDNS no/g" /etc/ssh/sshd_config
      ssh-keygen -A
      systemctl enable sshd.service

      # GRUB kernel command line
      sed -ie "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=\"0\"/g" /etc/default/grub
      sed -ie "s/^GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"net.ifnames=0 biosdevname=0 systemd.unified_cgroup_hierarchy=1\"/g" /etc/default/grub
      sed -ie "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"net.ifnames=0 biosdevname=0 systemd.unified_cgroup_hierarchy=1\"/g" /etc/default/grub
      grub2-mkconfig -o /boot/grub2/grub.cfg
      dracut -f
      exit 0
      %end
    KICKSTART
  }

  output_directory = "output-rhel10"

  ssh_username           = var.REDHAT_USERNAME
  ssh_password           = var.REDHAT_PASSWORD
  ssh_port               = 22
  ssh_read_write_timeout = "600s"
  ssh_timeout            = "120m"

  shutdown_command = "sudo shutdown -h now"

  vnc_bind_address = "0.0.0.0"
  vnc_port_min     = 5900
  vnc_port_max     = 6000
}

# ─── Build ───────────────────────────────────────────────────────────────────

build {
  sources = ["source.qemu.rhel10"]

  # provisioner "shell" {
  #   environment_vars = [
  #     "REDHAT_USERNAME=${var.REDHAT_USERNAME}",
  #     "REDHAT_PASSWORD=${var.REDHAT_PASSWORD}",
  #   ]
  #   inline = [
  #     "set -eu",
  #     "sudo sed -i 's/\\(def in_container():\\)/\\1\\n    return False/g' /usr/lib64/python*/*-packages/rhsm/config.py",
  #     "sudo subscription-manager register --username=$REDHAT_USERNAME --password=$REDHAT_PASSWORD",
  #     "echo 'zchunk=False' | sudo tee -a /etc/dnf/dnf.conf",
  #     "sudo yum makecache",
  #     "sudo yum update -y redhat-release",
  #     "sudo yum makecache",
  #     "sudo yum update -y",
  #     "sudo yum install -y --allowerasing ca-certificates curl gcc glibc-common glibc-langpack-en gnupg2 hostname iproute python3 sequoia-sq sudo yum-utils",
  #     "sudo yum install -y --allowerasing coreutils curl",
  #     "sudo yum install -y qemu-guest-agent",
  #   ]
  # }

  post-processor "shell-local" {
    inline = [
      "set -eu",
      "export _IMAGE=\"output-rhel10/rhel10.qcow2\"",
      "export LIBGUESTFS_BACKEND=direct",
      "sudo qemu-img convert -f qcow2 -O qcow2 \"$_IMAGE\" \"$_IMAGE.convert\" && sudo rm -rf \"$_IMAGE\"",
      "sudo chmod a+r /boot/vmlinuz*",
      "sudo LIBGUESTFS_BACKEND=direct virt-sysprep --operations defaults,machine-id,-ssh-userdir,-customize -a \"$_IMAGE.convert\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-customize --no-network -a \"$_IMAGE.convert\" --delete \"/var/lib/*/random-seed\" --delete \"/var/lib/wicked/*\" --firstboot-command \"ssh-keygen -A && systemctl restart ssh.service\"",
      "sudo LIBGUESTFS_BACKEND=direct virt-sparsify --in-place \"$_IMAGE.convert\"",
      "sudo qemu-img convert -f qcow2 -O qcow2 -c \"$_IMAGE.convert\" \"$_IMAGE\"",
      "sudo rm -rf \"$_IMAGE.convert\"",
    ]
  }
}
