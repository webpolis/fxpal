library("xts")

Sys.setenv(TZ="UTC")

pwd = ifelse(is.null(sys.frames()),getwd(),paste(dirname(sys.frame(1)$ofile),"/../..",sep=""))
dataPath = paste(pwd,"/app/data/",sep="")

qs = list.files(paste(dataPath,"quandl/",sep=""),pattern="([^\\.]+\\.){3}csv",full.names=T)

if (exists("dataset")){
	rm(dataset)
}

for (file in qs){
	if (!exists("dataset")){
		# if the merged dataset doesn't exist, create it
		dataset = read.csv(file, sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
		rownames(dataset) = as.Date(dataset[,1])
		dataset$Date = NULL
		dataset = as.xts(dataset)
	}else{
		# if the merged dataset does exist, append to it
		tmp = read.csv(file, sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
		rownames(tmp) = as.Date(tmp[,1])
		tmp$Date = NULL
		tmp$Trade.Date = NULL
		tmp = as.xts(tmp)
		dataset = merge.xts(dataset, tmp)
		rm(tmp)
	}
}

tmp = as.data.frame(dataset)
tmp$Date = as.Date(index(dataset))
write.csv(tmp, quote = FALSE, row.names = FALSE, file = paste(dataPath,"multisetsInputs.csv",sep=""), fileEncoding = "UTF-8")
rm(tmp)

names(dataset) = toupper(gsub("\\.{3}[\\w]+|CURRFX\\.|\\.\\d+|\\.Price", "", names(dataset), perl = TRUE))

dataset = cor(dataset, use="pairwise.complete.obs", method="pearson")
correlation = as.data.frame(as.table(dataset))
correlation = na.omit(correlation)
names(correlation) = c("cross1", "cross2", "rel")
correlation = correlation[correlation$rel!=1,]

write.csv(correlation, quote = FALSE, row.names = FALSE, file = paste(dataPath,"multisetsOutputs.csv",sep=""), fileEncoding = "UTF-8")

quit()