source(paste(pwd,'server','scripts','header.r',sep='/'))

opts = commandArgs(trailingOnly = TRUE)
instrument = sub("(\\w{3})_?(\\w{3})", "\\1_\\2", ifelse((length(opts)>0 && !is.na(opts[1])), opts[1], "EURUSD"))
granularity = ifelse((length(opts)>0 && !is.na(opts[2])), opts[2], "H1")

args = paste('{"instrument":"',instrument,'","granularity":"',granularity,'"}',sep='')
qfxBreakout(args)