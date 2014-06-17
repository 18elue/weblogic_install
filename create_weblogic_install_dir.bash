#!/usr/bin/bash
# this script is run under /home/6375ly/weblogic_install_script dir

# get dir name
weblogic_install_dir=$1

# create dir from TEMPLATE, add file input.properties, other_info.sh to dir
[[ -e $weblogic_install_dir ]] && rm -rf $weblogic_install_dir && echo "dir $weblogic_install_dir deleted"
cp -r DOMAIN_CREATE_TEMPLATE $weblogic_install_dir
mv input.properties $weblogic_install_dir/domain_create
mv other_info.sh $weblogic_install_dir/domain_create

# create start script
source $weblogic_install_dir/domain_create/input.properties

## create admin server start script
script_home=/home/6375ly/weblogic_install_script/$weblogic_install_dir/start_script
cp -r $script_home/template/admin_node $script_home/$ADMIN_SERVER_ADDRESS && echo "admin server start script dir created"

cd $script_home/$ADMIN_SERVER_ADDRESS
sed -i "s%\${SERVUSER}%$SERVUSER%g" $(grep \${SERVUSER} -l *)
sed -i "s%\${BEAHOME}%$BEAHOME%g" $(grep \${BEAHOME} -l *)
sed -i "s%\${T3_URL}%$T3_URL%g" $(grep \${T3_URL} -l *)
sed -i "s%\${DOMAIN_DIR}%$DOMAIN_DIR%g" $(grep \${DOMAIN_DIR} -l *)
sed -i "s%\${DOMAIN_NAME}%$DOMAIN_NAME%g" $(grep \${DOMAIN_NAME} -l *)
sed -i "s%\${ADMIN_SERVER_NAME}%$ADMIN_SERVER_NAME%g" $(grep \${ADMIN_SERVER_NAME} -l *)
sed -i "s%\${WEBLOGIC_USER}%$WEBLOGIC_USER%g" $(grep \${WEBLOGIC_USER} -l *)
sed -i "s%\${WEBLOGIC_PWD}%$WEBLOGIC_PWD%g" $(grep \${WEBLOGIC_PWD} -l *)
sed -i "s%\${ADMIN_LOG_DIR}%$ADMIN_LOG_DIR%g" $(grep \${ADMIN_LOG_DIR} -l *)

## create managed server start script
index=1;
for MANAGED_SERVER_NAME in ${MANAGED_SERVER_NAMES[@]};do
	log_dir_key=MANAGED_SERVER_${index}_LOG_DIR
	address_key=MANAGED_SERVER_${index}_ADDRESS
	index=$(($index+1))
	
	[[ -e $script_home/${!address_key} ]] || mkdir $script_home/${!address_key}
	cp $script_home/template/managed_node/* $script_home/${!address_key} && echo "managed server $MANAGED_SERVER_NAME dir created"
	

	cd $script_home/${!address_key}
	sed -i "s%\${SERVUSER}%$SERVUSER%g" $(grep \${SERVUSER} -l *)
	sed -i "s%\${BEAHOME}%$BEAHOME%g" $(grep \${BEAHOME} -l *)
	sed -i "s%\${T3_URL}%$T3_URL%g" $(grep \${T3_URL} -l *)
	sed -i "s%\${DOMAIN_DIR}%$DOMAIN_DIR%g" $(grep \${DOMAIN_DIR} -l *)
	sed -i "s%\${DOMAIN_NAME}%$DOMAIN_NAME%g" $(grep \${DOMAIN_NAME} -l *)
	sed -i "s%\${ADMIN_SERVER_NAME}%$ADMIN_SERVER_NAME%g" $(grep \${ADMIN_SERVER_NAME} -l *)
	sed -i "s%\${WEBLOGIC_USER}%$WEBLOGIC_USER%g" $(grep \${WEBLOGIC_USER} -l *)
	sed -i "s%\${WEBLOGIC_PWD}%$WEBLOGIC_PWD%g" $(grep \${WEBLOGIC_PWD} -l *)
	sed -i "s%\${MANAGED_SERVER_NAME}%$MANAGED_SERVER_NAME%g" $(grep \${MANAGED_SERVER_NAME} -l *)
	sed -i "s%\${MANAGED_SERVER_LOG_DIR}%${!log_dir_key}%g" $(grep \${MANAGED_SERVER_LOG_DIR} -l *)
	sed -i "s%\${Xms}%$Xms%g" $(grep \${Xms} -l *)
	sed -i "s%\${Xmx}%$Xmx%g" $(grep \${Xmx} -l *)
	sed -i "s%\${MaxPermSize}%$MaxPermSize%g" $(grep \${MaxPermSize} -l *)	
	
	# change file names
	for file_name in *; do
		if [[ $file_name =~ nodename ]];then
		mv $file_name ${file_name/nodename/${MANAGED_SERVER_NAME}}
		fi
	done
done


# remove template dir
rm -rf $script_home/template