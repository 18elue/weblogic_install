#!/bin/bash

# this script is used to create domains


# set env variable from input file
source input.properties
DOMAIN_HOME=$DOMAIN_DIR/$DOMAIN_NAME

#check if domain alread exists
[[ -e $DOMAIN_HOME ]] && echo "domain $DOMAIN_NAME already exists, exit now" && exit


# get create_domain.py config_domain.py
./create_py.pl

# create domain
CLASSPATH=/usr/local/oracle/wls-latest/wlserver_10.3/server/lib/weblogic.jar:$CLASSPATH
export CLASSPATH
PATH=/usr/local/oracle/wls-latest/jdk/bin:$PATH
export PATH
echo "starting to run creat_domain.py"
java weblogic.WLST create_domain.py
echo "create domain finished"

# config domain
$DOMAIN_HOME/startWebLogic.sh 2>&1 >/dev/null &
## check if admin server is up
for second in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
do
	ADMINJVMPID=$(ps -ef | grep "Dweblogic.Name=${ADMIN_SERVER_NAME}"  | grep jdk | grep $SERVUSER | grep -v grep | awk '{print $2}')
	if [[ $ADMINJVMPID != ""  ]];then
		echo "the pid of admin server is $ADMINJVMPID"
		echo "wait 30 seconds for admin server be up"
		sleep 30 
		echo "admin server is ready for WLST"
		break
	fi
	sleep 1
done
[[ $ADMINJVMPID = "" ]] && echo "admin server not working, exiting" && exit

echo "start to run config_domain.py"
java weblogic.WLST config_domain.py
echo "config domain finished"
echo "shuting down admin server"
kill -9 $ADMINJVMPID

# create and link log
#echo "starting to link log file"
#LOGDIR=/sanfs/mnt/vol02/${DOMAIN_NAME}/site/common/logs
#for node in ${ALL_NODES[@]};do
#	mkdir -p $LOGDIR/$node
#	DOMAIN_LOG=$DOMAIN_HOME/servers/$node/logs
#	[[ -e $DOMAIN_LOG ]] && rm -rf $DOMAIN_LOG
#	ln -s $LOGDIR/$node $DOMAIN_LOG
#	echo "$node finished"
#done
