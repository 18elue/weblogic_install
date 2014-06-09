#!/usr/bin/bash
# this script is run under /home/6375ly/weblogic_install_script dir

# get dir name
weblogic_install_dir=$1

# create dir from TEMPLATE, add input.properties file to dir
[[ -e $weblogic_install_dir ]] && rm -rf $weblogic_install_dir && echo "dir $weblogic_install_dir deleted"
cp -r DOMAIN_CREATE_TEMPLATE $weblogic_install_dir
mv input.properties $weblogic_install_dir/domain_create

# create start script
source $weblogic_install_dir/domain_create/input.properties

## create admin server start script
script_home=/home/6375ly/weblogic_install_script/$weblogic_install_dir/start_script
[[ -e $script_home/$ADMIN_SERVER_NAME ]] && rm -rf $script_home/$ADMIN_SERVER_NAME && echo "dir $script_home/$ADMIN_SERVER_NAME deleted"

cp -r $script_home/template/admin_node $script_home/$ADMIN_SERVER_NAME
echo "admin server dir created"

cd $script_home/$ADMIN_SERVER_NAME
sed -i "s%\${SERVUSER}%$SERVUSER%g" $(grep \${SERVUSER} -l *)
sed -i "s%\${BEAHOME}%$BEAHOME%g" $(grep \${BEAHOME} -l *)
sed -i "s%\${T3_URL}%$T3_URL%g" $(grep \${T3_URL} -l *)
sed -i "s%\${DOMAIN_NAME}%$DOMAIN_NAME%g" $(grep \${DOMAIN_NAME} -l *)
sed -i "s%\${ADMIN_SERVER_NAME}%$ADMIN_SERVER_NAME%g" $(grep \${ADMIN_SERVER_NAME} -l *)
sed -i "s%\${WEBLOGIC_USER}%$WEBLOGIC_USER%g" $(grep \${WEBLOGIC_USER} -l *)
sed -i "s%\${WEBLOGIC_PWD}%$WEBLOGIC_PWD%g" $(grep \${WEBLOGIC_PWD} -l *)

## create managed server start script
for MANAGED_SERVER_NAME in ${MANAGED_SERVER_NAMES[@]};do
	[[ -e $script_home/$MANAGED_SERVER_NAME ]] && rm -rf $script_home/$MANAGED_SERVER_NAME && echo "dir $script_home/$MANAGED_SERVER_NAME deleted"

	cp -r $script_home/template/managed_node $script_home/$MANAGED_SERVER_NAME
	echo "managed server $MANAGED_SERVER_NAME dir created"

	cd $script_home/$MANAGED_SERVER_NAME
	sed -i "s%\${SERVUSER}%$SERVUSER%g" $(grep \${SERVUSER} -l *)
	sed -i "s%\${BEAHOME}%$BEAHOME%g" $(grep \${BEAHOME} -l *)
	sed -i "s%\${T3_URL}%$T3_URL%g" $(grep \${T3_URL} -l *)
	sed -i "s%\${DOMAIN_NAME}%$DOMAIN_NAME%g" $(grep \${DOMAIN_NAME} -l *)
	sed -i "s%\${ADMIN_SERVER_NAME}%$ADMIN_SERVER_NAME%g" $(grep \${ADMIN_SERVER_NAME} -l *)
	sed -i "s%\${WEBLOGIC_USER}%$WEBLOGIC_USER%g" $(grep \${WEBLOGIC_USER} -l *)
	sed -i "s%\${WEBLOGIC_PWD}%$WEBLOGIC_PWD%g" $(grep \${WEBLOGIC_PWD} -l *)
	sed -i "s%\${MANAGED_SERVER_NAME}%$MANAGED_SERVER_NAME%g" $(grep \${MANAGED_SERVER_NAME} -l *)
	# change file names
	for file_name in *; do
		if [[ $file_name =~ nodename ]];then
		mv $file_name ${file_name/nodename/${MANAGED_SERVER_NAME}}
		fi
	done
done

## remove template dir
rm -rf $script_home/template