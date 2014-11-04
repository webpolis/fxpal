day = format(Sys.time(),"%d");
month = format(Sys.time(),"%m");
year = format(Sys.time(),"%Y");

url = "http://www.cftc.gov/files/dea/history/deacot{{year}}.zip";
urlFinal = gsub("\\{\\{year\\}\\}",year,url);
reportName = "annual.txt";
tmp = tempfile(tmpdir="/tmp");
download.file(urlFinal,tmp);
unzip(tmp,files=c(reportName));
data = read.table(reportName, sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8");
data = subset(data,CFTC.Market.Code.in.Initials=="CME"|CFTC.Market.Code.in.Initials=="ICUS");
data[,1] = gsub("(.*)\\s+\\-\\s+.*","\\1",data[,1],ignore.case=T,perl=T);

currencies = c("CANADIAN DOLLAR","SWISS FRANC","BRITISH POUND STERLING","JAPANESE YEN","EURO FX","NEW ZEALAND DOLLAR","AUSTRALIAN DOLLAR","U.S. DOLLAR INDEX","NIKKEI STOCK AVERAGE");

stats = Reduce(rbind,lapply(currencies,getPosition));
index(stats) <- c("AUD","GBP","CAD","EUR","JPY","NZD","NIKKEI","CHF","USD");

unlink(tmp);
unlink(reportName);

jpeg(paste(dataPath,"cot/COT-", month, "-",year, ".jpg", sep = ""),width=1334,height=750,quality=100,bg="dimgray");
barplot(as.matrix(t(stats)),ylab="Positioning",beside=T,col=c("olivedrab4","firebrick3","dodgerblue4"),cex.names=2,width=0.75,col.lab="white",col.axis="white",main="COT Status",col.main="white");

legend("topright", c("long","short","interest"), cex=1.5,col=c("olivedrab4","firebrick3","dodgerblue4"), lty=c(1,1,1),pch=22,text.col="white");
grid();

logoPath = paste(dataPath,"../images/logo-s.png",sep="");
logo = readPNG(logoPath);
addCopyright(paste("Powered by ",sep=""),logo,x = unit(0.5, "npc"), y = unit(0.9345, "npc"),1,fontsize=10, col="white");

dev.off();