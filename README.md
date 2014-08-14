## Requirements

* [node](http://nodejs.org)
* [R](http://www.r-project.org/)

### Datasets

Datasets included in this software are crucial. To generate and optimize datasets, follow these guidelines:

* Retrieve multisets (currencies + indexes + commodities historical data): `./server/scripts/multiset.sh`
* Execute `./server/scripts/eventsCrossesOut.sh` to generate the final output in `./app/data/eventsCrossesOutputs.csv`
