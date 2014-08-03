setwd("app/data/")

Sys.setenv(TZ="UTC")

opts = commandArgs(trailingOnly = TRUE)
weeks = ifelse((exists("opts") && !is.na(opts[1])), as.integer(opts[1]), 52)
cross1 = ifelse((exists("opts") && !is.na(opts[2])), opts[2], NA)
cross2 = ifelse((exists("opts") && !is.na(opts[3])), opts[3], NA)

data = read.csv("calendar.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
data = na.omit(data)
data[,1] = as.Date(data[,1])

getCurrenciesStrength <- function(w = 52, curr1=NA, curr2=NA){
	tmp = data
	startWeek = as.Date(format(Sys.Date(),format="%Y-%m-%d")) - as.difftime(w,units="weeks")
	tmp = tmp[tmp$date>=startWeek,]

	if(!is.na(curr1) && !is.na(curr2)){
		tmp = tmp[grep(paste(curr1,curr2,sep="|"), tmp$currency, ignore.case=TRUE),]
	}

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
	scaled$sd = sd(scaled$strength)
	return(scaled)
}

strength = getCurrenciesStrength(weeks, cross1, cross2)
