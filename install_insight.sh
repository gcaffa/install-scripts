#!/bin/bash
centos_release=`cat /etc/system-release 2> /dev/null`
run_user=`whoami`

if [ "$run_user" != "root" ]
then
        echo "Need root privileges for the installation."
        exit 1
fi

if [[ "$centos_release" > "CentOS Linux" || "$centos_release" > "Red Hat" ]]
then
        LOG_FILE_NAME="insight_install_$(date +"%Y_%m_%d_%I_%M").log"
        LOG_PATH="/var/log/insight/$LOG_FILE_NAME"
        mkdir -p /var/log/insight
        touch LOG_PATH
        echo "=============================="
        echo "Server IPs:"
        hostname -I
        echo "=============================="
        read -p "Enter server ip address: " IP_ADDRESS
        if ipcalc -cs $IP_ADDRESS
        then
                read -p "Enter server port (default: 80): " PORT
                if [ "$PORT" == "" ]
                then
                        PORT="80"
                fi

                echo "================================="
                echo "Please Validate the Information"
                echo "================================="

                echo "Server IP: " $IP_ADDRESS

                # echo "Hostname: " $HOSTNAME

                echo "Port: " $PORT

                read -p "Install InvGate Insight ? (no/YES): " INSTALL_RES

                case ${INSTALL_RES,,} in 
                        y|S|si|ye|yes ) INSTALL=true;;
                        n|no|o ) INSTALL=false;;
                        * ) INSTALL=true;;
                esac

                if [[ "$INSTALL" == "false" ]]
                then
                        echo "Aborting Installation"
                        exit 2
                fi

                # sed -i "s/::1.*/$IP_ADDRESS $HOSTNAME/g" /etc/hosts
                # hostnamectl set-hostname invgate-insight.com
                echo "[1] Installing postgreesql"
                yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm >> "$LOG_PATH"
                echo "[1] Finished"

                echo "[2] Adding EPEL repo"
                yum install epel-release -y >> "$LOG_PATH"
                echo "[2] Finished"

                echo "[3] Adding CentOS repo"
                yum install centos-release-scl -y >> "$LOG_PATH"
                echo "[3] Finished"

                echo "[4] Starting firewalld"
                service firewalld start >> "$LOG_PATH"
                echo "[4] Finished"

                echo "[5] Adding port (80/TCP)"
                firewall-cmd --permanent --add-port=80/tcp >> "$LOG_PATH"
                echo "[5] Finished"

                echo "[6] Adding port (443/TCP)"
                firewall-cmd --permanent --add-port=443/tcp >> "$LOG_PATH"
                echo "[6] Finished"

                echo "[7] Reloading firewalld"
                firewall-cmd --reload >> "$LOG_PATH"
                echo "[7] Finished"

                echo "[8] Setting enforce"
                setenforce 0 && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config >> "$LOG_PATH"
                echo "[8] Finished"

                echo "[9] Adding InvGate repo"
                touch /etc/yum.repos.d/invgate.repo >> "$LOG_PATH"
                tee -a /etc/yum.repos.d/invgate.repo <<EOL
[invgate]
name=InvGate Packages
baseurl=https://download.invgate.net/neoassets/packages/centos7/
enabled=1
gpgcheck=0
EOL
                echo "[9] Finished"

                echo "[10] Installing InvGate Insight"
                yum install invgate-neo-assets -y >> "$LOG_PATH"
                if [ "$?" != 0 ]
                then
                        echo "[X] Instalation FAILED"
                        exit 2
                fi
                echo "[10] Finished"
                
                echo "[11] Configuring InvGate Insight"
                sed -i "s|ASSETS_DOMAIN.*|ASSETS_DOMAIN=http://$IP_ADDRESS:$PORT|g" /usr/share/invgate/neoassets/neo-assets/.env >> "$LOG_PATH"
                sed -i "s|NEO_ASSETS_STATIC_URL.*|NEO_ASSETS_STATIC_URL=http://$IP_ADDRESS/static-front|g" /usr/share/invgate/neoassets/neo-assets/.env >> "$LOG_PATH"
                echo "[11] Finished"


                echo "[12] Restarting Apache"
                systemctl restart httpd24-httpd >> "$LOG_PATH"
                echo "[12] Finished"


                echo "==============================" 
                more /var/log/httpd/neo-assets-install.log | grep 'Your superadmin'
                echo "=============================="

                echo "[#] Instalation finished"
        else
        echo "Please provide a valid IP Address."
        exit 1
        fi
else
        echo "The Insight Server must be installed in a Centos/RedHat Linux"
        exit 1
fi