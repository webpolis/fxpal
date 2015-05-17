#!/bin/bash
CURDIR=$(dirname "$0")

for s in $(cat app/data/quandlSymbols.lst);
	do 
		out=$CURDIR/../../app/data/quandl/${s}.csv
		symbol=(${s//./ })
		curl -G -A "Mozilla/5.0 (Windows NT 6.1; rv:19.0) Gecko/20100101 Firefox/19.0" -o $out "https://quandl.com/api/v1/datasets/${symbol[0]}/${symbol[1]}.csv?column=${symbol[2]}&collapse=daily&trim_start=2005-01-01&auth_token=pWGUEdRoPxqEdp66WRYv"

		if [ "$OSTYPE" == "linux-gnu" ]; then
			sed -E -i "1s/\,([^\,]+)/,${s}/g" $out
		else
			sed -E -i "" "1s/\,([^\,]+)/,${s}/g" $out
		fi

		sleep 1
done

#paste -d, $(ls .tmp/*.csv) > $CURDIR/../../app/data/multisetsInputs.csv

cd $CURDIR/../../

find app/data/candles/*.* -type f -ctime +1 -exec rm {} \;
find app/data/breakout/*.* -type f -ctime +1 -exec rm {} \;
find app/data/quandl/*.csv -type f -ctime +1 -exec rm {} \;
find .tmp/*.json -type f -ctime +1 -exec rm {} \;

rm app/data/multisetsOutputs.csv

Rscript server/scripts/multisets.r
Rscript server/scripts/portfolio.r