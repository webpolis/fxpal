#!/bin/bash
CURDIR=$(dirname "$0")

curl -G -A "Mozilla/5.0 (Windows NT 6.1; rv:19.0) Gecko/20100101 Firefox/19.0" -o $CURDIR/../../app/data/multisetsInputs.csv "http://quandl.com/api/v1/multisets.csv?columns=CURRFX.AUDUSD.1,CURRFX.AUDNZD.1,CURRFX.AUDJPY.1,CURRFX.AUDGBP.1,CURRFX.AUDEUR.1,CURRFX.AUDCHF.1,CURRFX.AUDCAD.1,CURRFX.CADUSD.1,CURRFX.CADNZD.1,CURRFX.CADJPY.1,CURRFX.CADGBP.1,CURRFX.CADEUR.1,CURRFX.CADCHF.1,CURRFX.CHFUSD.1,CURRFX.CHFNZD.1,CURRFX.CHFJPY.1,CURRFX.CHFGBP.1,CURRFX.CHFEUR.1,CURRFX.EURUSD.1,CURRFX.EURNZD.1,CURRFX.EURJPY.1,CURRFX.EURGBP.1,CURRFX.GBPUSD.1,CURRFX.GBPNZD.1,CURRFX.GBPJPY.1,CURRFX.JPYUSD.1,CURRFX.JPYNZD.1,CURRFX.NZDUSD.1,YAHOO.INDEX_GDAXI.4,YAHOO.INDEX_FTSE.4,YAHOO.INDEX_AORD.4,NIKKEI.INDEX.4,YAHOO.INDEX_GSPTSE.4,OFDP.SILVER_5.1,WGC.GOLD_DAILY_USD.1,WSJ.COPPER.1,WSJ.CORN_2.1,WSJ.PL_MKT.1,OFDP.FUTURE_B1.4,FED.JRXWTFB_N_B.1&collapse=daily&trim_start=2005-01-01&auth_token=pWGUEdRoPxqEdp66WRYv"

cd $CURDIR/../../

find app/data/candles/*.* -type f -ctime +1 -exec rm {} \;
find app/data/breakout/*.* -type f -ctime +1 -exec rm {} \;
find .tmp/*.json -type f -ctime +1 -exec rm {} \;

rm app/data/multisetsOutputs.csv

Rscript server/scripts/multisets.r
Rscript server/scripts/portfolio.r