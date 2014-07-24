## Requirements

* [node](http://nodejs.org)
* [R](http://www.r-project.org/)

### Datasets

Datasets included in this software are crucial. In parallel, RapidMiner is used to process and generate new data.
To generate and optimize datasets, follow these guidelines:

* Retrieve multisets (currencies + indexes + commodities historical data): `./server/scripts/multiset.sh`
* Execute `./server/scripts/multisetsOut.sh` to generate the final output in `./app/data/multisetsOutputs.csv`

Now, we are going to generate a new correlation matrix between *currencies* and *economic indicators* (calendars):

* Retrieve weekly economic calendars: `./server/scripts/calendar.sh`
* Execute `node ./server/scripts/merge.js -c` to generate the full historical calendar
* Execute `node ./server/scripts/merge.js -e` to merge events in calendar with crosses values
* Execute `./server/scripts/eventsCrossesOut.sh` to generate the final output in `./app/data/eventsCrossesOutputs.csv`
