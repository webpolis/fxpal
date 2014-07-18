### Datasets

Datasets included in this software are crucial. In parallel, RapidMiner is used to process and generate new data.
To generate and optimize datasets, follow these guidelines:

* Retrieve economic calendars: `./server/scripts/calendar.sh`
* Retrieve multisets (currencies + indexes + commodities historical data): `./server/scripts/multiset.sh`
* Once multisets are ready, execute RapidMiner w/process in `./app/data/multisets.xml`. This will generate a correlation matrix for the above dataset.
* Copy the **Pairwise Table** in `./app/data/multisetsOutputsRaw.csv`.
* Replace *tabs* with *,* and use *cross1,cross2,rel* as the first line (columns names) in a new output file at `./app/data/multisetsOutputs.csv`

Now, we are going to generate a new correlation matrix between *currencies* and *economic indicators* (calendars):

* Execute `node ./server/scripts/merge.js`
