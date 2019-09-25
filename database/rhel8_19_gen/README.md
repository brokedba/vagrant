# Oracle 19c on Red Hat Linux 8

A simple Vagrant build for Oracle Database 19c on Red hat linux 8.

Note: the vagrant base box of RHEL8 is shipped with all the prerequisite rpm packages for Oracle 19c. tested with few Tim Hall builds so far

Enjoy

## Required Software

* [Vagrant](https://www.vagrantup.com/downloads.html)
* [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
* [Oracle Database](https://www.oracle.com/technetwork/database/enterprise-edition/downloads/oracle19c-linux-5462157.html)
* [Oracle REST Data Services (ORDS)](https://www.oracle.com/technetwork/developer-tools/rest-data-services/downloads/index.html)
* [Oracle SQLcl](https://www.oracle.com/technetwork/developer-tools/sqlcl/downloads/index.html)
* [Oracle Application Express (APEX)](https://www.oracle.com/technetwork/developer-tools/apex/downloads/index.html)
* [OpenJDK 12](http://jdk.java.net/12/)
* [Tomcat 9](https://tomcat.apache.org/download-90.cgi)

Place the software in the "software" directory before calling the `vagrant up` command.

Directory contents when software is included.

```
$ tree
.
+--- README.md
+--- scripts
|   +--- dbora.service
|   +--- install_os_packages.sh
|   +--- oracle_create_database.sh
|   +--- oracle_service_setup.sh
|   +--- oracle_software_installation.sh
|   +--- oracle_user_environment_setup.sh
|   +--- ords_software_installation.sh
|   +--- prepare_u01_u02_disks.sh
|   +--- root_setup.sh
|   +--- server.xml
|   +--- setup.sh
+--- software
|   +--- apache-tomcat-9.0.22.tar.gz
|   +--- apex_19.1_en.zip
|   +--- LINUX.X64_193000_db_home.zip
|   +--- openjdk-12.0.2_linux-x64_bin.tar.gz
|   +--- ords-19.2.0.199.1647.zip
|   +--- put_software_here.txt
|   +--- sqlcl-19.2.1.206.1649.zip
+--- Vagrantfile
$
```