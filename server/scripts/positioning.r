pwd = ifelse(is.null(sys.frames()),getwd(),paste(dirname(sys.frame(1)$ofile),"/../..",sep=""))
source(paste(pwd,'server','scripts','header.r',sep='/'))

opts = commandArgs(trailingOnly = TRUE)
instrument = sub("(\\w{3})_?(\\w{3})", "\\1/\\2", ifelse((length(opts)>0 && !is.na(opts[1])), opts[1], NA))
curr1 = sub("(\\w{3})_?(\\w{3})", "\\1", instrument)
curr2 = sub("(\\w{3})_?(\\w{3})", "\\2", instrument)
currency1 = ifelse((length(opts)>0 && !is.na(opts[2])), opts[2], NA)
currency2 = ifelse((length(opts)>0 && !is.na(opts[3])), opts[3], NA)
batch = ifelse((length(opts)>0 && !is.na(opts[4])), as.integer(opts[4]), 0)

if(!is.na(instrument)&!is.na(currency1)&!is.na(currency2) && !batch){
	args = paste('{"instrument":"',instrument,'","currency1":"',currency1,'", "currency2":"',currency2,'"}',sep='')
	qfxGraphCOTPositioning(args)
}

if(batch){
	crosses = read.csv(paste(dataPath,'availableCrosses.csv',sep=''), sep = ',', dec = '.', strip.white = TRUE, header=TRUE, encoding = 'UTF-8')
	crosses = as.character(crosses$displayName)

	markets = list('CAD'='CANADIAN DOLLAR','CHF'='SWISS FRANC','GBP'='BRITISH POUND STERLING','JPY'='JAPANESE YEN','EUR'='EURO FX','NZD'='NEW ZEALAND DOLLAR','AUD'='AUSTRALIAN DOLLAR','USD'='U.S. DOLLAR INDEX','NIKKEI'='NIKKEI STOCK AVERAGE');
	markets = as.list(as.data.frame(markets)[order(as.data.frame(markets))])

	for(cross in crosses){
		curr1 = sub("(\\w{3})\\/?(\\w{3})", "\\1", cross)
		curr2 = sub("(\\w{3})\\/?(\\w{3})", "\\2", cross)
		currency1 = markets[[curr1]]
		currency2 = markets[[curr2]]

		args = paste('{"instrument":"',cross,'","currency1":"',currency1,'", "currency2":"',currency2,'"}',sep='')
		qfxGraphCOTPositioning(args)
	}
}