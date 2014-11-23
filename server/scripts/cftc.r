pwd = ifelse(is.null(sys.frames()),getwd(),paste(dirname(sys.frame(1)$ofile),"/../..",sep=""))
source(paste(pwd,'server','scripts','header.r',sep='/'))

week = format(Sys.time(),'%U');
month = format(Sys.time(),'%m');
year = as.integer(format(Sys.time(),'%Y'));
data = getCOTData()

markets = list('CAD'='CANADIAN DOLLAR','CHF'='SWISS FRANC','GBP'='BRITISH POUND STERLING','JPY'='JAPANESE YEN','EUR'='EURO FX','NZD'='NEW ZEALAND DOLLAR','AUD'='AUSTRALIAN DOLLAR','USD'='U.S. DOLLAR INDEX','NIKKEI'='NIKKEI STOCK AVERAGE');
markets = as.list(as.data.frame(markets)[order(as.data.frame(markets))])

stats = Reduce(rbind,lapply(markets,getCOTPosition,data));
index(stats) <- names(markets) #c('AUD','GBP','CAD','EUR','JPY','NZD','NIKKEI','CHF','USD');

jpeg(paste(dataPath,'cot/COT-', month, '-',year, '.jpg', sep = ''),width=1334,height=750,quality=100,bg='dimgray');
barplot(as.matrix(t(stats)),ylab='Positioning',beside=T,col=c('olivedrab4','firebrick3','dodgerblue4'),cex.names=2,col.lab='white',col.axis='white',main='COT Status',col.main='white');

legend('topright', c('long','short','interest'), cex=c(2),pt.cex=c(3),col=c('olivedrab4','firebrick3','dodgerblue4'), lty=c(1,1,1),pch=c(15),pt.lwd=0,text.col='white');
grid();

logoPath = paste(dataPath,'../images/logo-s.png',sep='');
logo = readPNG(logoPath);
addCopyright(paste('Powered by ',sep=''),logo,x = unit(0.5, 'npc'), y = unit(0.9345, 'npc'),1,fontsize=10, col='white');

dev.off();