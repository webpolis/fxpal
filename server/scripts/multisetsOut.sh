#!/bin/bash
CURDIR=$(dirname "$0")
#TAB=$'\t'
#cat $CURDIR/../../app/data/multisetsOutputsRaw.csv | sed "s/$TAB/,/g" | awk 'BEGIN {FS =","; print "cross1,cross2,rel";} $3 !~ "NaN" {print $0}' > $CURDIR/../../app/data/multisetsOutputs.csv
Rscript $CURDIR/multisets.r