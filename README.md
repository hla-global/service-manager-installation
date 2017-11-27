# Setting up the Service Manager

## The Short Version

```bash
git clone https://github.com/hla-global/service-manager-installation.git
cd service-manager-installation
sudo chmod +x setup.sh
sudo ./setup.sh
```

The `setup.sh` script has been tested on RedHat 6, CentOS 7.1, and Ubuntu 14.04LTS (by the LAPPS developers).

Ben modified `setup.sh` and tested it on Ubuntu 16.04.

## The Long Version

The `setup.sh` script performs the following actions.

1. Downloads the service-manager.properties file and opens it in a text editor. Make any required changes (the fields should be self-explanatory), save the file, and exit.
1. Installs git, zip/unzip, and emacs if they are not already present on the system.
1. Installs OpenJDK 1.8
1. Installs PostgreSQL 9.6
1. Installs Tomcat 7
1. Generates all the XML configuration files; tomcat-user.xml, service-manager.xml, etc.
1. Downloads the latest service_manager.war file from the Open Langrid's GitHub repository.
1. Removes default Tomcat webapps and tightens read/write permissions on the Tomcat directories

### Notes

In most cases the ServiceManager.config file does not need to be edited. If you do need to make changes, for example to change the value of a field not listed in the *service-manager.properties* file you will need to download the file from *http://downloads.lappsgrid.org/service-manager/ServiceManager.config* and edit the file before running the `setup.sh` script.


### Troubleshooting

If the ANC's password service is down edit the ServiceManager.config file and replace occurrences of `${hexService.text}` with random hex strings and occurrences of `${passwordService.text}` with passwords.
