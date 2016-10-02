pwd = ifelse(is.null(sys.frames()),paste(getwd(),"/server/scripts",sep=""),dirname(sys.frame(1)$ofile))
dataPath = paste(pwd,"/../../app/data/",sep="")

Sys.setenv(TZ="UTC")

library("xts")
library("fPortfolio")
library("quantmod")
library("financeR")

#stocks = c("AMZN", "DOX", "AXP", "BRK-A", "TSLA", "TEVA", "PG", "AAPL", "CSCO", "CAT", "XOM", "GM", "GOOG", "INTC", "JNJ", "PFE", "BP", "SAP", "GSK", "SIE.DE", "VZ", "GS")
#stocks = c("ADBE","ADSK","ALU.PA","AMX","ARM.L","ATVI","BIDU","CAP.PA","CHKP","CHL","CSCO","DMGT.L","DTE.DE","EA","FB","FSLR","GOOG","HPQ","IBM","IFX.DE","INTC","KING","LNKD","MSFT","MSI","MU","NOK","NVDA","ORCL","RENN","SAP.DE","SGE.L","SNDK", "TEF","TEO","TRIP","TWTR","VOD","VOD.L","VZ","WDC","YHOO","YNDX","ZNGA")
#stocks = strsplit("AAL.L,ABF.L,AC.PA,ACA.PA,ADBE,ADN.L,ADS.DE,ADSK,AGK.L,AGNC,AHT.L,AI.PA,AIR.PA,ALO.PA,ALU.PA,ALV.DE,AMGN,ANF,ANTO.L,ARM.L,ATVI,AV.L,AZN.L,BAB.L,BABA,BARC.L,BAS.DE,BATS.L,BAYN.DE,BEI.DE,BG.L,BIDU,BLND.L,BLT.L,BMW.DE,BN.PA,BNP.PA,BNZL.L,BOSS.DE,BP.L,BRBY.L,CA.PA,CAP.PA,CAR,CBK.DE,CCH.L,CCL.L,CHKP,CNA.L,CON.DE,CPG.L,CPI.L,CRH.L,CS.PA,DAI.DE,DB1.DE,DEM,DG.PA,DGE.L,DMGT.L,DPS,DPW.DE,DTE.DE,EA,EDF.PA,EI.PA,EN.PA,EOAN.DE,EXPN.L,EZJ.L,FDX,FME.DE,FP.PA,FR.PA,FRE.DE,FRES.L,FSLR,GFS.L,GKN.L,GLE.PA,GLEN.L,GPS,GSK.L,HEI.DE,HEN3.DE,HL.L,HMSO.L,HOG,HSBA.L,IAG.L,IFX.DE,IHG.L,IMI.L,IMT.L,ITRK.L,ITV.L,JMAT.L,KER.PA,KGF.L,KING,LAND.L,LG.PA,LGEN.L,LHA.DE,LIN.DE,LLOY.L,LMT,LNKD,LR.PA,LSE.L,LVS,LXS.DE,MC.PA,MGGT.L,MKS.L,ML.PA,MNDI.L,MOS,MRK.DE,MRO.L,MRW.L,MSI,MU,MUV2.DE,NBL,NFLX,NG.L,NOK,NVDA,NXT.L,OML.L,OR.PA,ORA.PA,ORCL,PETM,PFC.L,POT,PRU.L,PSN.L,PSON.L,PUB.PA,RB.L,RBS.L,RDSA.L,REL.L,REX.L,RI.PA,RIO.L,RL,RMG.L,RNO.PA,RR.L,RRS.L,RSA.L,RWE.DE,SAB.L,SAF.PA,SAP.DE,SBRY.L,SBUX,SDF.DE,SDR.L,SGE.L,SGO.PA,SHP.L,SIE.DE,SL.L,SMIN.L,SN.L,SNDK,SPD.L,SSE.L,STAN.L,STZ,SU.PA,SVT.L,TATE.L,TEC.PA,TKA.DE,TLW.L,TPK.L,TRIP,TSCO.L,TSLA,TT.L,TV,TWTR,UG.PA,ULVR.L,URBN,UU.L,VIE.PA,VIV.PA,VOD.L,VOW3.DE,WDC,WEIR.L,WMH.L,WOS.L,WPP.L,WTB.L,WU", ",")[[1]]
#stocks = strsplit("FME.DE,PETM,RB.L,ABF.L,RRS.L,BAB.L,TT.L,LMT,NG.L,IMT.L,GSK.L,CPI.L,SHP.L,CHKP,SSE.L,MT.PA,TATE.L,NFLX,CNA.L,BIDU,MRW.L,BATS.L,FRE.DE,ULVR.L,AMGN,TWTR", ",")[[1]]

#merval
stocks = read.table(paste0(dataPath, "merval.csv"), sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")$symbol
stocks = as.character(lapply(stocks,FUN=function(x){paste(x,"BA",sep=".")}))

tickers = getSymbols(stocks, auto.assign = TRUE)

dataset <- Ad(get(tickers[1]))
for (i in 2:length(tickers)) {
	dataset <- merge(dataset, Ad(get(tickers[i])))
}

return_lag <- 5
data <- na.omit(ROC(na.spline(dataset), return_lag, type = "discrete"))
scenarios <- dim(data)[1]
assets <- dim(data)[2]
names(data) <- stocks

tmp = as.timeSeries(data)
spec = portfolioSpec()
setNFrontierPoints(spec) <- 10
constraints <- c("LongOnly")
setSolver(spec) <- "solveRquadprog"
setTargetReturn(spec) <- mean(colMeans(tmp))

# portfolioConstraints(data, spec, constraints)
# frontier <- portfolioFrontier(data, spec, constraints)
# print(frontier)
# tailoredFrontierPlot(object = frontier)

tp = tangencyPortfolio(tmp, spec, constraints)
mp = maxreturnPortfolio(tmp, spec, constraints)
ep = efficientPortfolio(tmp, spec, constraints)
tpWeights = getWeights(tp)
mpWeights = getWeights(mp)
epWeights = getWeights(ep)

mediumWeights = round((tpWeights + mpWeights + epWeights) / 3, 6)
names(mediumWeights) = names(tmp)
mediumWeights = sort(mediumWeights, decreasing = TRUE)

out = as.data.frame(mediumWeights)
out = data.frame(cross = names(mediumWeights), percentage = mediumWeights)
out=out[out$percentage>0,]

#barplot(height = out$percentage,names.arg = out$cross,cex.names = 0.5)

outFile = "stocksPortfolio"

write.csv(out, quote = FALSE, row.names = FALSE, file = paste(dataPath, paste(outFile,'.csv',sep=''),sep=""), fileEncoding = "UTF-8")
