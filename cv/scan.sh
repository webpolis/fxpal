#!/bin/bash

MIN=$1
MAX=$2
CSV_TPL=$3
CSV_SAMPLE=$4

for i in $(seq $MIN $MAX); do ./main $CSV_TPL $CSV_SAMPLE $i; done
