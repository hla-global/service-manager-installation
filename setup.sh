#!/usr/bin/env bash
set -u

export SMG=smg-1.1.0-SNAPSHOT

export MANAGER=http://downloads.lappsgrid.org/service-manager
export SCRIPTS=http://downloads.lappsgrid.org/scripts

# Locations that Tomcat is installed.
TOMCAT_MANAGER=/usr/share/tomcat/service-manager
TOMCAT_BPEL=/usr/share/tomcat/active-bpel

function usage()
{
	echo
	echo "USAGE"
	echo "   sudo ./setup.sh"
	echo
	echo
}

function log {
	echo $1
	echo "$(date +'%b %d %Y %Y') - $1" >> /var/log/service-manager-install.log 
}

function start_tomcat {
	log "Staring tomcat."
	if [[ $OS = redhat7 || $OS = centos ]] ; then
		systemctl start tomcat
	else
		service tomcat start
	fi
}

function stop_tomcat {
	log "Stopping tomcat."
	if [[ $OS = redhat7 || $OS = centos ]] ; then
		systemctl stop tomcat
	else
		service tomcat stop
		while [[ `ps aux | grep bootstrap.jar | grep -v grep | wc -l` -gt 0 ]] ; do
			echo "Waiting for tomcat to shut down."
			sleep 5
		done
	fi
}

function wait_for_start {
	while ! grep "Server startup in" $1/logs/catalina.out ; do
		log "Waiting for $1 to start"
		sleep 3
	done
}

function toggle_tomcat {
	start_tomcat
	wait_for_start $TOMCAT_MANAGER
	wait_for_start $TOMCAT_BPEL
	stop_tomcat
	sleep 5
}

source <(curl -sSL http://downloads.lappsgrid.org/scripts/sniff.sh)

if [[ -z $OS ]] ; then
	log "The variable OS has not been set!"
	exit 1
fi

if [[ $OS = ubuntu ]] ; then
	log "Updating apt-get indices."
	apt-get update && apt-get upgrade -y
elif [[ $OS = redhat* || $OS = centos ]] ; then
	yum makecache fast
else
	log "Unsupport Linux flavor: $OS"
	exit 1
fi

set +u
if [[ -z "$EDITOR" ]] ; then
	EDITOR=emacs
fi
set -eu

# Installs the packages required to install and run the Service Grid.
log "Installing common packages"
curl -sSL $SCRIPTS/install-common.sh | bash

# Edit the properties file to get it out of the way and allow then
# rest of the script to continue uninterrupted.
log "Configuring the Service Manager"
if [[ ! -e service-manager.properties ]] ; then
	wget $MANAGER/service-manager.properties
fi
$EDITOR service-manager.properties

log "Installing Java"
curl -sSL $SCRIPTS/install-java.sh | bash
log "Installing PostgreSQL"
curl -sSL $SCRIPTS/install-postgres.sh | bash

if [[ $OS = centos || $OS = redhat7 ]] ; then
	hba=/var/lib/pgsql/9.6/data/pg_hba.conf
	rm $hba
	echo "local all all trust" > $hba
	echo "host all all 127.0.0.1/32 trust" >> $hba
	echo "host all all ::1/128 trust" >> $hba
	systemctl restart postgresql-9.6
fi

if [ ! -e ServiceManager.config ] ; then
	wget $MANAGER/ServiceManager.config
fi

# Get the program used to transform the ServiceManager.config file
# into the various xml files.
wget http://downloads.lappsgrid.org/$SMG.tgz
tar xzf $SMG.tgz
chmod +x $SMG/smg

# Processing the ServiceManager.config will generate:
# 	service_manager.xml
# 	active-bpel.xml
# 	tomcat-users.xml
# 	tomcat-users-bpel.xml
# 	langrid.ae.properties
# 	db.config
$SMG/smg ServiceManager.config
source db.config

sudo -u postgres createuser -S -D -R $ROLENAME
sudo -u postgres psql --command "ALTER USER $ROLENAME WITH PASSWORD '$PASSWORD'"
sudo -u postgres createdb $DATABASE -O $ROLENAME -E 'UTF8'

# Now install Tomcat and create the PostgreSQL database.
log "Starting Tomcat installation."
# (Ben) curl -sSL $MANAGER/install-tomcat.sh | bash
# Use the fixed version of install-tomcat.sh
./install-tomcat.sh

cp tomcat-users.xml $TOMCAT_MANAGER/conf
cp service_manager.xml $TOMCAT_MANAGER/conf/Catalina/localhost

cp tomcat-users-bpel.xml $TOMCAT_BPEL/conf/tomcat-users.xml
cp active-bpel.xml $TOMCAT_BPEL/conf/Catalina/localhost
cp langrid.ae.properties $TOMCAT_BPEL/bpr

# Get the new .war file before starting Tomcat for the first time.
log "Downloading the latest service manager war file."
## this line parses "releases" page from github to get the (supposedly) latest servicegrid war file
# wget https://github.com`wget -qO- https://github.com/openlangrid/langrid/releases/ | grep --color=never 'jp\.go\.nict\.langrid\.webapps\.servicegrid-core\..\+\.war\"' | head -1 | cut -d '"' -f 2 `
## however, we decided to use hard-coded perm. path to avoid unexpected breaks.
wget https://github.com/openlangrid/langrid/releases/download/servicegrid-core-20161206/jp.go.nict.langrid.webapps.servicegrid-core.jxta-p2p.nict-nlp-20161206.war
mv `ls *.war | head -1` $TOMCAT_MANAGER/webapps/service_manager.war

#toggle_tomcat

log "Creating indices."
wget $MANAGER/create_indices.sql
cat create_indices.sql | sudo -u postgres psql $DATABASE

log "Creating stored procedure."
wget $MANAGER/create_storedproc.sql
cat create_storedproc.sql | sudo -u postgres psql $DATABASE 

# We need to generate this on the fly since it include the user
# defined ROLENAME.
log "Changing owner of the stored procedure."
echo "ALTER FUNCTION \"AccessStat.increment\"(character varying, character varying, character varying, character varying, character varying, timestamp without time zone, timestamp without time zone, integer, timestamp without time zone, integer, timestamp without time zone, integer, integer, integer, integer) OWNER TO $ROLENAME" > alter.sql
cat alter.sql | sudo -u postgres psql $DATABASE

log "Securing the Tomcat installations"
for dir in $TOMCAT_MANAGER $TOMCAT_BPEL ; do
	pushd $dir > /dev/null
	# Make the tomcat user the owner of everything.
	chown -R tomcat:tomcat .

	# Tighten permissions on subdirectories.
	chmod -R 0700 bin
	chmod -R 0700 conf
	chmod -R 0750 logs
	chmod -R 0700 temp
	chmod -R 0700 work
	chmod -R 0770 webapps
	popd > /dev/null
done

#log "Removing default webapps."
#for dir in $TOMCAT_MANAGER/webapps $TOMCAT_BPEL/webapps ; do
#	pushd $dir > /dev/null
#	rm -rf docs examples manager host-manager
#	popd > /dev/null
#done

if [[ $OS = redhat7 || $OS = centos ]] ; then
	log "Opening port 8080"
	iptables -I INPUT -p tcp -m tcp --dport 8080 -j ACCEPT
fi

start_tomcat 

log "The Service Grid is now running."
echo
