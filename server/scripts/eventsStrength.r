opts = commandArgs(trailingOnly = TRUE)
weeks = ifelse((exists('opts') && !is.na(opts[1])), as.integer(opts[1]), 52)
cross1 = ifelse((exists('opts') && !is.na(opts[2])), opts[2], NA)
cross2 = ifelse((exists('opts') && !is.na(opts[3])), opts[3], NA)
reDate = '([^\\s]+)(?:\\s+[^\\s]+){1,}'

calendar = fromJSON(file=paste(dataPath,'calendar.json',sep=''))
total = length(calendar$d)
last = calendar$d[[total]]
lastDate = gsub(reDate,'\\1',last$Released,perl=T)
endDate = format(Sys.Date(),format='%m/%d/%Y')

diffWeeks = as.integer(difftime(as.Date(endDate,format='%m/%d/%Y'),as.Date(lastDate,format='%m/%d/%Y'),units='weeks'))
startWeek = as.Date(format(Sys.Date(),format='%Y-%m-%d')) - as.difftime(diffWeeks,units='weeks')
startDate = format(startWeek,format='%m/%d/%Y')

url = 'http://www.forex.com/UIService.asmx/getEconomicCalendarForPeriod'
params = toJSON(list(aStratDate=startDate,aEndDate=endDate))
headers = list('Accept' = 'application/json', 'Content-Type' = 'application/json')
ret = fromJSON(postForm(url, .opts=list(postfields=params, httpheader=headers)))

calendar = append(calendar$d, ret$d)

df = data.frame()
for(i in 1:length(calendar)){
	cal = calendar[[i]]
	if(length(cal$Data)==0){
		next
	}
	rowData = sapply(cal$Data,unlist)
	actual = rowData['Actual',]
	actual = actual[actual!='' && !is.na(actual)]

	if(length(actual)==0){
		next
	}

	tmpDf = data.frame()
	actual = as.numeric(na.omit(actual))
	avg = mean(actual)
	tmpDf[1,'name'] = cal$Name
	tmpDf[1,'code'] = cal$EventCode
	tmpDf[1,'country'] = cal$Country
	tmpDf[1,'date'] = cal$Released
	tmpDf[1,'actual'] = avg
	df = rbind(tmpDf,df)
}

df$date = gsub(reDate,'\\1',df$date,perl=T)
df$date = as.Date(df$date,format='%m/%d/%Y')
df = df[order(df$date),]

getCurrenciesStrength <- function(w = 52, curr1=NA, curr2=NA){
	tmp = df
	startWeek = as.Date(format(Sys.Date(),format='%Y-%m-%d')) - as.difftime(w,units='weeks')
	tmp = tmp[tmp$date>=startWeek,]

	if(!is.na(curr1) && !is.na(curr2)){
		tmp = tmp[grep(paste(curr1,curr2,sep='|'), tmp$country, ignore.case=TRUE),]
	}

	# invert value for unemployment
	inv = 'unempl|jobless'
	tmp[grep(inv,tmp$name, ignore.case=TRUE),'actual'] = -(tmp[grep(inv,tmp$name, ignore.case=TRUE),'actual'])
	
	tmp = aggregate(tmp$actual, by=list(code=tmp$code,country=tmp$country),FUN=diff)
	tmp[,'x'] = sapply(tmp[,'x'],simplify=T,FUN=function(n) round(sum(n),6))
	tmp$scale = round(scale(tmp[,'x'], scale = TRUE, center = FALSE), 6)
	tmp = tmp[!is.na(tmp$scale),]

	scaled = aggregate(tmp$scale, by=list(country=tmp$country),FUN=mean)
	names(scaled) <- c('country','strength')
	scaled = scaled[order(-scaled[,'strength']),]
	scaled[,'strength'] = round(scale(scaled[,'strength'], scale = TRUE, center = FALSE), 6)
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
write.csv(strength, quote = FALSE, row.names = FALSE, file =  paste(dataPath, paste(outFile,'.csv',sep=''),sep=''), fileEncoding = 'UTF-8')

quit()
