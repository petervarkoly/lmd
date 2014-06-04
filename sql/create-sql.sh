#!/bin/bash
# Copyright (c) 2004-2014 Peter Varkoly <peter@varkoly.de> Nürnberg, Germany.  All rights reserved.
rcmysql status || rcmysql start
for i in /usr/share/lmd/sql/*.sql
do
	echo "Create lmd sql tabelles from $i"
	mysql -f < $i
done
echo "grant all on lmd.* to lmd@localhost  identified by \"lmd\"" | mysql
