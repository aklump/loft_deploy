#!/usr/bin/env bash
# This is snippet and not yet implemented 2016-07-13T13:23, aklump
# It creates a ssh tunnel to pantheon mysql

if [ ! "$production_db_port" ]; then
  end "Bad production db config; missing: \$production_db_port"
fi
if [ ! "$production_db_pass" ]; then
  end "Bad production db config; missing: \$production_db_pass"
fi

cmd="ssh -f -N -L $production_db_port:localhost:$production_db_port -p 2222 live.$pantheon_live_uuid@dbserver.live.$pantheon_live_uuid.drush.in"
echo $cmd
cmd="mysql -u pantheon -h 127.0.0.1 -p -P $production_db_port pantheon -p$production_db_pass"
echo $cmd
cmd="ps -fU $lobster_user | grep \"ssh -f\" | grep \"PORT:\" | awk '{print \$2}' | xargs kill"
echo $cmd

# More reading: <https://pantheon.io/docs/mysql-access/>, <https://pantheon.io/docs/ssh-tunnels/>
