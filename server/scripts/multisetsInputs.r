setwd("app/data/")
data = read.csv("multisetsInputs.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, fileEncoding = "UTF-8")

crosses1 = colnames(data)
crosses1 = crosses1[-(match("Date", crosses1))]
crosses2 = rev(crosses1)
crosses = matrix(nrow = length(crosses1), ncol = length(crosses2), dimnames = list(crosses1, crosses2))

for(cross1 in crosses1){
	for(cross2 in crosses2){
		corValue = cor(data[,cross1], data[,cross2], use = "pairwise.complete.obs", method = "pearson")
		crosses[cross1,cross2] = corValue
	}
}

correlation = as.data.frame(as.table(crosses))
correlation = na.omit(correlation)
names(correlation) = c("cross1", "cross2", "rel")
write.csv(correlation, quote = FALSE, file = "multisetsOutputs.csv", fileEncoding = "UTF-8")

quit()