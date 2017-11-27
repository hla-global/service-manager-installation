#!/usr/bin/env bash

# The manager variable should be picked up from the calling environment.  If not
# we set it to a likely default value.
if [[ -z $MANAGER ]] ; then
	MANAGER=http://downloads.lappsgrid.org/service-manager
fi

if [ -z "$OS" ] ; then
	source <(curl -sSL http://downloads.lappsgrid.org/scripts/sniff.sh)
fi

#if [[ ! `grep -c '^tomcat:' /etc/passwd` ]] ; then 
if ! id tomcat ; then
    if [[ $OS = redhat* || $OS = centos ]] ; then
        adduser -r -d /usr/share/tomcat -s /usr/bin/bash tomcat
    elif [[ $OS = ubuntu ]] ; then
        groupadd tomcat
        adduser --system --home /usr/share/tomcat --shell /usr/bin/bash --ingroup tomcat tomcat
    else
        echo "Unknown Linux flavor"
        exit 1
    fi
fi 

wget http://downloads.lappsgrid.org/tomcat.tgz
tar xzf tomcat.tgz
mv tomcat /usr/share
chown -R tomcat:tomcat /usr/share/tomcat


if [[ $OS = centos || $OS = redhat7 ]] ; then
    wget $MANAGER/tomcat.service
    mv tomcat.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable tomcat.service
elif [[ $OS = ubuntu || $OS = redhat6 ]] ; then
    # wget $MANAGER/tomcat.sh
    mv tomcat.sh /etc/init.d/tomcat
    chmod +x /etc/init.d/tomcat
    if [[ $OS = ubuntu ]]; then 
        update-rc.d tomcat defaults
    else 
        chkconfig --add tomcat
    fi # Added by Ben
else
	echo "Unknown Linux flavor... we should have failed already."
	exit 1
fi

echo "Tomcat installed to /usr/share/tomcat"

