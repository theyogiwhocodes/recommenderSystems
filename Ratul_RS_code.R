install.packages("arules")
install.packages("proxy")
install.packages("registry")
install.packages("irlba")
install.packages("recommenderlab")
install.packages("reshape2")
install.packages("plyr")
install.packages("stringr")
install.packages("stringi")
install.packages("ggplot2")
install.packages("splitstackshape")
install.packages("data.table")
install.packages("gsubfn")
install.packages("sqldf")
install.packages("proto")
install.packages("RSQLite")

# Loading the libraries.
library(arules)
library(proxy)
library(registry)
library(irlba)
library(recommenderlab)
library(reshape2)
library(plyr)
library(stringr)
library(stringi)
library(ggplot2)
library(splitstackshape)
library(data.table)
library(proto)
library(RSQLite)
library(gsubfn)
library(sqldf)


# Data directory path for the file.
setwd ("/home/ratulr/Documents/data_mining/DataMining_Recommender_Mehregan/recommender-master")


# Read training file along with header
inputdata<-read.csv("ratings.csv",header=TRUE)

# Just look at first few lines of this file
head(inputdata)


# Remove 'timestamp' column. We do not need it
inputdata<-inputdata[,-c(4)]
head(inputdata)

# Setting the seed for the sampling.
set.seed(12)

#Taking stratified sampling from the data set based on user id . Taking 80% data to train the model.
train_data = stratified(inputdata, "userId", .8)
# test_data is the testing data set . Taking the remaining 20% of the data to test the model output.
test_data = sqldf("select * from inputdata except select * from train_data")
head(train_data)

# Using acast to convert above data as follows:
#       m1  m2   m3   m4
# u1    3   4    2    5
# u2    1   6    5
# u3    4   4    2    5
acast_data <- acast(train_data, userId ~ movieId)
# Check the class of acast_data
class(acast_data)

# Convert it as a matrix
R <- as.matrix(acast_data)
# Convert R into realRatingMatrix data structure
# realRatingMatrix is a recommenderlab sparse-matrix like data-structure
r <- as(R, "realRatingMatrix")
r



# Create a recommender object (model)
#   Run anyone of the following three code lines.
#     Do not run all three
#       They pertain to three different algorithms.
#        UBCF: User-based collaborative filtering
#        IBCF: Item-based collaborative filtering
#      Parameter 'method' decides similarity measure
#        Cosine or Jaccard or Pearson
# Train is using the training set.
# Cosine Method
#train_rec_ubcf <- Recommender(r[1:nrow(r)],method="UBCF", param=list(normalize = "Z-score",nn = 5,method="Cosine", minRating = 1))
# Jaccard Method
#train_rec_ubcf <- Recommender(r[1:nrow(r)],method="UBCF", param=list(normalize = "Z-score",method="Jaccard",nn=5, minRating=1))
# Pearson Method
train_rec_ubcf <- Recommender(r[1:nrow(r)],method="UBCF", param=list(normalize = "Z-score",method="Pearson",nn=5,minRating=1))



############Create predictions#############################
# This prediction does not predict movie ratings for test.
#   But it fills up the user 'X' item matrix so that
#    for any userid and movieid, I can find predicted rating
#      'type' parameter decides whether you want ratings or top-n items
#         we will go for ratings
recom <- predict(train_rec_ubcf, r[1:nrow(r)], type="ratings")
recom


########## Create prediction file from model #######################
# We will create 3 files by running the model 3 times using 3 different similarity Jaccard,Cosine, Pearson
# Convert all your recommendations to list structure
rec_list<-as(recom,"list")
head(summary(rec_list))

ratings <- NULL

# For all lines in test file, one by one
for ( u in 1:length(test_data[,1]))
{
  # Read userid and movieid from columns 2 and 3 of test data
  userid  <- test_data[u,1]
  movieid <- test_data[u,2]
  
  # Get as list & then convert to data frame all recommendations for user: userid
  u1 <- as.data.frame(rec_list[[userid]])
  # Create a (second column) column-id in the data-frame u1 and populate it with row-names
  # Remember (or check) that rownames of u1 contain are by movie-ids
  # We use row.names() function
  u1$id <- row.names(u1)
  # Now access movie ratings in column 1 of u1
  x <- u1[u1$id==movieid,1]

  # If no ratings were found, assign 0. 
  if (length(x)==0)
  {
    ratings[u] <- 0
  }
  else
  {
    ratings[u] <-x
  }
  
}
length(ratings)
tx<-cbind(test_data[,1:3],round(ratings))
# Write to a csv file: output_<method>.csv in your folder
write.table(tx,file="output_pearson.csv",row.names=FALSE,col.names=FALSE,sep=',')
# Submit now this csv file to kaggle

######################################################################
#### To check the performance of the 3 models we will calculate NMAE:
######################################################################
#define a MAE function : 
mae <- function(error)
{
  mean(abs(error))
}

#For cosine
cosinedata <- read.csv("output_cosine.csv", header = FALSE)
cosine_actual <- cosinedata[,3]
cosine_predicted <- cosinedata[,4]
error_cosine <-  cosine_predicted - cosine_actual 
# MAE = Sum(|predicted - real |)/ n
mae_cosine <- mae(error_cosine)
# The Min and Max ratings are common for all three models as the testing set is same across all 3 models
max_rating = max(cosine_actual)
min_rating = min(cosine_actual)
#NMAE = MAE/ (max rating - min rating)
NMAE_cosine <- mae_cosine / (max_rating - min_rating )
NMAE_cosine
#NMAE_cosine = 0.1850611



#For jaccard
jaccarddata <- read.csv("output_jaccard.csv", header = FALSE)
jaccard_actual <- jaccarddata[,3]
jaccard_predicted <- jaccarddata[,4]
error_jaccard <-  jaccard_predicted - jaccard_actual 
# MAE = Sum(|predicted - real |)/ n
mae_jaccard <- mae(error_jaccard)
# The Min and Max ratings are common for all three models as the testing set is same across all 3 models
max_rating = max(jaccard_actual)
min_rating = min(jaccard_actual)
#NMAE = MAE/ (max rating - min rating)
NMAE_jaccard <- mae_jaccard / (max_rating - min_rating )
NMAE_jaccard
#NMAE_jaccard 0.1846834



#For pearson
pearsondata <- read.csv("output_pearson.csv", header = FALSE)
pearson_actual <- pearsondata[,3]
pearson_predicted <- pearsondata[,4]
error_pearson <-    pearson_predicted - pearson_actual 
# MAE = Sum(|predicted - real |)/ n
mae_pearson <- mae(error_pearson )
# The Min and Max ratings are common for all three models as the testing set is same across all 3 models
max_rating = max(pearson_actual)
min_rating = min(pearson_actual)
#NMAE = MAE/ (max rating - min rating)
NMAE_pearson <- mae_pearson / (max_rating - min_rating )
NMAE_pearson
#NMAE_pearson 0.1852389

