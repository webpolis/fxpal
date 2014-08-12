tmp = read.table("/Volumes/KINGSTON/annualof.txt", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
tmp = subset(tmp,CFTC.Market.Code.in.Initials=="CME")
tmp[,1] = gsub("(.*)\\s+\\-\\s+.*","\\1",tmp[,1],ignore.case=T,perl=T)

getPosition <- function(currency){
	curr = subset(tmp,Market.and.Exchange.Names==currency)
	longNC = diff(rev(curr$Noncommercial.Positions.Long..All.))
	shortNC = diff(rev(curr$Noncommercial.Positions.Short..All.))
	ret = as.data.frame(merge(last(longNC),last(shortNC)))
	rownames(ret) = c(currency)
	names(ret) = c("long","short")
	return(ret)
}

currencies = c("CANADIAN DOLLAR","SWISS FRANC","BRITISH POUND STERLING","JAPANESE YEN","EURO FX","BRAZILIAN REAL","NEW ZEALAND DOLLAR","AUSTRALIAN DOLLAR")