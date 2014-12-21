Sys.setenv(TZ="UTC")

pwd = ifelse(is.null(sys.frames()),getwd(),paste(dirname(sys.frame(1)$ofile),"/../..",sep=""))
dataPath = paste(pwd,"/app/data/",sep="")

qs = list.files(paste(dataPath,"quandl/",sep=""),pattern="([^\\.]+\\.){3}csv",full.names=T)

rm(dataset)
for (file in qs){
	# if the merged dataset doesn't exist, create it
	if (!exists("dataset")){
		dataset = read.csv(file, sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
	}

	# if the merged dataset does exist, append to it
	if (exists("dataset")){
		tmp = read.csv(file, sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
		dataset = merge(dataset, tmp, all.x=T)
		rm(tmp)
	}
}

write.csv(dataset, quote = FALSE, row.names = FALSE, file = paste(dataPath,"multisetsInputs.csv",sep=""), fileEncoding = "UTF-8")

names(dataset) = toupper(gsub("\\.{3}[\\w]+|CURRFX\\.|\\.\\d+|\\.Price", "", names(dataset), perl = TRUE))

dataset = dataset[-(match("DATE", colnames(dataset)))]

dataset = cor(dataset, use="pairwise.complete.obs", method="pearson")
correlation = as.data.frame(as.table(dataset))
correlation = na.omit(correlation)
names(correlation) = c("cross1", "cross2", "rel")
correlation = correlation[correlation$rel!=1,]

write.csv(correlation, quote = FALSE, row.names = FALSE, file = paste(dataPath,"multisetsOutputs.csv",sep=""), fileEncoding = "UTF-8")

quit()