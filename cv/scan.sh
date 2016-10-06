#!/bin/bash

MIN=$1
MAX=$2
CSV=$3

for i in $(seq $MIN $MAX); do ./main $CSV $i; done

