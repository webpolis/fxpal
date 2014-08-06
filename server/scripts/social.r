setwd("app/data/")

Sys.setenv(TZ="UTC")

library("tm")
library("twitteR")

twitCred = load("twitterCredentials.RData")
registerTwitterOAuth(twitCred)

twits = searchTwitter("GBPUSD",n=500,lang="en")
df = do.call("rbind", lapply(twits, as.data.frame))
corpus = Corpus(VectorSource(df$text))

corpus = tm_map(corpus,content_transformer(tolower))
corpus = tm_map(corpus,content_transformer(removePunctuation))
corpus = tm_map(corpus,content_transformer(removeNumbers))
corpus = tm_map(corpus,removeWords,stopwords("english"))
corpus = tm_map(corpus,stemDocument)

dtm = TermDocumentMatrix(corpus, control = list(minWordLength = 1))
