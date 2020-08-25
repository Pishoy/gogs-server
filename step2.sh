#!/bin/bash
# /etc/rc.d/init.d/gogs
#
# Runs the Gogs
#
#
# chkconfig: - 85 15
#
### BEGIN INIT INFO
# Provides: gogs
# Required-Start: $remote_fs $syslog
# Required-Stop: $remote_fs $syslog
# Should-Start: mysql postgresql
# Should-Stop: mysql postgresql
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Start gogs at boot time.
# Description: Control gogs.
### END INIT INFO

# Source function library.
. /etc/init.d/functions

# Gogs admin 
ADMIN_USER=myadmin
ADMIN_PASS=1
ADMIN_EMAIL="test@test.com"

# Default values
DOMIAN=167.99.5.178
GOGS_PORT=4000
NAME=git
GOGS_HOME=/opt/gogs
GOGS_PATH=${GOGS_HOME}/$NAME
GOGS_USER=git
SERVICENAME="Gogs"
LOCKFILE=/var/lock/subsys/gogs
LOGPATH=${GOGS_HOME}/log
LOGFILE=${LOGPATH}/gogs.log
RETVAL=0
echo "*******************************************************"
echo "doing RPM of MSQL" 
sudo rpm -ivh mysql57-community-release-el7-9.noarch.rpm
echo "doing yum of MSQL" 
sudo yum install mysql-server -y
echo "checking status of MSQL" 
sudo systemctl status mysqld
echo "start mysql if not started"
sudo systemctl start mysqld
echo "secure installation of MSQL" 
#sudo mysql_secure_installation -y
ROOT_DATABASE_PASS=myrootPassW0Rd123
GOGS_DATABASE_PASS=strongpassword

# you need to set the gogs server to use database user gogs and password is GOGS_DATABASE_PASS

mysqladmin -u root password "$ROOT_DATABASE_PASS" || true
mysql -u root -p"$ROOT_DATABASE_PASS" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_DATABASE_PASS';"
mysql -u root -p"$ROOT_DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
mysql -u root -p"$ROOT_DATABASE_PASS" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"$ROOT_DATABASE_PASS" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%'"
mysql -u root -p"$ROOT_DATABASE_PASS" -e "CREATE DATABASE IF NOT EXISTS gogs CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -u root -p"$ROOT_DATABASE_PASS" -e "CREATE USER 'git'@'localhost' IDENTIFIED BY '$GOGS_DATABASE_PASS';"
mysql -u root -p"$ROOT_DATABASE_PASS" -e "GRANT ALL PRIVILEGES ON gogs.* TO  'git'@'localhost'  WITH GRANT OPTION;"
mysql -u root -p"$ROOT_DATABASE_PASS" -e "FLUSH PRIVILEGES;"
echo "*******************************************************"
echo "tar of gogs install"
#tar xvf v2.18.0.tar.gz
mkdir /opt/gogs
tar -xzf gogs_0.11.91_linux_amd64.tar.gz --strip-components=1 -C /opt/gogs
echo "create a new system user for Gogs:"
sudo adduser --home /opt/gogs --shell /bin/bash --comment 'Gogs application' git
echo "change default port"
mkdir -p /opt/gogs/custom/conf
[[ -z "${GOGS_PORT}" ]] &&  export GOGS_PORT=3000

cat <<EOF > /opt/gogs/custom/conf/app.ini

[server]
DOMAIN = $DOMIAN
PROTOCOL = http
HTTP_ADDR = 0.0.0.0
HTTP_PORT = $GOGS_PORT
[database]
DB_TYPE: mysql
HOST: 127.0.0.1:3306
NAME: gogs
USER: git
PASSWD: '$GOGS_DATABASE_PASS'
SSL_MODE: 'disable'
PATH: 'data/gogs.db'

[security]
INSTALL_LOCK: true

EOF
sudo cp gogs.service /etc/systemd/system/gogs.service
sudo chown -R git:git /opt/gogs/
sudo systemctl daemon-reload
sudo systemctl restart gogs
sudo systemctl enable gogs
sudo systemctl status gogs
echo "waiting gogos server to up ...., then gonna create the admin account , username:$ADMIN_USER , password:$ADMIN_PASS"
sleep 4
# create admin user
if USER=git /opt/gogs/gogs admin create-user --name $ADMIN_USER --password $ADMIN_PASS  --admin --email $ADMIN_EMAIL;then
	echo "your admin account created successfully , username:$ADMIN_USER , password:$ADMIN_PASS"
fi

# Read configuration from /etc/sysconfig/gogs to override defaults
[ -r /etc/sysconfig/$NAME ] && . /etc/sysconfig/$NAME
# Don't do anything if nothing is installed
[ -x ${GOGS_PATH} ] || exit 0
# exit if logpath dir is not created.
[ -x ${LOGPATH} ] || exit 0

DAEMON_OPTS="--check $NAME"

# Set additional options, if any
[ ! -z "$GOGS_USER" ] && DAEMON_OPTS="$DAEMON_OPTS --user=${GOGS_USER}"

start() {
cd ${GOGS_HOME}
echo -n "Starting ${SERVICENAME}: "
daemon $DAEMON_OPTS "${GOGS_PATH} web > ${LOGFILE} 2>&1 &"
RETVAL=$?
echo
[ $RETVAL = 0 ] && touch ${LOCKFILE}

return $RETVAL
}

stop() {
cd ${GOGS_HOME}
echo -n "Shutting down ${SERVICENAME}: "
killproc ${NAME}
RETVAL=$?
echo
[ $RETVAL = 0 ] && rm -f ${LOCKFILE}
}

case "$1" in
start)
status ${NAME} > /dev/null 2>&1 && exit 0
start
;;
stop)
stop
;;
status)
status ${NAME}
;;
restart)
stop
start
;;
reload)
stop
start
;;
*)
echo "Usage: ${NAME} {start|stop|status|restart}"
exit 1
;;
esac
exit $RETVAL

