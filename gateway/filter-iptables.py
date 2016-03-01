#!/usr/bin/python

# This script extracts key information from the iptables log file.
# Full tutorial is here: http://awasu.com/weblog/bpi-gateway/firewall/
#
# To process the entire log file:
#   sudo filter-iptables.py </var/log/iptables
#
# Or to monitor the log file in real-time:
#   sudo tail -f /var/log/iptables | filter-iptables.py

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

import sys
import os
import re
import time

# ---------------------------------------------------------------------

# This table defines log messages we want to filter out.
IGNORE_RULES = [
    { "proto": "UDP" , "in": "eth0" , "dpt": (137,138) } , # NetBIOS
    { "proto": "UDP" , "out": "eth0" , "dpt": (137,138) } , # NetBIOS
    { "proto": "UDP" , "in": "eth0" , "dpt": (67,68) } , # DHCP
    { "proto": "UDP" , "out": "eth0" , "dpt": (67,68) } , # DHCP
    { "proto": "UDP" , "in": "wlan1" , "dpt": (67,68) } , # DHCP
    { "proto": "UDP" , "out": "wlan1" , "dpt": (67,68) } , # DHCP
]

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

def check_rule( rule , vals ) :
    """ Check if an ignore rule matches a log message. """
    for val_name,target_vals in rule.items() :
        if not vals.has_key( val_name ) :
            return False
        if type(target_vals) not in (tuple,list) :
            target_vals = [ target_vals ]
        target_vals = [ str(v) for v in target_vals ]
        if vals[val_name] not in target_vals :
            return False
    return True

# ---------------------------------------------------------------------

def make_addr( ip_addr , port_no ) :
    if ip_addr and port_no :
        return ip_addr + ":" + port_no
    if ip_addr :
        return ip_addr
    if port_no :
        return ":" + port_no
    return ""

# ---------------------------------------------------------------------

while True :

    # read the next line
    line_buf = sys.stdin.readline()
    if not line_buf : break
    vals = { mo.group(1).lower(): mo.group(2) for mo in re.finditer( "([A-Z]+?)=(\S*)" , line_buf ) }
    vals["_timestamp_"] = line_buf[:15]
    vals["_src_"] = make_addr( vals.get("src") , vals.get("spt") )
    vals["_dest_"] = make_addr( vals.get("dst") , vals.get("dpt") )

    # filter out entries we're not interested in
    if any( check_rule(r,vals) for r in IGNORE_RULES ) :
        continue

    # output the next line
    print "{_timestamp_} | proto={proto:4} in={in:5} out={out:5} src={_src_:21} dest={_dest_:21}".format( **vals )
