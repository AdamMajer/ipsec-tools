#!/bin/sh

#
# sa-up.sh local configuration for a new SA
#
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

case `uname -s` in
NetBSD)
	DEFAULT_GW=`netstat -rn | awk '($1 == "default"){print $2}'`
	;;
Linux)
	DEFAULT_GW=`netstat -rn | awk '($1 == "0.0.0.0"){print $2}'`
	;;
esac

echo $@
echo "LOCAL_ADDR = ${LOCAL_ADDR}"
echo "LOCAL_PORT = ${LOCAL_PORT}"
echo "REMOTE_ADDR = ${REMOTE_ADDR}"
echo "REMOTE_PORT = ${REMOTE_PORT}"
echo "DEFAULT_GW = ${DEFAULT_GW}"
echo "INTERNAL_ADDR4 = ${INTERNAL_ADDR4}"
echo "INTERNAL_DNS4 = ${INTERNAL_DNS4}"

echo ${INTERNAL_ADDR4} | grep '[0-9]' > /dev/null || exit 0
echo ${DEFAULT_GW} | grep '[0-9]' > /dev/null || exit 0

test -f /etc/resolv.conf.bak || cp /etc/resolv.conf /etc/resolv.conf.bak
echo "# Generated by racoon on `date`" > /etc/resolv.conf
echo "nameserver ${INTERNAL_DNS4}" >> /etc/resolv.conf

case `uname -s` in
NetBSD)
	if=`netstat -rn|awk '($1 == "default"){print $7}'`
	ifconfig ${if} alias ${INTERNAL_ADDR4}
	route delete default
	route add default ${DEFAULT_GW} -ifa ${INTERNAL_ADDR4}
	;;
Linux)
	if=`netstat -rn|awk '($1 == "0.0.0.0"){print $8}'`
	ifconfig ${if}:1 ${INTERNAL_ADDR4}      
	route delete default
	route add ${REMOTE_ADDR} gw ${DEFAULT_GW} dev ${if}
	route add default gw ${DEFAULT_GW} dev ${if}:1
	;;
esac

# Use this for a NAT-T setup
LOCAL="${LOCAL_ADDR}[${LOCAL_PORT}]"
REMOTE="${REMOTE_ADDR}[${REMOTE_PORT}]"

# Use this for a non NAT-T setup
#LOCAL="${LOCAL_ADDR}"
#REMOTE="${REMOTE_ADDR}"


echo "
spdadd ${INTERNAL_ADDR4}/32[any] 0.0.0.0/0[any] any
       -P out ipsec esp/tunnel/${LOCAL}-${REMOTE}/require;
spdadd 0.0.0.0/0[any] ${INTERNAL_ADDR4}[any] any
       -P in ipsec esp/tunnel/${REMOTE}-${LOCAL}/require;
" | setkey -c

#
# XXX This is a workaround for Linux forward policies problem. 
# Someone familiar with forward policies please fix this properly.
#
case `uname -s` in
Linux)
	echo "
	spddelete 0.0.0.0/0[any] ${INTERNAL_ADDR4}[any] any
		-P fwd ipsec esp/tunnel/${REMOTE}-${LOCAL}/require;
	" | setkey -c
	;;
esac
