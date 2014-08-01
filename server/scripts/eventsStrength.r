setwd("app/data/")

Sys.setenv(TZ="UTC")

opts = commandArgs(trailingOnly = TRUE)
cross1 = ifelse((exists("opts") && !is.na(opts[1])), opts[1], NA)
cross2 = ifelse((exists("opts") && !is.na(opts[1])), opts[1], NA)

data = read.csv("calendar.csv", sep = ",", dec = ".", strip.white = TRUE, header=TRUE, encoding = "UTF-8")
data = na.omit(data)

if(!is.na(cross1) && !is.na(cross2)){
	data = data[grep(paste(cross1,'|',cross2, sep = ''),data$currency,ignore.case=TRUE),]
}

allValues = grep('actual|forecast|previous',names(data))
actualValues = grep('actual',names(data))

# invert value for unemployment
data[grep('unempl',data$event, ignore.case=TRUE),allValues] <- -(data[grep('unempl',data$event, ignore.case=TRUE),allValues])

data[,actualValues] <- round(scale(data[,actualValues], scale = TRUE, center = FALSE), 6)
scaled = aggregate(data$actual, by=list(currency=data$currency),FUN=sum)
scaled = scaled[order(-scaled[,2]),]
names(scaled) <- c("currency","strength")
