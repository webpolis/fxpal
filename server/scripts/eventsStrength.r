setwd("app/data/")

Sys.setenv(TZ="UTC")

opts = commandArgs(trailingOnly = TRUE)
weeks = ifelse((exists("opts") && !is.na(opts[1])), as.integer(opts[1]), 52)
cross1 = ifelse((exists("opts") && !is.na(opts[2])), opts[2], NA)
cross2 = ifelse((exists("opts") && !is.na(opts[3])), opts[3], NA)

calendar = fromJSON(file="calendar.json")
total = length(calendar$d)
last = calendar$d[[total]]
lastDate = gsub("([^\\s]+)(?:\\s+[^\\s]+){1,}","\\1",last$Released,perl=T)
endDate = format(Sys.Date(),format="%m/%d/%Y")

diffWeeks = as.integer(difftime(as.Date(endDate,format="%m/%d/%Y"),as.Date(lastDate,format="%m/%d/%Y"),units="weeks"))
startWeek = as.Date(format(Sys.Date(),format="%Y-%m-%d")) - as.difftime(diffWeeks,units="weeks")
startDate = format(startWeek,format="%m/%d/%Y")

url = "http://www.forex.com/UIService.asmx/getEconomicCalendarForPeriod"
params = toJSON(list(aStratDate=startDate,aEndDate=endDate))
headers = list('Accept' = 'application/json', 'Content-Type' = 'application/json')
ret = fromJSON(postForm(url, .opts=list(postfields=params, httpheader=headers)))

df = data.frame()
for(i in 1:length(ret$d)){
	
} 



getCurrenciesStrength <- function(w = 52, curr1=NA, curr2=NA){
	tmp = data
	startWeek = as.Date(format(Sys.Date(),format="%Y-%m-%d")) - as.difftime(w,units="weeks")
	tmp = tmp[tmp$date>=startWeek,]

	if(!is.na(curr1) && !is.na(curr2)){
		tmp = tmp[grep(paste(curr1,curr2,sep="|"), tmp$currency, ignore.case=TRUE),]
	}

	allValues = grep('actual',names(tmp))

	# invert value for unemployment
	inv = 'continu_claim|jobless_claim|unempl'
	tmp[grep(inv,tmp$event, ignore.case=TRUE),allValues] = transform(tmp[grep(inv,tmp$event, ignore.case=TRUE),allValues],actual=-actual)
	
	tmp = aggregate(tmp$actual, by=list(currency=tmp$currency,event=tmp$event),FUN=diff)
	tmp[,3] = sapply(tmp[,3],simplify=T,FUN=function(x) round(sum(x),6))
	names(tmp) = c("currency","event","value")
	tmp$scale = round(scale(tmp[,3], scale = TRUE, center = TRUE), 6)

	scaled = aggregate(tmp$value, by=list(currency=tmp$currency),FUN=mean)
	scaled = scaled[order(-scaled[,2]),]
	scaled[,2] = round(scale(scaled[,2], scale = TRUE, center = FALSE), 6)
	names(scaled) <- c("currency","strength")
	scaled$sd = sd(scaled$strength)
	scaled$strength = scale(scaled$strength+scaled$sd,center=F)
	return(scaled)
}

strength = getCurrenciesStrength(weeks, cross1, cross2)
outFile = paste('calendar',weeks,sep = '-')
if(!is.na(cross1) && !is.na(cross2)){
	outFile = paste(outFile,cross1,cross2, sep = '-')
}
outFile = paste(outFile,'strength', sep = '-')
write.csv(strength, quote = FALSE, row.names = FALSE, file = paste(outFile,'.csv',sep=''), fileEncoding = "UTF-8")

quit()
