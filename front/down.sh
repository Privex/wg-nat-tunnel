#!/usr/bin/env bash
##################################################
#
#    --- FRONT SERVER ---
#
# This config is to be put on the FRONT server
# Place in /etc/wireguard/down.sh
# then run: chmod +x /etc/wireguard/down.sh
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

sysctl -w net.ipv4.ip_forward=0

iptables -D FORWARD -i "$IFACE" -j ACCEPT
iptables -D FORWARD -o "$IFACE" -j ACCEPT
ip6tables -D FORWARD -i "$IFACE" -j ACCEPT
ip6tables -D FORWARD -o "$IFACE" -j ACCEPT

iptables -D INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -D INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
ip6tables -D FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -t mangle -D POSTROUTING -o "$IFACE" -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
iptables -t mangle -D POSTROUTING -o "$OUTFACE" -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
ip6tables -t mangle -D POSTROUTING -o "$IFACE" -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
ip6tables -t mangle -D POSTROUTING -o "$OUTFACE" -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

if (( NAT_OUT )); then
    iptables -t nat -D POSTROUTING -o "$OUTFACE" -j MASQUERADE
fi
if (( NAT_IN )); then
    iptables -t nat -D PREROUTING -i "$OUTFACE" -d "$MY_IP" -j DNAT --to-destination "$DST_IP"
    for p in "${EXCL_PORTS[@]}"; do
        iptables -t nat -D PREROUTING -i "$OUTFACE" -p tcp --dport "$p" -j RETURN
        iptables -t nat -D PREROUTING -i "$OUTFACE" -p udp --dport "$p" -j RETURN
    done
fi
iptables -D FORWARD -j DROP

echo " [+++] Removed iptables rules!"
exit 0

