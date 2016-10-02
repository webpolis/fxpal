library(tm)
library(tm.plugin.webmining)
library(RCurl)
library(XML)

rss.fxstreet.content = xmlParse("http://xml.fxstreet.com/news/forex-news/index.xml",useInternalNodes=T)
rss.actionfx.content = xmlParse("http://feeds.actionforex.com/ActionInsightallReports",useInternalNodes=T)
rss.actionfx2.content = xmlParse("http://feeds.actionforex.com/CandlesticksIntradayTrades",useInternalNodes=T)
rss.mt5.content = xmlParse("http://news.mt5.com/news/rss",useInternalNodes=T)
#rss.dailyfx.content = xmlParse("http://www.dailyfx.com/feeds/forex_market_news",useInternalNodes=T)
rss.fxstreet.nodes = getNodeSet(rss.fxstreet.content,"//item")
rss.actionfx.nodes = getNodeSet(rss.actionfx.content,"//item")
rss.actionfx2.nodes = getNodeSet(rss.actionfx2.content,"//item")
rss.mt5.nodes = getNodeSet(rss.mt5.content,"//item")
#rss.dailyfx.nodes = getNodeSet(rss.dailyfx.content,"//item")
rss.fxstreet.list = lapply(rss.fxstreet.nodes,xmlToList)
rss.actionfx.list = lapply(rss.actionfx.nodes,xmlToList)
rss.actionfx2.list = lapply(rss.actionfx2.nodes,xmlToList)
rss.mt5.list = lapply(rss.mt5.nodes,xmlToList)
#rss.dailyfx.list = lapply(rss.dailyfx.nodes,xmlToList)

reDate = "[a-z]{1,3}\\,\\s*([0-9]{1,2})\\s*([a-z]{2,3})\\s*[0-9]{2}([0-9]{2})\\s*([0-9]{2}:[0-9]{2}:[0-9]{2}).*"

rss.fxstreet.df = data.frame(Reduce(rbind,rss.fxstreet.list))
rss.fxstreet.df$pubDate = sapply(rss.fxstreet.df$pubDate,function(l) {as.POSIXct(strptime(gsub(reDate,"\\1-\\2-\\3 \\4",l,ignore.case=T,perl=T),format="%d-%b-%y %T"))})
rss.actionfx.df = data.frame(Reduce(rbind,rss.actionfx.list))
rss.actionfx.df$pubDate = sapply(rss.actionfx.df$pubDate,function(l) {as.POSIXct(strptime(gsub(reDate,"\\1-\\2-\\3 \\4",l,ignore.case=T,perl=T),format="%d-%b-%y %T"))})
rss.actionfx2.df = data.frame(Reduce(rbind,rss.actionfx2.list))
rss.actionfx2.df$pubDate = sapply(rss.actionfx2.df$pubDate,function(l) {as.POSIXct(strptime(gsub(reDate,"\\1-\\2-\\3 \\4",l,ignore.case=T,perl=T),format="%d-%b-%y %T"))})
rss.mt5.df = data.frame(Reduce(rbind,rss.mt5.list))
rss.mt5.df$pubDate = sapply(rss.mt5.df$pubDate,function(l) {as.POSIXct(strptime(gsub(reDate,"\\1-\\2-\\3 \\4",l,ignore.case=T,perl=T),format="%d-%b-%y %T"))})
#rss.dailyfx.df = data.frame(Reduce(rbind,rss.dailyfx.list))
#rss.dailyfx.df$pubDate = sapply(rss.dailyfx.df$pubDate,function(l) {as.POSIXct(strptime(gsub(reDate,"\\1-\\2-\\3 \\4",l,ignore.case=T,perl=T),format="%d-%b-%y %T"))})

rss.df = data.frame()
if(length(grep("pubDate|description|title",names(rss.fxstreet.df)))==3){
	rss.df = rbind(rss.df, rss.fxstreet.df[,c("title","description","pubDate")])
}
if(length(grep("pubDate|description|title",names(rss.actionfx.df)))==3){
	rss.df = rbind(rss.df, rss.actionfx.df[,c("title","description","pubDate")])
}
if(length(grep("pubDate|description|title",names(rss.actionfx2.df)))==3){
	rss.df = rbind(rss.df, rss.actionfx2.df[,c("title","description","pubDate")])
}
if(length(grep("pubDate|description|title",names(rss.mt5.df)))==3){
	rss.df = rbind(rss.df, rss.mt5.df[,c("title","description","pubDate")])
}
if(length(grep("pubDate|description|title",names(rss.dailyfx.df)))==3){
	rss.df = rbind(rss.df, rss.dailyfx.df[,c("title","description","pubDate")])
}

rss.df$pubDate = as.POSIXlt(rss.df$pubDate,origin="1970-01-01")

startWeek = as.Date(format(Sys.Date(),format="%Y-%m-%d")) - as.difftime(2,units="weeks")
rss.df.filtered = rss.df[as.Date(rss.df$pubDate)>=startWeek,]
rss.df.filtered$description= sapply(rss.df.filtered$description,extractHTMLStrip)

corpus = Corpus(VectorSource(rss.df.filtered$description))

corpus = tm_map(corpus,content_transformer(tolower))
corpus = tm_map(corpus,content_transformer(removePunctuation))
corpus = tm_map(corpus,content_transformer(removeNumbers))
corpus = tm_map(corpus,removeWords,stopwords("english"))
#corpus = tm_map(corpus,stemDocument)

dtm = TermDocumentMatrix(corpus, control = list(minWordLength = 1))
dtmSparse = removeSparseTerms(dtm,0.9)
dfSparse = as.data.frame(inspect(dtmSparse))
scaleSparse = scale(dfSparse)
distSparse = dist(scaleSparse, method = "euclidean")
clustSparse = hclust(distSparse, method="ward")
