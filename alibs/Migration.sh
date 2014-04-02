#!/bin/bash
# Copyright (c) 2014 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.

interface()
{
  echo "getCapabilities default start"
}

getCapabilities()
{
echo 'title Release Update of OSS
allowedRole root
allowedRole sysadmins
category System
order 10000'
}

default()
{
        SLESP3=$( zypper lr | grep SLES11-SP3 )

        if [ -e /var/adm/oss/migration ]
        then
                echo "label Die Migration läuft."
                echo "label The migration is processing."
                return
        elif [ -z "$SLESP3" ]
        then
                echo "label Jetzt können Sie das Update von SLES11 SP2 auf SLES11 SP3 starten."
                echo "label Now we can start the update from SLES11 SP2 to SLES11 SP3"
                echo "action cancel"
                echo "action start"
                return
        elif [ -e /var/adm/oss/must-restart ]
        then
                echo "label Ihr System is auf dem aktuellen Stand. Die Migration wurde beendet.<br>Bitte starten Sie den Server neu!"
                echo "label Your system is actuall. The migration process has been comleted.<br>Please restart your server!"
	else
                echo "label Ihr System is auf dem aktuellen Stand. Die Migration wurde beendet.<br>"
                echo "label Your system is actuall. The migration process has been comleted.<br>"
        fi

}

start()
{
        at -f /usr/share/lmd/tools/migrate-oss.sh now

	echo "label Die Migration wurde gestartet."
	echo "label The migration was started."

}

while read -r k v
do
    export FORM_$k=$v
done

$1
