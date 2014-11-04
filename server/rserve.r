library(Rserve)

pwd = ifelse(is.null(sys.frames()),getwd(),paste(dirname(sys.frame(1)$ofile),"/..",sep=""));
header = paste(pwd,"server","scripts","header.r",sep="/")

Rserve(debug=TRUE,args=paste("--RS-enable-control","--no-save","--RS-source",header,"--RS-workdir",paste(pwd,"/",sep=""),sep=" "))