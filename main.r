

#main

library(data.table)
library(xgboost)
library(glmnet)
library(dplyr)
library(moments)
library(bit64)
library(parallel)

rate=0.25
mc.cores=8

#setwd('D:\\kaggle_Production_Line')
setwd('/media/linsam/10FE4529FE450884/kaggle_Production_Line')

#----------------------------------------------
# work feature1 and feature2
#20min
# find 100 top.res1.per and 100 last.res1.per in train_numeric
temp = work.num.cate.feature.fun(amount=200)
numeric.feature         =temp[[1]]
categorical.feature     =temp[[2]]
train.numericna.per     =temp[[3]]
train.categorical.per   =temp[[4]]
train.date.per          =temp[[5]] 
# use train.date L3-res==1 : 0.045, total-res==1 : 0.0058

feature1 = work.feature1.fun()
feature2 = work.feature2.fun(feature1)
final.data.feature = merge(feature1,feature2,all=T,by=c("Id") )

#----------------------------------------------
# find xgb.important
temp = work.mode.xgb1.fun(numeric.feature,final.data.feature)
model.xgb1    = temp[[1]]
dtrain        = temp[[2]]
train.numeric = temp[[3]]
train.var.name= temp[[4]]
#----------------------------------------------------------
# compare mcc score
pred1<-predict(model.xgb1,dtrain)
pred1[pred1>rate]=1
pred1[pred1<rate]=0
#table(pred1)
t1 = table(train.numeric$Response,pred1)
#t1
mcc.evaluation.fun(t1)	
rm(train.numeric,dtrain)
gc()
#----------------------------------------------------------
# find feature by xgb.important
temp = work.xgb.feature.fun(train.var.name,
                            model.xgb1,
                            final.data.feature,
                            feature.amount=200
)
# feature var
var.feature = temp[[1]]
final.data.feature2 = temp[[2]]
#-----------------------------------------------------------------
# work fitted model, nrounds by model.xgb1
temp = work.myparams.xgbmodel.fun(var.feature,
                                  final.data.feature2,
                                  nrounds=50
)
my.xgb.model  = temp[[1]]
dtrain        = temp[[2]]
train.numeric = temp[[3]]
#-----------------------------------------------------------------
# compare mcc score
pred1<-predict(my.xgb.model,dtrain)
pred1[pred1>rate]=1
pred1[pred1<rate]=0
t1 = table(train.numeric$Response,pred1)
mcc.evaluation.fun(t1)	

#-----------------------------------------------------------------
rm(train.numeric)
gc()
#----------------------------------------------------------
final.pred = work.final.pred.fun(var.feature,final.data.feature2,my.xgb.model)
fwrite(final.pred,"value.csv")



