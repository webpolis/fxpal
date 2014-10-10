library(TTR)

year = format(Sys.time(),"%Y")
url = "http://www.cftc.gov/files/dea/history/deahistfo{{year}}.zip"
urlFinal = gsub("\\{\\{year\\}\\}",year,url)
reportName = "annualof.txt"
tmp = tempfile()
download.file(urlFinal,tmp)
unzip(tmp,files=c(reportName))
data = read.table(reportName, sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
data = subset(data,CFTC.Market.Code.in.Initials=="CME")
data[,1] = gsub("(.*)\\s+\\-\\s+.*","\\1",data[,1],ignore.case=T,perl=T)

getPosition <- function(currency){
	curr = subset(data,Market.and.Exchange.Names==currency)
	longNC = diff(rev(curr$Noncommercial.Positions.Long..All.))
	shortNC = diff(rev(curr$Noncommercial.Positions.Short..All.))
	ret = as.data.frame(merge(last(longNC),last(shortNC)))
	rownames(ret) = c(currency)
	names(ret) = c("long","short")
	return(ret)
}

currencies = c("CANADIAN DOLLAR","SWISS FRANC","BRITISH POUND STERLING","JAPANESE YEN","EURO FX","BRAZILIAN REAL","NEW ZEALAND DOLLAR","AUSTRALIAN DOLLAR")

stats = Reduce(rbind,lapply(currencies,getPosition))

unlink(tmp)
unlink(reportName)