library(Rserve)

pwd = ifelse(is.null(sys.frames()),getwd(),paste(dirname(sys.frame(1)$ofile),"/..",sep=""));
header = paste(pwd,"server","scripts","header.r",sep="/")
socket = paste(pwd,"server","socket",sep="/")

Rserve(debug=TRUE,args=paste("--RS-enable-control","--vanilla","--RS-source",header,"--RS-workdir",paste(pwd,"/",sep=""),"--RS-socket",socket,sep=" "))