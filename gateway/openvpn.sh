#!/usr/bin/env bash

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
CONF_FILENAME=~/.openvpnrc
DEFAULT_GATEWAY=`cat $CONF_FILENAME 2>/dev/null | sed -n -e "s/^default:\s*//p"`

# initialize
if [ "$#" -eq 0 ] ; then
    GATEWAY=$DEFAULT_GATEWAY
elif [ "$#" -eq 1 ] ; then
    GATEWAY=$1
else
    echo "Usage: $0 [gateway]"
    echo
    echo "    Start OpenVPN (default gateway: $DEFAULT_GATEWAY)."
    exit 1
fi

# translate abbreviated gateway names
case `echo $GATEWAY | tr "[:upper:]" "[:lower:]"` in
    mel)
        GATEWAY="AU Melbourne" ;;
    syd)
        GATEWAY="AU Sydney" ;;
    nz)
        GATEWAY="New Zealand" ;;
    hk)
        GATEWAY="Hong Kong" ;;
    sg|sing)
        GATEWAY=Singapore ;;
    jp|jap|japan|tokyo)
        GATEWAY=Japan ;;
esac

# validate the gateway
if [ ! -f "/etc/openvpn/$GATEWAY.ovpn" ] ; then
    echo "ERROR: Invalid gateway: $GATEWAY"
    exit 1
fi

# check if OpenVPN is already running
if pgrep "openvpn" >/dev/null ; then
    echo "WARNING: OpenVPN is already running - killing it."
    pkill openvpn
fi

# start OpenVPN
echo "Starting OpenVPN: $GATEWAY"
openvpn \
    --cd /etc/openvpn/ \
    --config "$GATEWAY.ovpn" \
    --auth-user-pass auth --auth-nocache \
    --log /var/log/openvpn \
    --daemon
echo "default: $GATEWAY" >$CONF_FILENAME
