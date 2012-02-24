#!/bin/bash
### BEGIN INIT INFO
# Provides:          custom firewall
# Required-Start:    $remote_fs $syslog $network
# Required-Stop:     $remote_fs $syslog $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: firewall initscript
# Description:       Custom Firewall
### END INIT INFO
######################################
# Script to setup/reset iptables rules
# Author: killman@openwebtech.fr
# Date: 24/02/2012
######################################
##########################
#------Variables---------
##########################
SCRIPTNAME=`basename $0`

##########################
#------Functions----------
##########################
print_usage(){
echo -e "USAGE: $SCRIPTNAME start|stop|save\n"
exit 0
}
flush_tables(){
echo -e "Flushing iptables rules....\n"
# Stuff to flush iptable rules #
iptables -F  #flush every rules (generic)
iptables -X  #erase each chains (INPUT,OUTPOUT,FORW..) (generic)
iptables -t nat -F #idem for nat table
iptables -t nat -X #idem for nat table
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo -e "Flushing done!\n"
exit 0
}

save_rules(){
 	while [[ ($answer != "n|y") ]]
 	do
 		case "$answer" in
 			
 			y)
 				echo -e "Saving rules and set startup ...\n"
 				/sbin/iptables-save > /etc/iptables.up.rules
 				if [[ ! -f "/etc/network/if-pre-up.d/iptables" ]]
 				then
 				 					echo -e '
 #!/bin/bash 
/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
					chmod +x /etc/network/if-pre-up.d/iptables
 					echo "Iptables rules saved."
 					exit 0
 				else
 					echo "Iptables rules saved."
 					exit 0
 				fi	
 				
 			;;
 			
 			n)
 				echo "Saving Iptables rules aborted."
 				exit 1
 			;;
 				
 			*)
 				echo -e "Do you want to erase existing rules ? y/n \n"
 				read answer
 			;;
 		esac
 	done
}

init_tables(){
echo -e "Initializing iptables rules...\n"
# Listing of iptable rules #
# Reseting rules for conf
iptables -t filter -F
iptables -t filter -X

# Main server rules
# block everything first
iptables -t filter -P INPUT DROP
iptables -t filter -P OUTPUT ACCEPT
iptables -t filter -P FORWARD DROP

#do not break existing connections
# RELATED meaning that the packet is starting a new connection, but is associated with an existing connection, such as an FTP data transfer, or an ICMP error.
# ESTABLISHED ESTABLISHED meaning that the packet is associated with a connection which has seen packets in both direction
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT


# allow ssh (the most important!)
# ESTABLISHED: The packet is part of a connection that has seen packets in both directions
# NEW: The packet is the start of a new connection
# RELATED: The packet is starting a new secondary connection. 
# This is a common feature of such protocols such as an FTP data transfer, or an ICMP error.
iptables -A INPUT -t filter -p tcp --dport 2222 -j ACCEPT
iptables -A OUTPUT -t filter -p tcp --dport 2222 -j ACCEPT
iptables -A INPUT -t filter -p tcp -m state --state NEW,ESTABLISHED,RELATED --sport 2222 -j ACCEPT

#allow dns resolution
iptables -A OUTPUT -t filter -p tcp --dport 53 -j ACCEPT
iptables -A OUTPUT -t filter -p udp --dport 53 -j ACCEPT
iptables -A INPUT -t filter -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -t filter -p udp --dport 53 -j ACCEPT
echo -e "allow dns resolution\n"

#allow dhcp discovering
iptables -A INPUT -t filter -p udp --dport 67:68 -j ACCEPT
iptables -A OUTPUT -t filter -p udp --dport 67:68 -j ACCEPT
echo -e "allow dhcp discovering\n"

#allow lo
iptables -A INPUT -t filter -i lo -j ACCEPT
iptables -A OUTPUT -t filter -o lo -j ACCEPT
echo -e "allow lo\n"

#allow smtp 25
iptables -A INPUT -t filter -p tcp --dport 25 -j ACCEPT
iptables -A OUTPUT -t filter -p tcp --dport 25 -j ACCEPT
echo -e "allow smtp 25\n"

#allow imap 143
iptables -A INPUT -t filter -p tcp --dport 143 -j ACCEPT
iptables -A OUTPUT -t filter -p tcp --dport 143 -j ACCEPT
echo -e "allow imap 143\n"

#allow pop 110
iptables -A INPUT -t filter -p tcp --dport 110 -j ACCEPT
echo -e "allow pop 110\n"

#allow http/https
iptables -A INPUT -t filter -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -t filter -p tcp --dport 80 -j ACCEPT
echo -e "allow http\n"

#allow irc bouncer incoming connections
iptables -A INPUT -t filter -p tcp --dport 6666 -j ACCEPT
echo -e "allow connections to znc irc bouncer"
#openvpn
# The masquerade IP address always defaults to the IP address of the firewall's main interface.
# This kernel has not been compiled with the proper kernel module to be able to use MASQUERADE statement.
# The advantage of this is that you never have to specify the NAT IP address. This makes it much easier to configure iptables NAT with DHCP.
# You can configure many to one NAT to an IP alias, using the POSTROUTING and not the MASQUERADE statement. 
# An example of this can be seen in the static NAT section that follows.
#https://secure.intovps.com/knowledgebase/19/How-to-install-and-configure-OpenVPN.html
echo 1 > /proc/sys/net/ipv4/ip_forward
#iptables -A FORWARD -i tun0 -o venet0 -j ACCEPT
iptables -I INPUT -i tun0 -j ACCEPT
iptables -I FORWARD -i tun0 -j ACCEPT
iptables -I FORWARD -o tun0 -j ACCEPT
iptables -I OUTPUT -o tun0 -j ACCEPT
iptables -I INPUT -t filter -p udp --dport 1723 -j ACCEPT
iptables -A POSTROUTING -t nat -s 10.8.0.0/24 -j SNAT --to xxx
echo -e "allow openvpn connections\n"
#rTorrent
#web interface
iptables -I INPUT -t filter -p tcp --dport 26745 -j ACCEPT
iptables -I OUTPUT -t filter -p udp --sport 6881 -j ACCEPT
echo -e "allow rTorrent\n"
echo -e "Initialization done!\n"
exit 0
}


# Managing options #
case "$1" in
	start)
	shift
	init_tables
	;;

	stop)
	shift
	flush_tables
	;;
	
	save)
	shift
	save_rules
	;;
esac

# if sth wrong as argument => exit
if [[ ($# -ne 1) && ("$1" == "") ]]
then
	print_usage
	exit 1
fi

