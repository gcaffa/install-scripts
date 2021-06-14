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
        echo "=============================="
        echo "Server IPs:"
        hostname -I
        echo "=============================="
        read -p "Enter server ip address: " IP_ADDRESS
        if ipcalc -cs $IP_ADDRESS
        then
                # read -p "Enter server hostname (invgate-insight.com): " HOSTNAME
                # if [ "$HOSTNAME" == "" ]
                # then
                #         HOSTNAME="invgate-insight.com"
                # fi

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
                yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
                yum install epel-release -y
                yum install centos-release-scl -y
                service firewalld start
                firewall-cmd --permanent --add-port=80/tcp
                firewall-cmd --permanent --add-port=443/tcp
                firewall-cmd --reload
                setenforce 0 && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
                touch /etc/yum.repos.d/invgate.repo 
                tee -a /etc/yum.repos.d/invgate.repo <<EOL
[invgate]
name=InvGate Packages
baseurl=https://download.invgate.net/neoassets/packages/centos7/
enabled=1
gpgcheck=0
EOL
                yum install invgate-neo-assets -y
                if [ "$?" != 0 ]
                then
                        echo "The installation failed"
                        exit 2
                fi
                sed -i "s|ASSETS_DOMAIN.*|ASSETS_DOMAIN=http://$IP_ADDRESS:$PORT|g" /usr/share/invgate/neoassets/neo-assets/.env
                sed -i "s|NEO_ASSETS_STATIC_URL.*|NEO_ASSETS_STATIC_URL=http://$IP_ADDRESS/static-front|g" /usr/share/invgate/neoassets/neo-assets/.env

                systemctl restart httpd24-httpd

                echo "==============================" 
                more /var/log/httpd/neo-assets-install.log | grep 'Your superadmin'
                echo "=============================="
        else
        echo "Please provide a valid IP Address."
        exit 1
        fi
else
        echo "The Insight Server must be installed in a Centos/RedHat Linux"
        exit 1
fi