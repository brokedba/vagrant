. /vagrant_config/install.env

echo "******************************************************************************"
echo "Create environment scripts." `date`
echo "******************************************************************************"
mkdir -p /home/oracle/scripts

cat > /home/oracle/scripts/setEnv.sh <<EOF
# Oracle Settings
export TMP=/tmp
export TMPDIR=\$TMP

export ORACLE_HOSTNAME=${NODE1_FQ_HOSTNAME}
export ORACLE_BASE=${ORACLE_BASE}
export ORA_INVENTORY=${ORA_INVENTORY}
export ORACLE_HOME=\$ORACLE_BASE/${ORACLE_HOME_EXT}
export ORACLE_SID=${ORACLE_SID}
export DATA_DIR=${DATA_DIR}
export ORACLE_TERM=xterm
export BASE_PATH=/usr/sbin:\$PATH
export PATH=\$ORACLE_HOME/bin:\$BASE_PATH

export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib
export CLASSPATH=\$ORACLE_HOME/JRE:\$ORACLE_HOME/jlib:\$ORACLE_HOME/rdbms/jlib
EOF

cat >> /home/oracle/.bash_profile <<EOF
. /home/oracle/scripts/setEnv.sh
EOF
echo "******************************************************************************"
echo "Create start/stop scripts." `date`
echo "******************************************************************************"


cat > /home/oracle/scripts/start_all.sh <<EOF
#!/bin/bash
. /home/oracle/scripts/setEnv.sh
db_type=\`cat /home/oracle/scripts/db_type.txt\`
if [ "\$db_type" == "Primary" ] 
then echo "... opeining primary DB"
echo -e "\n startup;\nexit" | \$ORACLE_HOME/bin/sqlplus "/ as sysdba"
else 
echo "... mounting standby DB"
echo -e "\nstartup mount;\nexit" | \$ORACLE_HOME/bin/sqlplus "/ as sysdba"
fi
DB_UNIQUE_NAME=\`sqlplus -s "/ as sysdba" <<EOF                                                                                             	
      set heading off feedback off verify off                                                                                              	
      select value from v\\\\\$parameter where name='db_unique_name';                                                                          	
      exit                                                                                                                                 	
EOF\` 
DB_UNIQUE_NAME=\`echo \$DB_UNIQUE_NAME|awk '{gsub (/ /,""); print \$0}'\`
db_type=\`echo "show configuration;" | \$ORACLE_HOME/bin/dgmgrl / |grep  "\$DB_UNIQUE_NAME " |awk  '{print \$3 " " \$4}'\` 
echo ===========================================
echo  \$DB_UNIQUE_NAME DB is a \$db_type   
echo ===========================================
db_role=\`echo \$db_type|awk '{print \$1}'\` 
 if [ "\$db_role" == "Primary" ] 
 then echo "edit database \$DB_UNIQUE_NAME set state='TRANSPORT-ON';"|\$ORACLE_HOME/bin/dgmgrl /
 else sleep 30
 echo "edit database \$DB_UNIQUE_NAME set state='APPLY-ON';"|\$ORACLE_HOME/bin/dgmgrl /
 fi
 echo
 echo ===========================================
 echo -e "            Show new DB state" 
 echo  "show database \$DB_UNIQUE_NAME;" |\$ORACLE_HOME/bin/dgmgrl / |grep "Intended State:"
 echo ===========================================
   \$ORACLE_HOME/bin/lsnrctl start
EOF


cat > /home/oracle/scripts/stop_all.sh <<EOF                                                                                               	
#!/bin/bash                                                                                                                                 	
. /home/oracle/scripts/setEnv.sh                                                                                                            	
status=\`/home/oracle/scripts/check_dgmgrl.sh|awk -F: '{gsub (/ /,""); print \$2}'\`                                                        	
if [ "\$status" != "up" ]                                                                                                	
then echo "the status is not up  service can't be stopped "                                                                                 	
else                                                                                                                                        	
DB_UNIQUE_NAME=\`sqlplus -s "/ as sysdba" <<EOF                                                                                             	
       set heading off feedback off verify off                                                                                              	
       select value from v\\\\\$parameter where name='db_unique_name';                                                                          	
       exit                                                                                                                                 	
EOF\` 
DB_UNIQUE_NAME=\`echo \$DB_UNIQUE_NAME|awk '{gsub (/ /,""); print \$0}'\`
db_type=\`echo "show configuration;" | \$ORACLE_HOME/bin/dgmgrl / |grep  "\$DB_UNIQUE_NAME " |awk  '{print \$3 " " \$4}'\` 
echo ===========================================
echo  \$DB_UNIQUE_NAME DB is a \$db_type   
echo ===========================================
echo \$db_type|awk '{print \$1}' > /home/oracle/scripts/db_type.txt
db_role=\`echo \$db_type|awk '{print \$1}'\` 
 if [ "\$db_role" == "Primary" ] ; then
 echo "edit database \$DB_UNIQUE_NAME set state='LOG-TRANSPORT-OFF';"|\$ORACLE_HOME/bin/dgmgrl /
 else echo "edit database \$DB_UNIQUE_NAME set state='APPLY-OFF';" |\$ORACLE_HOME/bin/dgmgrl /
 fi
 echo
 echo ===========================================
 echo "            Show new DB state" 
 echo "show database \$DB_UNIQUE_NAME;" |\$ORACLE_HOME/bin/dgmgrl / |grep "Intended State:"
 echo ===========================================
 echo ... shuting down \$DB_UNIQUE_NAME  database 
 echo -e "\nshutdown immediate;\nexit" | \$ORACLE_HOME/bin/sqlplus "/ as sysdba"
\$ORACLE_HOME/bin/lsnrctl stop
fi 
EOF

cat > /home/oracle/scripts/check_dgmgrl.sh <<EOF
#!/bin/bash
. /home/oracle/.bash_profile
result=\`echo "show configuration;" | \$ORACLE_HOME/bin/dgmgrl /| grep -A 1 "Configuration Status" | grep -v "Configuration Status"|awk -F[' '] '{print \$1}'\`
if [ "\$result" == "SUCCESS" ] ; then
 echo 'Data Guard status : up '
else echo  "\$result"
fi
EOF

chown -R oracle.oinstall ${SCRIPTS_DIR}
chmod u+x ${SCRIPTS_DIR}/*.sh

echo "******************************************************************************"
echo "Create directories." `date`
echo "******************************************************************************"
. /home/oracle/scripts/setEnv.sh
mkdir -p ${ORACLE_HOME}
mkdir -p ${DATA_DIR}
