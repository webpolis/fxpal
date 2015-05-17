library(tm)
library(twitteR)
library(SnowballC)

Sys.setlocale("LC_CTYPE","en_US.UTF-8")
Sys.setenv(TZ='UTC')

pwd = getwd()
dataPath = paste(pwd,'/app/data/',sep='')

#load(paste(dataPath,'twitterCredentials.RData',sep='/'))
setup_twitter_oauth("yzriG1M9DRkut9SaCnoPIsCi7","5Exi0mVLHAhvXnvFAkniIgKlHbu4WJNGHIZhh4tjH0dMMEMy51","2192463607-zdC0xIgitnR6m8JISftPBUcUSOIU3eYOwsxzNvd","ibkvQXMmlSwtz0qxbc6LwaeNZT2I2sOmTrXNTFVBjla28")

getCluster <- function(cross=NA,source="twitter",lang="en",geocode=NULL,resultType="mixed"){
  if(lang == "es"){
    Sys.setlocale("LC_CTYPE","es_ES.UTF-8")
  }else{
    Sys.setlocale("LC_CTYPE","en_US.UTF-8")
  }
  
  sparse=0.95
  
  if(source=="twitter"){
    twits = searchTwitter(cross,n=1500,lang=lang,geocode=geocode,resultType=resultType)
    df = do.call('rbind', lapply(twits, as.data.frame))
    df[,1] = iconv(df[,1],to="utf-8-mac")
    df[,1] = gsub("http:[^\\s]+","",df[,1])
    corpus = Corpus(VectorSource(df$text))
  }else if(source=="google"){
    wc=params = list(hl = lang, q = cross, ie = "utf-8", num
                     = 1500, output = "rss")
    corpus=WebCorpus(GoogleNewsSource(cross,params=wc))
    sparse=0.75
  }
  
  corpus = tm_map(corpus,content_transformer(tolower))
  #corpus = tm_map(corpus, PlainTextDocument)
  corpus = tm_map(corpus,content_transformer(removePunctuation))
  corpus = tm_map(corpus,content_transformer(removeNumbers))
  
  if(lang=="en"){
    corpus = tm_map(corpus,removeWords,stopwords('english'))
  }else if(lang=="es"){
    corpus = tm_map(corpus,removeWords,stopwords('spanish'))
  }
  #corpus = tm_map(corpus,stemDocument)
  
  dtm = TermDocumentMatrix(corpus, control = list(minWordLength = 1, weighting =
                                                    function(x)
                                                      weightTfIdf(x, normalize =
                                                                    FALSE)))
  dtmSparse = removeSparseTerms(dtm,sparse)
  dfSparse = as.data.frame(inspect(dtmSparse))
  scaleSparse = scale(dfSparse)
  distSparse = dist(scaleSparse, method = 'euclidean')
  clustSparse = hclust(distSparse, method='ward')
  
  return(clustSparse)
}