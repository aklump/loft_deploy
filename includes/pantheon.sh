#!/usr/bin/env bash
# This is snippet and not yet implemented 2016-07-13T13:23, aklump
# It creates a ssh tunnel to pantheon mysql


#  return 0
#
#  mysql -u pantheon -p$production_db_pass -h dbserver.dev.$pantheon_live_uuid.drush.in -P $production_db_port pantheon
#
#  _mysql_production_end
#  cmd="ssh -f -N -L $production_db_port:localhost:$production_db_port -p 2222 live.$pantheon_live_uuid@dbserver.live.$pantheon_live_uuid.drush.in"
#  eval $cmd
#
##  is_active=$(ps -fU $lobster_user | grep "ssh -f" | grep "$production_db_port:" | awk '{print \$2}')
##  if [ ! "$is_active" ]; then
##    cmd="ssh -f -N -L $production_db_port:localhost:$production_db_port -p 2222 live.$pantheon_live_uuid@dbserver.live.$pantheon_live_uuid.drush.in"
##    eval $cmd
##  fi
#
#  cmd="mysql -u pantheon -h 127.0.0.1 -p -P $production_db_port pantheon -p$production_db_pass"
##  eval $cmd
#echo $cmd
##  close="ps -fU $lobster_user | grep \"ssh -f\" | grep \"$production_db_port:\" | awk '{print \$2}' | xargs kill"
##  echo $close
#
#  show_switch
#  # More reading: <https://pantheon.io/docs/mysql-access/>, <https://pantheon.io/docs/ssh-tunnels/>
#}

#function _mysql_production_end() {
#  ps -fU $lobster_user | grep "ssh -f" | grep "$production_db_port:" | awk '{print $2}' | xargs kill
#}
