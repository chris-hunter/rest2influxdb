#!/bin/bash
#This script is to read items from openhab rest api and save them to file

source ./config.cfg

resturl="http://$openhabserver:$openhabport/rest/items"
curl -X GET --header "Accept: application/json" "$resturl"  > items.xml

cat items.xml \
     | sed 's/}/\n/g' \
     | sed 's/,/\n/g' \
     | sed -n '/"name"/p' \
     | sed 's/"name":"//g' \
     | sed 's/"//g' \
> items.txt

exit 0
