#!/usr/bin/env sh
set -euo pipefail

GATEWAYIP="192.168.50.250"
NETWORK="192.168.50.0/23"
NETWORK6="fd50::/8"
TIMEZONE="${1:-Europe/Warsaw}"
NTP_POOL0="${2:-0.pl.pool.ntp.org}"
NTP_POOL1="${3:-1.pl.pool.ntp.org}"

# DNS for FreeBSD

# Update and install packages
pkg update
pkg install -y unbound curl openssl nghttp2

# Network configuration in FreeBSD is typically done via /etc/rc.conf
# e.g., for interface em0:
# sysrc ifconfig_em0="inet 192.168.50.226 netmask 255.255.254.0"
# sysrc defaultrouter="192.168.50.250"

# Setup Timezone
tzsetup "${TIMEZONE}"

# Setup NTP
if ! grep -q "$NTP_POOL0" /etc/ntp.conf; then
sed -i '' -e "$(printf '1i\\\nserver %s iburst prefer' "$NTP_POOL0")" /etc/ntp.conf
sed -i '' -e "$(printf '1i\\\nserver %s iburst prefer' "$NTP_POOL1")" /etc/ntp.conf
fi

sysrc ntpd_enable="YES"
sysrc ntpd_sync_on_start="YES"

service ntpd stop 2>/dev/null || true
ntpdate "${NTP_POOL0}"
service ntpd start

# Enable HTTPS
if [ ! -f /usr/local/etc/ssl/myCA.key ]; then
mkdir -p /usr/local/etc/ssl
openssl genrsa -out /usr/local/etc/ssl/myCA.key 2048
openssl req -x509 -new -nodes -key /usr/local/etc/ssl/myCA.key -sha256 -days 1825 -subj '/CN=home.lab CA' -out /usr/local/etc/ssl/myCA.pem
openssl req -new -newkey rsa:2048 -nodes -keyout /usr/local/etc/ssl/mydomain.key -subj '/CN=home.lab' -out /usr/local/etc/ssl/mydomain.csr
openssl x509 -req -in /usr/local/etc/ssl/mydomain.csr -CA /usr/local/etc/ssl/myCA.pem -CAkey /usr/local/etc/ssl/myCA.key -CAcreateserial -out /usr/local/etc/ssl/mydomain.pem -days 1825 -sha256

chmod 600 /usr/local/etc/ssl/myCA.key /usr/local/etc/ssl/mydomain.key
chmod 644 /usr/local/etc/ssl/myCA.pem /usr/local/etc/ssl/mydomain.pem
fi

# Add Root hints
curl -fsSL https://www.internic.net/domain/named.cache -o /usr/local/etc/unbound/root.hints
chmod 644 /usr/local/etc/unbound/root.hints

# Initialize DNSSEC root trust anchor
/usr/local/sbin/unbound-anchor -a /usr/local/etc/unbound/root.key || true
chown unbound:unbound /usr/local/etc/unbound/root.key

# Configure Unbound
mv /usr/local/etc/unbound/unbound.conf /usr/local/etc/unbound/unbound.conf.orig || true
touch /usr/local/etc/unbound/unbound.conf

#New version of unbound.conf
cat << EOF > /usr/local/etc/unbound/unbound.conf
server:
        verbosity: 1
        log-queries: yes
        num-threads: 2
        num-queries-per-thread: 1024
        interface: 0.0.0.0
        interface: ::0
        interface: 0.0.0.0@443
        interface: ::0@443
        port: 53
        https-port: 443
        do-ip4: yes
        do-ip6: yes
        do-udp: yes
        do-tcp: yes
        so-sndbuf: 0
        so-rcvbuf: 0
        msg-cache-size: 32m
        rrset-cache-size: 64m
        prefetch: yes
        prefetch-key: yes
        serve-expired: yes
        hide-identity: yes
        hide-version: yes
        access-control: ${NETWORK} allow
        access-control: 127.0.0.0/8 allow
        access-control: ${NETWORK6} allow
        root-hints: "/usr/local/etc/unbound/root.hints"
        # Add DNSSEC
        auto-trust-anchor-file: "/usr/local/etc/unbound/root.key"
        # Add HTTPS
        tls-service-key: "/usr/local/etc/ssl/mydomain.key"
        tls-service-pem: "/usr/local/etc/ssl/mydomain.pem"
        harden-dnssec-stripped: yes
        harden-glue: yes
        qname-minimisation: yes
        harden-referral-path: no
        log-time-ascii: yes
        private-domain: "home.lab"
        local-zone: "home.lab" static
        domain-insecure: "home.lab"
        # local-data: "mu.tmnt.local. IN A 192.168.51.10"
        local-data: "sv-lambda. IN A 192.168.50.203"
        local-data: "privx.home.lab. IN A 192.168.50.230"
        local-data-ptr: "192.168.50.230 privx.home.lab"
        local-data-ptr: "192.168.50.203 sv-lambda"
# python:
# dynlib:
remote-control:
#forward-zone:
#        name: "."
#        forward-addr: 1.1.1.1
#        forward-addr: 9.9.9.9
EOF

chflags noschg /etc/resolv.conf 2>/dev/null || true
echo "nameserver 127.0.0.1" > /etc/resolv.conf
chflags schg /etc/resolv.conf

# Set preferred default route
sysrc defaultrouter="${GATEWAYIP}"
route change default "${GATEWAYIP}" 2>/dev/null || route add default "${GATEWAYIP}"

# Prevent other DHCP interfaces from overriding the default route.
# "supersede routers" forces dhclient on every interface to always use
# our gateway, ignoring whatever the DHCP server hands out.
# Replace vtnet1 with the interface name that should NOT control the route.
cat >> /etc/dhclient.conf << EOF

# Prevent DHCP from changing the default gateway
supersede routers ${GATEWAYIP};
EOF

# Firewall configuration using PF
touch /etc/pf.conf
cat << EOF > /etc/pf.conf
# Note: change ext_if to your WAN/external interface (e.g., igb0, vtnet0)
ext_if="vtnet1"
# int_if: internal/LAN interface - all traffic allowed (change if needed)
int_if="vtnet0"

# Always allow loopback - required for Unbound (127.0.0.1) and local services
pass quick on lo0 all

# Allow all traffic on internal interface
pass quick on \$int_if all

# Default behavior: pass out all traffic on external interface, keep state
pass out on \$ext_if all

# By default block incoming on external interface
block in on \$ext_if all

# Allow SSH from 192.168.0.0/16 (IPv4)
pass in quick on \$ext_if inet proto tcp from 192.168.0.0/16 to any port 22

# Allow DNS from 192.168.50.0/23 (IPv4)
pass in quick on \$ext_if inet proto udp from ${NETWORK} to any port 53
pass in quick on \$ext_if inet proto tcp from ${NETWORK} to any port 53
pass in quick on \$ext_if inet proto tcp from ${NETWORK} to any port 443

# Allow DNS from fd50::/8 (IPv6)
pass in quick on \$ext_if inet6 proto udp from ${NETWORK6} to any port 53
pass in quick on \$ext_if inet6 proto tcp from ${NETWORK6} to any port 53
pass in quick on \$ext_if inet6 proto tcp from ${NETWORK6} to any port 443

# Uncomment for IPv6 SSH
# pass in quick on \$ext_if inet6 proto tcp from 2001:db8::/32 to any port 22
EOF

sysrc pf_enable="YES"
service pf restart || service pf start

# Enable and start Unbound
sysrc unbound_enable="YES"
unbound-checkconf /usr/local/etc/unbound/unbound.conf
service unbound restart || service unbound start

# Check DNS over HTTPS:
# curl -v --doh-url https://127.0.0.1/dns-query --doh-insecure -I https://cloudflare.com

# Check DNSSEC from other host
# dig @192.168.50.242 cloudflare.com +dnssec