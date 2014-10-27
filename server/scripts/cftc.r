library(TTR)

year = format(Sys.time(),"%Y")
url = "http://www.cftc.gov/files/dea/history/deacot{{year}}.zip"
urlFinal = gsub("\\{\\{year\\}\\}",year,url)
reportName = "annual.txt"
tmp = tempfile()
download.file(urlFinal,tmp)
unzip(tmp,files=c(reportName))
data = read.table(reportName, sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
data = subset(data,CFTC.Market.Code.in.Initials=="CME"|CFTC.Market.Code.in.Initials=="ICUS")
data[,1] = gsub("(.*)\\s+\\-\\s+.*","\\1",data[,1],ignore.case=T,perl=T)

getPosition <- function(currency){
	curr = subset(data,Market.and.Exchange.Names==currency)
	cl = ROC(rev(curr$Noncommercial.Positions.Long..All.),type="discrete")
	cs = ROC(rev(curr$Noncommercial.Positions.Short..All.),type="discrete")
	ci = ROC(rev(curr$Open.Interest..All.),type="discrete")
	pos = matrix(c(cl,cs,ci),ncol=3,dimnames=list(NULL,c("long","short","interest")))
	ret = last(zoo(pos))
	index(ret) = c(currency)
	return(ret)
}

currencies = c("CANADIAN DOLLAR","SWISS FRANC","BRITISH POUND STERLING","JAPANESE YEN","EURO FX","NEW ZEALAND DOLLAR","AUSTRALIAN DOLLAR","U.S. DOLLAR INDEX","NIKKEI STOCK AVERAGE")

stats = Reduce(rbind,lapply(currencies,getPosition))

unlink(tmp)
unlink(reportName)

dev.new()
barplot(as.matrix(t(stats)),main="COT - Rate of Change",ylab="Positioning",beside=T,col=c("green","red","blue"),cex.names=0.35,width=0.75)
legend("bottomright", c("long","short","interest"), cex=0.8,col=c("green","red","blue"), lty=c(1,1,1))
grid()