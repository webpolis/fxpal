library(TTR)

year = format(Sys.time(),"%Y")
url = "http://www.cftc.gov/files/dea/history/deahistfo{{year}}.zip"
urlFinal = gsub("\\{\\{year\\}\\}",year,url)
reportName = "annualof.txt"
tmp = tempfile()
download.file(urlFinal,tmp)
unzip(tmp,files=c(reportName))
data = read.table(reportName, sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
data = subset(data,CFTC.Market.Code.in.Initials=="CME"|CFTC.Market.Code.in.Initials=="ICUS")
data[,1] = gsub("(.*)\\s+\\-\\s+.*","\\1",data[,1],ignore.case=T,perl=T)

getPosition <- function(currency){
	curr = subset(data,Market.and.Exchange.Names==currency)
	oInterest = diff(rev(curr$Open.Interest..All.))
	longNC = diff(rev(curr$Noncommercial.Positions.Long..All.))
	shortNC = diff(rev(curr$Noncommercial.Positions.Short..All.))
	ret = as.data.frame(merge(last(longNC),last(shortNC)))
	ret = merge(ret,as.data.frame(last(oInterest)))
	rownames(ret) = c(currency)
	names(ret) = c("long","short","interest")
	return(ret)
}

currencies = c("CANADIAN DOLLAR","SWISS FRANC","BRITISH POUND STERLING","JAPANESE YEN","EURO FX","BRAZILIAN REAL","NEW ZEALAND DOLLAR","AUSTRALIAN DOLLAR", "U.S. DOLLAR INDEX")

stats = Reduce(rbind,lapply(currencies,getPosition))

unlink(tmp)
unlink(reportName)

plot.ts(stats,plot.type=c("single"),col=c("green","red","black"),axes=F,xlab="currency")
axis(1,at=1:9,labels=row.names(stats),cex.axis=0.5)
axis(2,cex.axis=0.5,at=seq(min(stats),max(stats),by=5000))
legend("topright", c("long","short","interest"), cex=0.8,col=c("green","red","black"), lty=c(1,1,1))
abline(h=0,lty=c(3))