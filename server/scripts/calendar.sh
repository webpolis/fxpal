#!/bin/bash
CURDIR=$(dirname "$0")
for i in $(node calendar.js)
	do
		sleep 1
		curl -G -A "Mozilla/5.0 (Windows NT 6.1; rv:19.0) Gecko/20100101 Firefox/19.0" -O $i
done

mv Calendar*.csv $CURDIR/../../app/data/