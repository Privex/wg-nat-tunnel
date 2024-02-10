#!/usr/bin/env bash
##################################################
#
#    --- FRONT SERVER ---
#
# This config is to be put on the FRONT server
# Place in /etc/wireguard/up.sh
# then run: chmod +x /etc/wireguard/up.sh
##################################################

set -o xtrace

(( $# > 1 )) && IFACE="$1" || IFACE="wg0"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: ${CONF_FILE="${DIR}/config.env"}

if [[ ! -f "$CONF_FILE" ]]; then
    >&2 echo " [!!!] ERROR: Config file $CONF_FILE is missing! Please create it!"
    exit 4
fi
source "$CONF_FILE"

sysctl -w net.ipv4.ip_forward=1

iptables -I FORWARD -i "$IFACE" -j ACCEPT
iptables -I FORWARD -o "$IFACE" -j ACCEPT
ip6tables -I FORWARD -i "$IFACE" -j ACCEPT
ip6tables -I FORWARD -o "$IFACE" -j ACCEPT

iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -t mangle -A POSTROUTING -o "$IFACE" -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
iptables -t mangle -A POSTROUTING -o "$OUTFACE" -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
ip6tables -t mangle -A POSTROUTING -o "$IFACE" -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
ip6tables -t mangle -A POSTROUTING -o "$OUTFACE" -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

if (( NAT_OUT )); then
    iptables -t nat -I POSTROUTING -o "$OUTFACE" -j MASQUERADE
fi
if (( NAT_IN )); then
    for p in "${EXCL_PORTS[@]}"; do
        iptables -t nat -A PREROUTING -i "$OUTFACE" -p tcp --dport "$p" -j RETURN
        iptables -t nat -A PREROUTING -i "$OUTFACE" -p udp --dport "$p" -j RETURN
    done
    iptables -t nat -A PREROUTING -i "$OUTFACE" -d "$MY_IP" -j DNAT --to-destination "$DST_IP"
fi
iptables -A FORWARD -j DROP

echo " [+++] Added iptables rules!"
exit 0

