# Awasu channel plugin that monitors your IP address.

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

import requests
import time
import md5
import xml.sax.saxutils

# get the IP info
ipinfo = requests.get( "http://ipinfo.io" ).json()

# generate the feed
summary = ipinfo["ip"] \
          + ": " + ", ".join( ipinfo[k] for k in ("city","region","country") if ipinfo[k] ) \
          + " ({})".format( ipinfo["org"] )
print "<feed xmlns='http://www.w3.org/2005/Atom' xmlns:xhtml='http://www.w3.org/1999/xhtml'>"
print "<link href='http://ipinfo.io' />"
print "<title> IP Info </title>"
print "<entry>"
print "<id> {} </id>".format( md5.new( summary ).hexdigest() )
print "<updated> {} </updated>".format( time.strftime( "%Y-%m-%dT%H:%M:%SZ" , time.gmtime() ) )
print "<title> {} </title>".format( xml.sax.saxutils.escape( summary ) )
print "<content type='xhtml'> <xhtml:div>"
print "<table>"
for key,val in ipinfo.iteritems() :
    print "<tr> <td> {}: </td> <td> <em>{}</em> </td> </tr>".format(
        key , 
        xml.sax.saxutils.escape( val )
    )
print "</table>"
print "</xhtml:div> </content>"
print "</entry>"
print "</feed>"
