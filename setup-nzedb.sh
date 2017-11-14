#!/bin/bash

# Do a stock run of the playbook to setup nZEDb
# $1 = full|restart|test
# $2... = additional ansible parameters

# Full install of zZEDb
if [ "ZZ$1" = "ZZfull" ] ; then
    shift
    ansible-playbook -K -i nzedb-hosts nzedb-playbook.yml $@
fi

