#!/bin/bash
CURDIR=$(dirname "$0")

curl -G -A "Mozilla/5.0 (Windows NT 6.1; rv:19.0) Gecko/20100101 Firefox/19.0" -o $CURDIR/../../app/data/multisetsInputs.csv "http://quandl.com/api/v1/multisets.csv?columns=QUANDL.AUDUSD.1,QUANDL.AUDNZD.1,QUANDL.AUDJPY.1,QUANDL.AUDGBP.1,QUANDL.AUDEUR.1,QUANDL.AUDCHF.1,QUANDL.AUDCAD.1,QUANDL.CADUSD.1,QUANDL.CADNZD.1,QUANDL.CADJPY.1,QUANDL.CADGBP.1,QUANDL.CADEUR.1,QUANDL.CADCHF.1,QUANDL.CHFUSD.1,QUANDL.CHFNZD.1,QUANDL.CHFJPY.1,QUANDL.CHFGBP.1,QUANDL.CHFEUR.1,QUANDL.EURUSD.1,QUANDL.EURNZD.1,QUANDL.EURJPY.1,QUANDL.EURGBP.1,QUANDL.GBPUSD.1,QUANDL.GBPNZD.1,QUANDL.GBPJPY.1,QUANDL.JPYUSD.1,QUANDL.JPYNZD.1,QUANDL.NZDUSD.1,YAHOO.INDEX_GDAXI.4,YAHOO.INDEX_FTSE.4,YAHOO.INDEX_AORD.4,NIKKEI.INDEX.4,YAHOO.INDEX_GSPTSE.4,OFDP.SILVER_5.1,WGC.GOLD_DAILY_USD.1,WSJ.COPPER.1,WSJ.CORN_2.1,WSJ.PL_MKT.1,OFDP.FUTURE_B1.4,FED.JRXWTFB_N_B.1&collapse=daily&trim_start=2005-01-01&auth_token=pWGUEdRoPxqEdp66WRYv"

cd $CURDIR
Rscript $CURDIR/multisets.r

# to properly set pwd inside R script
cd $CURDIR/../../
Rscript server/scripts/candlesticks.r 1 2 3 volatility
