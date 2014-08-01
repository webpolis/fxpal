#!/bin/bash
CURDIR=$(dirname "$0")
WEEKS=${1-157}
for i in $(node $CURDIR/calendar.js -w $WEEKS)
	do
		sleep 1
		curl -G -A "Mozilla/5.0 (Windows NT 6.1; rv:19.0) Gecko/20100101 Firefox/19.0" -O $i
done

mv Calendar*.csv $CURDIR/../../app/data/