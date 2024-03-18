#!/bin/bash

MIN=$1
MAX=$2
CSV_TPL=$3 # current data
CSV_SAMPLE=$4 # historical data where to find similar patterns
DIST_MAX=$5

for i in $(seq $MIN $MAX); do ./CVMatcher $CSV_TPL $CSV_SAMPLE $i $DIST_MAX; done
