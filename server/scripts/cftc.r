Sys.setenv(TZ="UTC")

pwd = ifelse(is.null(sys.frames()),getwd(),paste(dirname(sys.frame(1)$ofile),"/../..",sep=""))
dataPath = paste(pwd,"/app/data/",sep="")

source(paste(pwd,'server','scripts','header.r',sep='/'))

data = getCOTData()

currencies = c('CANADIAN DOLLAR','SWISS FRANC','BRITISH POUND STERLING','JAPANESE YEN','EURO FX','NEW ZEALAND DOLLAR','AUSTRALIAN DOLLAR','U.S. DOLLAR INDEX','NIKKEI STOCK AVERAGE');

stats = Reduce(rbind,lapply(currencies,getCOTPosition,data));
index(stats) <- c('AUD','GBP','CAD','EUR','JPY','NZD','NIKKEI','CHF','USD');

unlink(tmp);
unlink(reportName);

jpeg(paste(dataPath,'cot/COT-', month, '-',year, '.jpg', sep = ''),width=1334,height=750,quality=100,bg='dimgray');
barplot(as.matrix(t(stats)),ylab='Positioning',beside=T,col=c('olivedrab4','firebrick3','dodgerblue4'),cex.names=2,col.lab='white',col.axis='white',main='COT Status',col.main='white');

legend('topright', c('long','short','interest'), cex=c(2),pt.cex=c(3),col=c('olivedrab4','firebrick3','dodgerblue4'), lty=c(1,1,1),pch=c(15),pt.lwd=0,text.col='white');
grid();

logoPath = paste(dataPath,'../images/logo-s.png',sep='');
logo = readPNG(logoPath);
addCopyright(paste('Powered by ',sep=''),logo,x = unit(0.5, 'npc'), y = unit(0.9345, 'npc'),1,fontsize=10, col='white');

dev.off();