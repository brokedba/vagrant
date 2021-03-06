. /vagrant_config/install.env

echo "******************************************************************************"
echo "Configure network scripts." `date`
echo "******************************************************************************"

cat > ${ORACLE_HOME}/network/admin/tnsnames.ora <<EOF
LISTENER = (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_HOSTNAME})(PORT = 1521))

${NODE1_DB_UNIQUE_NAME} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_HOSTNAME})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ${ORACLE_SID})
    )
  )

${NODE2_DB_UNIQUE_NAME} =
  (DESCRIPTION =
    (ADDRESS_LIST =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE2_HOSTNAME})(PORT = 1521))
    )
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SID = ${ORACLE_SID})
    )
  )
EOF


cat > ${ORACLE_HOME}/network/admin/listener.ora <<EOF
LISTENER =
  (DESCRIPTION_LIST =
    (DESCRIPTION =
      (ADDRESS = (PROTOCOL = TCP)(HOST = ${NODE1_HOSTNAME})(PORT = 1521))
      (ADDRESS = (PROTOCOL = IPC)(KEY = EXTPROC1521))
    )
  )

SID_LIST_LISTENER =
  (SID_LIST =
    (SID_DESC =
      (GLOBAL_DBNAME = ${NODE1_DB_UNIQUE_NAME}_DGMGRL)
      (ORACLE_HOME = ${ORACLE_HOME})
      (SID_NAME = ${ORACLE_SID})
    )
  )

ADR_BASE_LISTENER = ${ORACLE_BASE}
INBOUND_CONNECT_TIMEOUT_LISTENER=400
EOF


cat > ${ORACLE_HOME}/network/admin/sqlnet.ora <<EOF
SQLNET.INBOUND_CONNECT_TIMEOUT=400
EOF

echo "******************************************************************************"
echo "Start listener." `date`
echo "******************************************************************************"
lsnrctl start

echo "******************************************************************************"
echo "Create database." `date`
echo "******************************************************************************"
dbca -silent -createDatabase                                                 \
  -templateName General_Purpose.dbc                                          \
  -gdbname ${ORACLE_SID} -sid ${ORACLE_SID} -responseFile NO_VALUE           \
  -characterSet AL32UTF8                                                     \
  -sysPassword ${SYS_PASSWORD}                                               \
  -systemPassword ${SYS_PASSWORD}                                            \
  -createAsContainerDatabase true                                            \
  -numberOfPDBs 1                                                            \
  -pdbName ${PDB_NAME}                                                       \
  -pdbAdminPassword ${PDB_PASSWORD}                                          \
  -databaseType MULTIPURPOSE                                                 \
  -automaticMemoryManagement false                                           \
  -totalMemory 2048                                                          \
  -storageType FS                                                            \
  -datafileDestination "${DATA_DIR}"                                         \
  -redoLogFileSize 50                                                        \
  -emConfiguration NONE                                                      \
  -ignorePreReqs

echo "******************************************************************************"
echo "Set the PDB to auto-start." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF
ALTER SYSTEM SET db_create_file_dest='${DATA_DIR}';
ALTER SYSTEM SET db_create_online_log_dest_1='${DATA_DIR}';
ALTER PLUGGABLE DATABASE ${PDB_NAME} SAVE STATE;
ALTER SYSTEM SET local_listener='LISTENER';
ALTER SYSTEM SET db_recovery_file_dest_size=20G;
ALTER SYSTEM SET db_recovery_file_dest='/u01/app/oracle';
exit;
EOF

echo "******************************************************************************"
echo "Configure archivelog mode, standby logs and flashback." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF

-- Enable archivelog mode.
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;

ALTER DATABASE FORCE LOGGING;
-- Make sure at least one logfile is present.
ALTER SYSTEM SWITCH LOGFILE;

-- Add standby logs.
ALTER DATABASE ADD STANDBY LOGFILE SIZE 50M;
ALTER DATABASE ADD STANDBY LOGFILE SIZE 50M;
ALTER DATABASE ADD STANDBY LOGFILE SIZE 50M;
ALTER DATABASE ADD STANDBY LOGFILE SIZE 50M;
-- If you don't want to use OMF specify a path like this.
--ALTER DATABASE ADD STANDBY LOGFILE ('${DATA_DIR}/${ORACLE_SID^^}/standby_redo01.log') SIZE 50M;

-- Enable flashback database.
ALTER DATABASE FLASHBACK ON;

ALTER SYSTEM SET STANDBY_FILE_MANAGEMENT=AUTO;
EXIT;
EOF



echo "******************************************************************************"
echo "Enable the broker." `date`
echo "******************************************************************************"
sqlplus / as sysdba <<EOF

ALTER SYSTEM SET dg_broker_start=TRUE;

EXIT;
EOF

echo "******************************************************************************"
echo "Create start/stop scripts." `date`
echo "******************************************************************************"


touch /home/oracle/scripts/db_type.txt


cat > /home/oracle/scripts/start_all.sh <<EOF
#!/bin/bash
. /home/oracle/scripts/setEnv.sh
DB_UNIQUE_NAME=`ls $ORACLE_HOME/dbs/dr2*dat| xargs -n 1 basename|awk '{gsub(/dr2/,x)}1' |awk '{gsub(/\.dat/,x)}1'`
db_type=`cat /home/oracle/scripts/db_type.txt`
if [ "\$db_type" == "Primary" ] ; then
# open primary DB
echo -e "\n startup;\nexit" | ${ORACLE_HOME}/bin/sqlplus "/ as sysdba"
echo "edit database \$DB_UNIQUE_NAME set state='TRANSPORT-ON';" |$ORACLE_HOME/bin/dgmgrl /
# mount standby DB
else echo -e "\nstartup mount;\nexit" | ${ORACLE_HOME}/bin/sqlplus "/ as sysdba"
sleep 20
echo "edit database \$DB_UNIQUE_NAME set state='APPLY-ON';" |$ORACLE_HOME/bin/dgmgrl /
fi
echo "show database $DB_UNIQUE_NAME;" |$ORACLE_HOME/bin/dgmgrl / |grep "Intended State:"
EOF


cat > /home/oracle/scripts/stop_all.sh <<EOF
#!/bin/bash
. /home/oracle/scripts/setEnv.sh
/home/oracle/scripts/check_dgmgrl.sh
DB_UNIQUE_NAME=`ls $ORACLE_HOME/dbs/dr2*dat| xargs -n 1 basename|awk '{gsub(/dr2/,x)}1' |awk '{gsub(/\.dat/,x)}1'`
echo "show configuration;" |$ORACLE_HOME/bin/dgmgrl / |grep -A 1 \$DB_UNIQUE_NAME |awk 'NR==4 {print \$3}' > /home/oracle/scripts/db_type.txt
db_type=`cat /home/oracle/scripts/db_type.txt`
echo  "\$DB_UNIQUE_NAME is a \$db_type" DB
if [ "$db_type" == "Primary" ] ; then
echo "edit database \$DB_UNIQUE_NAME set state='LOG-TRANSPORT-OFF';" |$ORACLE_HOME/bin/dgmgrl /

 else echo "edit database \$DB_UNIQUE_NAME set state='APPLY-OFF';" |$ORACLE_HOME/bin/dgmgrl /
  fi
  echo "show database $DB_UNIQUE_NAME;" |$ORACLE_HOME/bin/dgmgrl / |grep "Intended State:"
echo -e "\nshutdown immediate;\nexit" | ${ORACLE_HOME}/bin/sqlplus "/ as sysdba"
EOF

touch /home/oracle/scripts/check_dgmgrl.sh 
cat > /home/oracle/scripts/check_dgmgrl.sh <<EOF
#!/bin/bash
. /home/oracle/.bash_profile
result=`echo "show configuration;" |$ORACLE_HOME/bin/dgmgrl / |grep -A 1 "Configuration Status" | grep -v "Configuration Status"|awk '{print $1}'`
if [ "$result" == "SUCCESS" ] ; then
 echo 'Data Guard status : up '
else echo  "$result"
fi
DB_UNIQUE_NAME=`ls $ORACLE_HOME/dbs/dr2*dat| xargs -n 1 basename|awk '{gsub(/dr2/,x)}1' |awk '{gsub(/\.dat/,x)}1'`
echo "show configuration;" |$ORACLE_HOME/bin/dgmgrl / |grep -A 1 \$DB_UNIQUE_NAME |awk 'NR==4 {print \$3}' > /home/oracle/scripts/db_type.txt
db_type=`cat /home/oracle/scripts/db_type.txt`
echo  "\$DB_UNIQUE_NAME is a \$db_type" DB
EOF

chown -R oracle.oinstall ${SCRIPTS_DIR}
chmod u+x ${SCRIPTS_DIR}/*.sh
