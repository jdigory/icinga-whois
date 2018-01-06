#!/bin/bash

check_file=/etc/icinga/zones/zones.cfg
template=/etc/icinga/templates/zones.cfg

while read d || [[ -n $d ]]; do
    grep -w $d $check_file >/dev/null
    if [ $? -eq 0 ]
    then
        continue
    fi

	# add newline
	echo "" >> $check_file

	# add domain to file, based on template
	cat $template | sed -e "s:__domain__:$d:g" >> $check_file
done </usr/local/src/domains
