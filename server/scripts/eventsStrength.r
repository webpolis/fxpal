setwd("app/data/")

Sys.setenv(TZ="UTC")

data = read.csv("calendar.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
data = na.omit(data)

getCurrenciesStrength <- function(tmp){
	allValues = grep('actual|previous',names(tmp))

	# invert value for unemployment
	tmp[grep('continu_claim|jobless_claim|unempl',tmp$event, ignore.case=TRUE),allValues] = transform(tmp[grep('continu_claim|jobless_claim|unempl',tmp$event, ignore.case=TRUE),allValues],actual=-actual,previous=-previous)

	tmp = aggregate(tmp$actual, by=list(currency=tmp$currency,event=tmp$event),FUN=diff)
	tmp[,3] = sapply(tmp[,3],simplify=T,FUN=function(x) round(sum(x),6))
	names(tmp) = c("currency","event","value")
	tmp$scale = round(scale(tmp[,3], scale = TRUE, center = TRUE), 6)

	scaled = aggregate(tmp$value, by=list(currency=tmp$currency),FUN=mean)
	scaled = scaled[order(-scaled[,2]),]
	scaled[,2] = round(scale(scaled[,2], scale = TRUE, center = FALSE), 6)
	names(scaled) <- c("currency","strength")
	return(scaled)
}

