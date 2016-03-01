#!/usr/bin/env bash

# This script sets up firewall rules.
# Full tutorial is here: http://awasu.com/weblog/bpi-gateway/firewall/
#
# NOTE: If you are making changes to this script, you should remove 
# the invocation of it from /etc/rc.local, so that if you accidentally 
# lock yourself out, a reboot will let you back in.

# COPYRIGHT:   (c) Awasu Pty. Ltd. 2016 (all rights reserved).
#              Unauthorized use of this code is prohibited.
#
# LICENSE:     This software is provided 'as-is', without any express
#              or implied warranty.
#
#              In no event will the author be held liable for any damages
#              arising from the use of this software.
#
#              Permission is granted to anyone to use this software
#              for any purpose, and to alter it and redistribute it freely, 
#              subject to the following restrictions:
#
#              - The origin of this software must not be misrepresented;
#                you must not claim that you wrote the original software.
#                If you use this software, an acknowledgement is requested
#                but not required.
#
#              - Altered source versions must be plainly marked as such,
#                and must not be misrepresented as being the original software.
#                Altered source is encouraged to be submitted back to
#                the original author so it can be shared with the community.
#                Please share your changes.
#
#              - This notice may not be removed or altered from any
#                source distribution.

# ---------------------------------------------------------------------

# initialize
LOCAL_INTERFACE=eth0 # local network (wired)
LOCAL_WIFI_INTERFACE=wlan1 # local network (wifi)
EXTERNAL_INTERFACE=wlan0 # internet access (via wifi)
VPN_INTERFACE=tun0 # VPN access

# parse the command-line arguments
if [ "$#" -ne 1 ] ; then
    echo "Usage: $0 [vpn|novpn|disable]"
    echo
    echo "   Configure the firewall."
    exit 1
fi
REAL_EXTERNAL_INTERFACE=$EXTERNAL_INTERFACE
if [ "$1" == "vpn" ] ; then
    # we will be using a VPN - send all output through it
    EXTERNAL_INTERFACE=$VPN_INTERFACE
else
    # no VPN - make sure OpenVPN is not running
    if pgrep "openvpn" >/dev/null ; then
        echo "WARNING: OpenVPN is running - killing it."
        pkill openvpn
    fi
    if [ "$1" == "novpn" ] ; then
        :
    elif [ "$1" == "disable" ] ; then
        # reset everything (default policy: accept)
        echo "Clearing all firewall rules."
        iptables --flush
        iptables --delete-chain
        iptables -P INPUT ACCEPT
        iptables -P OUTPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -t nat --flush
        iptables -t nat --delete-chain
        iptables -t nat -A POSTROUTING -o $EXTERNAL_INTERFACE -j MASQUERADE
        exit 0
    else
        echo "Invalid argument: $1"
        exit 1
    fi
fi
echo "Configuring the firewall to use '$EXTERNAL_INTERFACE'."

# reset everything (default policy: drop)
# NOTE: This script hangs here the first time it is run from the console,
# if it has been disabled in /etc/rc.local, although pressing ENTER wakes it up.
# I suspect this is because the first time around, there are no firewall rules,
# so setting the DROP policy causes the response packets to be lost. 
# Running it again, there are rules in place to allow response packets, 
# so things work OK. Everything works if we run it at startup (in /etc/rc.local),
# so it's not a big deal.
iptables --flush
iptables --delete-chain
iptables -P INPUT DROP
iptables -P OUTPUT DROP
iptables -P FORWARD DROP

# always allow responses
iptables -A INPUT   -p tcp -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT  -p tcp -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -p tcp -m state --state RELATED,ESTABLISHED -j ACCEPT

# always allow loopback
iptables -A INPUT  -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# always allow ICMP (important!)
iptables -A INPUT   -p icmp -j ACCEPT
iptables -A OUTPUT  -p icmp -j ACCEPT
iptables -A FORWARD -p icmp -j ACCEPT

# allow outgoing DNS
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A INPUT  -p udp --sport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -m state --state NEW -j ACCEPT

# allow incoming DNS
iptables -A INPUT  -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p udp --sport 53 -j ACCEPT
iptables -A INPUT  -p tcp --dport 53 -m state --state NEW -j ACCEPT

# allow DHCP
iptables -I INPUT  -i $LOCAL_INTERFACE -p udp --dport 67:68 --sport 67:68 -j ACCEPT
iptables -I OUTPUT -o $LOCAL_INTERFACE -p udp --dport 67:68 --sport 67:68 -j ACCEPT
iptables -I INPUT  -i $LOCAL_WIFI_INTERFACE -p udp --dport 67:68 --sport 67:68 -j ACCEPT
iptables -I OUTPUT -o $LOCAL_WIFI_INTERFACE -p udp --dport 67:68 --sport 67:68 -j ACCEPT
     
# allow incoming SSH
# NOTE: We allow ESTABLISHED connections, just to be sure!
iptables -A INPUT  -i $LOCAL_INTERFACE -p tcp --dport 22 -m state --state NEW,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -o $LOCAL_INTERFACE -p tcp --sport 22 -m state --state ESTABLISHED -j ACCEPT

# allow HTTP (for the pixel server)
iptables -A INPUT  -i $LOCAL_INTERFACE -p tcp --dport 80 -m state --state NEW -j ACCEPT

# allow incoming SMTP (for email relaying)
iptables -A INPUT  -i $LOCAL_INTERFACE -p tcp --dport 25 -m state --state NEW -j ACCEPT

# allow selected services
PORTS=http,https
iptables -A OUTPUT -p tcp -m multiport --dports $PORTS -m state --state NEW -j ACCEPT
PORTS=ntp
iptables -A OUTPUT -p udp -m multiport --dports $PORTS -j ACCEPT
iptables -A INPUT  -p udp -m multiport --sports $PORTS -j ACCEPT

# enable NAT for selected services
# nb: NAT requires net.ipv4.ip_forward to be enabled in /etc/sysctl.conf
iptables -t nat --flush
iptables -t nat --delete-chain
iptables -t nat -A POSTROUTING -o $EXTERNAL_INTERFACE -j MASQUERADE
PORTS=http,https,pop3,pop3s,imap,imaps,smtp,smtps,587,ssh,ftp # nb: TCP services for the LAN
iptables -A FORWARD \
    -i $LOCAL_INTERFACE -o $EXTERNAL_INTERFACE \
    -p tcp -m multiport --dports $PORTS \
    -m state --state NEW \
    -j ACCEPT
PORTS=ntp # nb: UDP services for the LAN
iptables -A FORWARD \
    -i $LOCAL_INTERFACE -o $EXTERNAL_INTERFACE \
    -p udp -m multiport --dports $PORTS \
    -j ACCEPT
iptables -A FORWARD \
    -i $EXTERNAL_INTERFACE -o $LOCAL_INTERFACE \
    -p udp -m multiport --sports $PORTS \
    -j ACCEPT
PORTS=http,https # nb: TCP services for the internal WiFi network
iptables -A FORWARD \
    -i $LOCAL_WIFI_INTERFACE -o $EXTERNAL_INTERFACE \
    -p tcp -m multiport --dports $PORTS \
    -m state --state NEW \
    -j ACCEPT

# allow OpenVPN
if [ "$EXTERNAL_INTERFACE" == "$VPN_INTERFACE" ] ; then
    iptables -A OUTPUT -o $REAL_EXTERNAL_INTERFACE -p udp --dport 1194 -j ACCEPT
    iptables -A INPUT  -i $REAL_EXTERNAL_INTERFACE -p udp --sport 1194 -j ACCEPT
fi

# create a chain that logs packets, then drops them
iptables -N LOGDROP
iptables -A LOGDROP -m state --state INVALID -j DROP # nb: to avoid logging
# nb: the first "limit-burst" packets will be logged, then only "limit" per minute
iptables -A LOGDROP \
    -m limit --limit-burst 10 --limit 10/m \
    -j LOG --log-prefix "iptables: "
iptables -A LOGDROP -i $LOCAL_INTERFACE -j REJECT
iptables -A LOGDROP -i $LOCAL_WIFI_INTERFACE -j REJECT
iptables -A LOGDROP -j DROP

# log and drop any remaining packets (nb: this must appear last)
iptables -A INPUT   -j LOGDROP
iptables -A OUTPUT  -j LOGDROP
iptables -A FORWARD -j LOGDROP

# check if we should start OpenVPN
if [ "$EXTERNAL_INTERFACE" == "$VPN_INTERFACE" ] ; then
    `dirname $0`/openvpn.sh
fi
