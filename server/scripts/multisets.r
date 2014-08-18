pwd = ifelse(is.null(sys.frames()),getwd(),dirname(sys.frame(1)$ofile))
dataPath = paste(pwd,"/../../app/data/",sep="")

Sys.setenv(TZ="UTC")

data = read.table(paste(dataPath,"multisetsInputs.csv",sep=""), sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
names(data) = toupper(gsub("\\.{3}[\\w]+|QUANDL\\.|\\.Price", "", names(data), perl = TRUE))

data = data[-(match("DATE", colnames(data)))]

data = cor(data, use="pairwise.complete.obs", method="pearson")
correlation = as.data.frame(as.table(data))
correlation = na.omit(correlation)
names(correlation) = c("cross1", "cross2", "rel")
correlation = correlation[correlation$rel!=1,]

write.csv(correlation, quote = FALSE, row.names = FALSE, file = paste(dataPath,"multisetsOutputs.csv",sep=""), fileEncoding = "UTF-8")

quit()