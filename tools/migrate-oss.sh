DATE=$( /usr/share/oss/tools/oss_date.sh )
(
echo "/var/log/OSS-MIGRATION-SLES11-SP3-$DATE" > /var/adm/oss/migration
echo "/var/log/OSS-MIGRATION-SLES11-SP3-$DATE" > /var/adm/oss/oss_service
. /etc/sysconfig/schoolserver
. /etc/profile.d/profile.sh
ARCH=$( uname -m )
/usr/bin/wget -O /tmp/SMT.tar http://repo.openschoolserver.net/products/SLE11SP3/SMT.$ARCH.tar
tar xf /tmp/SMT.tar -C /etc/zypp/repos.d/
zypper ref
zypper al squidGuard
zypper al SuSEfirewall2 
zypper -n dup -l --from SLES11-SP3-Pool --from SLES11-SP3-Updates --from SLE11-SDK-SP3-Pool --from SLE11-SDK-SP3-Updates
zypper rl squidGuard
zypper rl SuSEfirewall2
/etc/cron.daily/oss.list-updates
rm /var/adm/oss/migration
rm /var/adm/oss/oss_service
sed -i /default-character-set/d /etc/my.cnf
touch /var/lib/mysql/.force_upgrade
rcmysql restart
rclmd restart
echo 'You have to reboot your OSS-server!
Bitte starten Sie Ihren OSS-Server neu!' > /var/adm/oss/must-restart
) &> /var/log/OSS-MIGRATION-SLES11-SP3-$DATE

