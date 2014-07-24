setwd("app/data/")
data = read.csv("multisetsInputs.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, fileEncoding = "UTF-8")
names(data) = toupper(gsub("\\.{3}[\\w]+|QUANDL\\.|\\.Price", "", names(data), perl = TRUE))

crosses1 = colnames(data)
crosses1 = crosses1[-(match("Date", crosses1))]
crosses2 = rev(crosses1)
crosses = matrix(nrow = length(crosses1), ncol = length(crosses2), dimnames = list(crosses1, crosses2))

for(cross1 in crosses1){
	for(cross2 in crosses2){
		if(cross1 == cross2){
			next
		}
		if(is.na(crosses[cross1,cross2]) && is.na(crosses[cross2,cross1])){
			corValue = cor(data[,cross1], data[,cross2], use = "pairwise.complete.obs", method = "pearson")
			crosses[cross1,cross2] = corValue
		}
	}
}

correlation = as.data.frame(as.table(crosses))
correlation = na.omit(correlation)
names(correlation) = c("cross1", "cross2", "rel")
write.csv(correlation, quote = FALSE, file = "multisetsOutputs.csv", fileEncoding = "UTF-8")

quit()