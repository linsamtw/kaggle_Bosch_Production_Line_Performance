
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
# work feature
#20min
temp = work.num.cate.feature.fun(amount=200)
numeric.feature     =temp[[1]]
categorical.feature =temp[[2]]
train.numericna.per =temp[[3]]
train.categorical.per = temp[[4]]
train.date.per      =temp[[5]] 
# use train.date L3-res==1 : 0.045, total-res==1 : 0.0058

feature1 = work.feature1.fun()
feature2 = work.feature2.fun(feature1)
final.data.feature = merge(feature1,feature2,all=T,by=c("Id") )

#----------------------------------------------
# find xgb.importance
temp = work.mode.xgb1.fun(numeric.feature,final.data.feature)
model.xgb1    = temp[[1]]
dtrain        = temp[[2]]
train.numeric = temp[[3]]
train.var.name= temp[[4]]
# 1000000
# train-rmse:0.069863+0.000558	test-rmse:0.073493+0.000919
# 66 train-rmse:0.070151
# ---------work.res1.feature
# 1183747
#	train-rmse:0.069921+0.000433	test-rmse:0.073180+0.000364
# 86	train-rmse:0.070221 
# L3
# train-rmse:0.070588+0.000314	test-rmse:0.073311+0.000349
# 62	train-rmse:0.070975 
# L3+all
# train-rmse:0.070603+0.000342	test-rmse:0.073293+0.000351
# 66  train-rmse:0.070850
# L0~all
# 70 train-rmse:0.070324+0.000381	test-rmse:0.073180+0.000365
# 70 train-rmse:0.070500
# add feature2
# 79	train-rmse:0.062796+0.000512	test-rmse:0.067555+0.000481
# 79  train-rmse:0.063726
# fix work.feature code
# [129]	train-rmse:0.061196+0.000326	test-rmse:0.067605+0.000484
# [129]	train-rmse:0.062397
#----------------------------------------------------------
# compare mcc score, because eval of xgb.model is rmse
pred1<-predict(model.xgb1,dtrain)
pred1[pred1>rate]=1
pred1[pred1<rate]=0
#table(pred1)
t1 = table(train.numeric$Response,pred1)
#t1
mcc.evaluation.fun(t1)	
# 0.422839
# 1000000 0.37969
# ---------work.res1.feature
# 1183747 0.3466546
# L3 0.3098475
# L3+all 0.3263655
# L0~all 0.3378502 rate = 0.25:0.3516619, rate = 0.3:0.3520926, rate = 0.2:0.3378502
# add feature2 0.5339928
# fix work.feature code 0.5653452
# feature2-2 0.5574488
#----------------------------------------------------------  
rm(train.numeric,dtrain)
gc()
#----------------------------------------------------------
# work xgb.importance feature
temp = work.xgb.feature.fun(train.var.name,
                            model.xgb1,
                            final.data.feature,
                            feature.amount=100
)
var.feature = temp[[1]]
final.data.feature2 = temp[[2]]

#colnames(train.numeric)
#temp = work.model.xgb2.fun(var.feature,
#                           final.data.feature2
#                           )
#model.xgb2    = temp[[1]]
#dtrain        = temp[[2]]
#train.numeric = temp[[3]]
# 100
# train-rmse:0.069305+0.000294	test-rmse:0.073031+0.000428
# [66]	train-rmse:0.069803 
# 200
#	train-rmse:0.068604+0.000363	test-rmse:0.073556+0.000411
# [83]	train-rmse:0.069511
# ---------work.res1.feature
# 200
#	[66]	train-rmse:0.070291+0.000359	test-rmse:0.073167+0.000339
# [66]	train-rmse:0.070590 
# 100
# [76]	train-rmse:0.069853+0.000263	test-rmse:0.073115+0.000398
# [76]	train-rmse:0.070396
# L3
# [76]	train-rmse:0.070040+0.000378	test-rmse:0.073264+0.000382
# [76]	train-rmse:0.070533
# L3+all
# [69]	train-rmse:0.070081+0.000369	test-rmse:0.073216+0.000286
# [69]	train-rmse:0.070571 
# L0~all,feature = 200
# [78]	train-rmse:0.069903+0.000332	test-rmse:0.073198+0.000361
# [78]	train-rmse:0.070398 
# feature = 50
# [60]  train-rmse:0.070003+0.000279	test-rmse:0.073118+0.000441
# [60]	train-rmse:0.070523 
# feature2, fix work.feature2
# [129]	train-rmse:0.060842+0.000437	test-rmse:0.067541+0.000520
# [129]	train-rmse:0.062118
#pred1<-predict(model.xgb2,dtrain)
#pred1[pred1>rate]=1
#pred1[pred1<rate]=0
#t1 = table(train.numeric$Response,pred1)
#mcc.evaluation.fun(t1)	
# 100 0.3717358
# 200 0.3913898
# ---------work.res1.feature
# 200 0.335463
# 100 0.3356458
# L3  0.3324643
# L3+all 0.3317864
# L0~all,feature=200,rate = 0.25:0.3429469,  rate = 0.2:0.3376435
# feature = 50, 0.33085
# feature2, fix work.feature: 0.5733722
#-----------------------------------------------------------------
# work fitted model
temp = work.myparams.xgbmodel.fun(var.feature,
                                  final.data.feature2,
                                  nrounds=50
)
my.xgb.model  = temp[[1]]
dtrain        = temp[[2]]
train.numeric = temp[[3]]
# nrounds=50 : train-rmse:0.064347
# feature 100: train-rmse:0.061552
#-----------------------------------------------------------------
# compare train mcc score
pred1<-predict(my.xgb.model,dtrain)
pred1[pred1>rate]=1
pred1[pred1<rate]=0
t1 = table(train.numeric$Response,pred1)
mcc.evaluation.fun(t1)	
# nrounds=50 : 0.5164973
# feature2-2 : 0.5374545
# rate = 0.25: 0.5437629
# feature 100: 0.5482553
#-----------------------------------------------------------------
rm(train.numeric)
gc()
#----------------------------------------------------------
# final pred
final.pred = work.final.pred.fun(var.feature,final.data.feature2,my.xgb.model)
fwrite(final.pred,"value.csv")

#             private public 1373
# feature 100 0.23609 0.21804 50%
# feature 200 0.21775 0.21528
# ---------work.res1.feature
# feature 200 0.23430 0.22927
# feature 100 0.23367 0.22418
# l3          0.22378 0.22663
# l3+all      0.23127 0.22520
# l0~all,feature=200,rate=0.25: 0.22610 0.21285 , 
#                    rate=0.2 : 0.23318 0.21287
# feature 50  0.23021 0.22811
# feature2, fix work.feature 0.39455 0.37960, rank: 446 478, 32.4%/34.8%
# nrounds = 50. 0.39905 0.39144, rank: 434, 429, 31.6%/31.2%
# feature2-2,   0.45015 0.45188, rank: 126, 108, 9.2%/7.9%
# rate = 0.25   0.46471 0.47034, rank: 82, 74, 6.0%/5.4%
# feature 100   0.46673 0.47352, rank: 78, 66, 5.7%/4.8%











