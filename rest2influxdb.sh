#!/bin/bash
# This script reads the values of an item from openhab via REST and imports the data to influxdb
# useage: get_item_states.sh <itemname>

source ./config.cfg
# convert historical times to unix timestamps,
tenyearsago=`date +"%Y-%m-%dT%H:%M:%S" --date="10 years ago"`
oneyearago=`date +"%Y-%m-%dT%H:%M:%S" --date="-12 months 28 days ago"`
onemonthago=`date +"%Y-%m-%dT%H:%M:%S" --date="29 days ago"`
oneweekago=`date +"%Y-%m-%dT%H:%M:%S" --date="-6 days -23 hours 59 minutes ago"`
onedayago=`date +"%Y-%m-%dT%H:%M:%S" --date="-23 hours 59 minutes ago"`
eighthoursago=`date +"%Y-%m-%dT%H:%M:%S" --date="-7 hours 59 minutes ago"`
# print timestamps
echo ""
echo "### timestamps"
echo "item: $line"
echo "10y:  $tenyearsago"
echo "1y:   $oneyearago"
echo "1m:   $onemonthago"
echo "1w:   $oneweekago"
echo "1d:   $onedayago"
echo "8h:   $eighthoursago"

while read line; do
    echo $line
    resturl="http://$openhabserver:$openhabport/rest/persistence/items/$line?serviceId=$serviceid&api_key=$line"

    echo "resturl:   $resturl"

    # get values and write to different files
    curl -X GET --header "Accept: application/json" "$resturl&starttime=${tenyearsago}&endtime=${oneyearago}"  > ${line}_10y.xml
    curl -X GET --header "Accept: application/json" "$resturl&starttime=${oneyearago}&endtime=${onemonthago}"  > ${line}_1y.xml
    curl -X GET --header "Accept: application/json" "$resturl&starttime=${onemonthago}&endtime=${oneweekago}"  > ${line}_1m.xml
    curl -X GET --header "Accept: application/json" "$resturl&starttime=${oneweekago}&endtime=${onedayago}"    > ${line}_1w.xml
    curl -X GET --header "Accept: application/json" "$resturl&starttime=${onedayago}&endtime=${eighthoursago}" > ${line}_1d.xml
    curl -X GET --header "Accept: application/json" "$resturl&starttime=${eighthoursago}"                      > ${line}_8h.xml

    # combine files
    cat ${line}_10y.xml ${line}_1y.xml ${line}_1m.xml ${line}_1w.xml ${line}_1d.xml ${line}_8h.xml > ${line}.xml

    # convert data to line protocol file
    cat ${line}.xml \
	| sed 's/}/\n/g' \
	| sed 's/data/\n/g' \
	| grep -e "time.*state"\
	| tr -d ',:[{"' \
	| sed 's/time/ /g;s/state/ /g' \
	| awk -v item="$line" '{print item " value=" $2 " " $1 "000000"}' \
	| sed 's/value=ON/value=1/g;s/value=OFF/value=0/g' \
    > ${line}.txt

    values=`wc -l ${line}.txt | cut -d " " -f 1`
    echo ""
    echo "### found values: $values"

    curl --request POST \
	 "http://10.31.78.1:8086/api/v2/write?org=$influxorg&bucket=$influxbucket&precision=ns" \
	 --header "Authorization: Token $influxtoken" \
	 --header "Content-Type: text/plain; charset=uft-8" \
	 --header "Accept: application/json" \
	 --data-binary @${line}.txt

    echo ""
    echo "### delete temporary files"
    rm ${line}*
    echo "sleeping for 5s"
    sleep 5s
done < items.txt

exit 0
