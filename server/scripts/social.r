library(tm)
library(twitteR)

load("twitterCredentials.RData")
registerTwitterOAuth(twitCred)

twits = searchTwitter("GBPUSD",n=500,lang="en")
df = do.call("rbind", lapply(twits, as.data.frame))
corpus = Corpus(VectorSource(df$text))

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

