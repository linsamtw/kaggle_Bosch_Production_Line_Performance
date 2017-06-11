
# function

# find top n of var name
find.top.var.name.fun = function(res1.var.sd,n){
  data2.sd.sort = sort( res1.var.sd, decreasing = TRUE)
  #data2.sd.sort[1:5]
  feature1.name = names( data2.sd.sort[1:n] )
  return(feature1.name)
}

#*********************************************************
#*********************************************************
#*********************************************************
# work nrow and skip of fread, i = 0:11   
nrow.skip.fun=function(n=1183747,i=11){
  
  amount = 100000
  skip = 1+i*amount # i=0:11
  nrow = amount 
  #if(i==11) nrow = n-skip+1
  
  return(c(skip,nrow))
}

# separate operation, because data is too large
work.block.data.fun=
  function(i=1, var.class = c("L0","L1","L2","L3")){
    
    date.col.name = colnames(
      fread("train_date.csv",nrows=1,skip =0) 
    )
    temp = nrow.skip.fun(n=1183747,i=i)
    skip = temp[1]
    nrow = temp[2]
    train = fread("train_date.csv",nrows=nrow,skip =skip)
    colnames(train) = date.col.name
    
    temp = nrow.skip.fun(n=1183748,i=i)
    skip = temp[1]
    nrow = temp[2]
    test = fread("test_date.csv",nrows=nrow,skip =skip)
    colnames(test) = date.col.name
    data = rbind(train,test)
    
    # var.class = "L1"
    var.num = sapply(c(1:length(var.class)),function(x)
      grep(var.class[x],colnames(data))
    ) 
    if( is.integer(var.num)==0 ){
      var.num = do.call(c,var.num) %>% sort
    }
    var.num = c(1,var.num)
    
    data = data[,var.num,with=F]
    data[1:5,1:5,with=F]
    rm(train,test)
    gc()
    return(data)
  }

# work train_date feature by L0,L1,L2,L3,all
build.date.feature.fun=function(i=0, var.class = c("L0")){
  print(i)
  # i = 0 : 11
  data = work.block.data.fun(i,var.class)
  #nrow(data)
  #===================================
  # it is much important, data.table is slower than matrix
  data = as.matrix(data) # matrix is fast
  #===================================
  #data[1:5,1:5]
  temp = mclapply( c(1:nrow(data)),#i=10
                   function(i){
                     x     = data[i,2:ncol(data)] 
                     map = !is.na(x)
                     class.amount  = n_distinct(x[map])
                     na.amount     = sum(is.na(x))
                     first = ( x[map][1] )
                     if(class.amount != 0){
                       min   = min(x, na.rm=T)
                       max   = max(x, na.rm=T)
                       last  = x[map][length(x[map])]
                     }else{
                       min   = NA
                       max   = NA
                       last  = NA
                     }
                     result = c(data[i],first,min,last,max,class.amount,na.amount)
                     
                     resule.name = c("first","min","last","max","class.amount","na.amount")
                     var.class2 = var.class
                     if(length(var.class2)>1) var.class2 = "all"
                     resule.name = paste(var.class2,resule.name,sep="_")
                     names(result) = c("Id",resule.name)
                     return(result)
                   }
                   , mc.cores=8, mc.preschedule = T)
  #date.feature[9,]
  date.feature =  do.call(rbind,temp) %>% data.table %>%
    arrange(Id) %>% 
    data.table
  rm(temp)
  gc()
  return(list(date.feature))
}

# work train_date feature
main.work.date.feature.fun=function(var.class = "L0"){
  # i = 0 : 11
  temp = sapply(c(0:11),function(x)
    build.date.feature.fun(i=x,var.class )
  )
  
  date.feature = do.call(rbind,temp)
  nrow(date.feature)
  rm(temp)
  gc()
  
  return(date.feature)
}

#*********************************************************
# feature Engineering on date.csv
# build first, min, last, max, class, sum(na)
# for all date.csv & L0, L1, L2, L3
# data is too large, block operation
# nrow(train)	=  1183747
# nrow(test)	=  1183748	
#*********************************************************
work.feature1.fun=function(){
  
  L0.date.feature = main.work.date.feature.fun( var.class = "L0" )
  L1.date.feature = main.work.date.feature.fun( var.class = "L1" )
  L2.date.feature = main.work.date.feature.fun( var.class = "L2" )
  L3.date.feature = main.work.date.feature.fun( var.class = "L3" )
  all.date.feature = main.work.date.feature.fun( 
    var.class = c("L0","L1","L2","L3") )
  
  feature1 = Reduce(function(x,y) merge(x,y,all=T,by=c("Id")), 
                    list(	L0.date.feature,
                          L1.date.feature,
                          L2.date.feature,
                          L3.date.feature,
                          all.date.feature))
  rm(L0.date.feature,L1.date.feature,L2.date.feature,L3.date.feature,
     all.date.feature)
  gc()
  #return(final.date.feature)
  return(feature1)
}


work.model.fun=function(dtrain){
  
  xgb_params=list( 	
    objective="reg:linear",
    #objective = "binary:logistic",
    booster = "gbtree",
    eta= 0.1, 
    max_depth= 10, 
    colsample_bytree= 0.7,
    subsample = 0.7
    #,feval = MCC
  )
  set.seed(100)
  xgb_cv <- xgb.cv(data = dtrain,
                   params = xgb_params,
                   nrounds = 3000,
                   maximize = FALSE,
                   prediction = TRUE,
                   nfold = 3,
                   print_every_n = 10,
                   early_stopping_rounds = 10
                   ,nthread=8
                   #,eval_metric = MCC
                   ,eval_metric = "rmse"
  )
  best_nrounds = xgb_cv$best_iteration
  
  clf <- xgb.train(params=xgb_params,
                   data=dtrain, 
                   nrounds =best_nrounds,
                   watchlist = list(train = dtrain),
                   eval_metric='rmse'
                   #eval_metric = mcc.evaluation.fun,
                   #feval = mcc.evaluation.fun
  )
  
  return(clf)
}

# work xgb feature by xgb.importance, top n
work.feature.fun=function(train.var.name,model.xgb1,n){
  importance <- xgb.importance(
    feature_names = train.var.name , 
    model = model.xgb1 )
  
  feature = importance$Feature[1:n]
  return(feature)
}
# find station error per of response == 1 
find.rep1.per.fun = function(i,data){ # i=26
  temp = data[,c(i,ncol(data)),with=F]
  colnames(temp) = c("x","Response")
  temp = temp[!x==""]
  temp = temp[complete.cases(temp),]
  
  if(nrow(temp)==0)return(0)
  
  value = sum(temp$Response)/nrow(temp)
  return(value)
}

# use product line name vs reponse% to find feature
work.rep1.per.fun = function(data){
  temp = sapply(c(1:(ncol(data)-1)),#(ncol(train.numeric)-1)
                function(x)
                  find.rep1.per.fun(x,data) )
  train.numeric.na.per = data.table(temp)
  train.numeric.na.per$var.name = 
    colnames(data)[1:(ncol(data)-1)]
  
  #train.numericna.per = train.numeric.na.per %>% 
  #  arrange(.,desc(temp)) %>% 
  #  data.table
  
  return(train.numeric.na.per)
}

# because data is too large, work sub data, i = 0:11
work.subdata.fun = function(name = "numeric", i=0,n=1183747){
  temp = nrow.skip.fun(n,i=i)
  skip = temp[1]
  nrow = temp[2]
  data.name = paste("train_",name,".csv",sep="")
  data = fread(data.name,nrows=nrow,skip =skip)
  
  date.col.name = colnames(
    fread(data.name,nrows=1,skip =0) 
  )
  colnames(data) = date.col.name
  return(data)
}

# work train_xxx error per
work.data.rep1.per.fun = function(name = "categorical"){ # i=5
  
  data.name = paste("train_",name,".csv",sep="")
  temp = fread(data.name,nrows = 5 )
  
  n = length(temp)
  if( sum( colnames(temp)=="Response" ) )n=n-1
  var.num = c( seq(2,n,100),n+1 ) # i=1
  
  temp2 = mclapply( c(1:(length(var.num)-1)),# length(var.num)-1  i=1
                    function(i){
                      data =fread(data.name,nrows=1183747, 
                                  select = c( var.num[i] : (var.num[i+1]-1) )
                      )
                      data = cbind(data,Response)
                      temp = work.rep1.per.fun(data)
                      return(temp)
                    }
                    , mc.cores=8, mc.preschedule = T)  
  value = do.call(rbind,temp2)
  gc()
  return(value)
}

# find feature by error per on numeric, date, categorical
work.num.cate.feature.fun=function(amount=200){
  
  Response = fread("train_numeric.csv",
                   nrows=1183747,select=c(970))
  Response <<- Response$Response
  
  train.numericna.per   = work.data.rep1.per.fun(name = "numeric")
  train.date.per        = work.data.rep1.per.fun(name = "date")
  train.date.per = train.date.per[temp!=0]
  train.categorical.per = work.data.rep1.per.fun(name = "categorical")
  train.categorical.per = train.categorical.per[temp!=0]
  #-------------------------------------------------------
  train.numericna.per = train.numericna.per %>% 
    arrange(desc(temp)) %>%
    data.table
  train.date.per      = train.date.per %>% 
    arrange(desc(temp)) %>%
    data.table
  train.categorical.per = train.categorical.per %>% 
    arrange(desc(temp)) %>%
    data.table  
  
  n1 = nrow(train.numericna.per) 
  n3 = nrow(train.categorical.per) 
  numeric.feature = train.numericna.per$var.name[ 
    c(1:amount,(n1-amount):(n1)) ]
  categorical.feature = train.categorical.per$var.name[ 
    c(1:amount,(n3-amount):(n3)) ]                    
  return( list(numeric.feature,
               categorical.feature,
               train.numericna.per,
               train.categorical.per,
               train.date.per
  ) )
}
# 
my.cumsum = function(x){
  total <<- 0
  value = sapply(c(1:length(x)), # i=12
                 function(i){
                   total <<- total + x[i]
                   if(x[i] == 0) {total <<- 0}
                   return(total) 
                 }  )
  return(value)
}

group.fun = function(x){
  # x = temp$order.same.time[1:100]
  total <<- 0
  value = sapply(c(1:length(x)), # i=12
                 function(i){
                   if(x[i-2]==0 && x[i-1]==0 && x[i]!=0)
                     total <<- total+1
                   return(total) 
                 }  )
  return(value)
}

# next or prev is same or not, that means same Production Line 
# next1 : 下一個是否為  同時生產的產品  yes-1, no-0  
# prev1 : 上一個是否為  同時生產的產品  yes-1, no-0
# total : next1+prev1
# P1    : 是否為同一時間製造     total>0
# ord   : 在同時生產的產品中  該產品是第幾個  (cumsum(prev1)+1)*P1
# group : 第幾群同時生產的產品
# ******* tmpDT$fst[is.na(tmpDT$fst)] <- 0  否則會產生na
# group_len : table(group)
# time_Li   : 在該製程耗時 Li_max-Li_min     ex : time_L3 : L3_max-L3_min
# time_dtL3 : 與前一產品相比    耗時差距
#             time_L3 - c(NA, time_L3[2:nrow(DT)-1])
# time_idtL3: 與下一產品相比    耗時差距 
#             time_L3 - c(time_L3[2:nrow(DT)-0], NA)]
# NAs_dtL3  : 與前一產品相比    na數量
#             L3.NAs - c(NA, L3.NAs[2:nrow(DT)-1])]
# NAs_idtL3  : 與下一產品相比    na數量
#             L3.NAs - c(L3.NAs[2:nrow(DT)-0], NA)]
# Add prev&next target
# target_prev:= c(NA, target[1:(nrow(LK_DT)-1)])
# target_next:= c(target[2:(nrow(LK_DT))], NA)
work.feature2.fun=function(feature1){
  temp = feature1 %>% 
    subset(select = c(Id,all_first,all_max,all_min,all_na.amount) )
  res.train = fread("train_numeric.csv",select=c("Id","Response"))
  res.test  = fread("test_numeric.csv",select=c("Id"))
  res.test$Response = NA
  res = rbind(res.train,res.test)
  rm(res.train,res.test);gc()
  
  temp = merge(temp,res,by="Id")
  
  temp$all_first[is.na(temp$all_first)] = -temp$Id[is.na(temp$all_first)]
  
  temp$next.all = c(temp$all_first[2:nrow(temp)],0)
  temp$prev.all = c(0,temp$all_first[1:(nrow(temp)-1)])
  
  temp$all_next = as.numeric(temp$all_first == temp$next.all )
  temp$all_prev = as.numeric(temp$all_first == temp$prev.all )
  temp$next.all = NULL
  temp$prev.all = NULL
  
  temp$total = temp$all_next + temp$all_prev
  
  temp$same.time = as.numeric( temp$total>0 )
  
  temp$order.same.time = 
    Reduce(function(a,b){
      sum(a,b)*b
    },temp$all_prev,accumulate = T) +temp$same.time
  
  temp$group = group.fun(temp$order.same.time)*temp$same.time
  
  tem = table(temp$group)
  tem2 = data.table(group = as.numeric( names(tem) ),
                    group.amount = as.integer(tem)) 
  
  temp2 = merge(temp,tem2,all.x=T,by=c("group")) %>% arrange(Id) %>% data.table
  # rank = 31%
  #==========================================================================
  # feature 2-2
  temp2$cost.time = temp2$all_max-temp2$all_min
  temp2$prev.cost.time = 
    temp2$cost.time - 
    c(NA,temp2$cost.time[1:length(temp2$cost.time)-1])
  
  temp2$next.cost.time = 
    temp2$cost.time - 
    c(temp2$cost.time[2:length(temp2$cost.time)],NA)
  
  temp2$prev.na.amount = 
    temp2$all_na.amount - 
    c(NA,temp2$all_na.amount[1:(length(temp2$all_na.amount)-1)])
  
  temp2$next.na.amount = 
    temp2$all_na.amount - 
    c(temp2$all_na.amount[2:(length(temp2$all_na.amount))],NA)
  
  temp2$prev.traget = c(NA,
                        temp2$Response[1:(length(temp2$Response)-1)])
  
  temp2$next.traget = c(temp2$Response[2:(length(temp2$Response))],NA)
  
  #temp$group = NULL
  # all_first,all_max,all_min,all_na.amount
  temp2$all_first = NULL
  temp2$all_max = NULL
  temp2$all_min = NULL
  temp2$all_na.amount = NULL
  temp2$Response = NULL
  return(temp2) 
}

work.mode.xgb1.fun=
  function(numeric.feature,
           final.data.feature){
    train.numeric	=fread("train_numeric.csv",nrows=1183747,
                         select = c("Id",numeric.feature,"Response"))
    train.numeric = merge(train.numeric,final.data.feature,by=c("Id"))
    
    train.var.name = train.numeric %>% 
      subset(.,select = -c(Id,Response)) %>% colnames
    gc()
    
    dtrain <- xgb.DMatrix( data= as.matrix(
      subset(train.numeric,select=-c(Id,Response) )
    ) ,label=train.numeric$Response)
    gc()
    model.xgb1 = work.model.fun(dtrain)
    return(list(model.xgb1,dtrain,train.numeric,train.var.name))
  }

work.xgb.feature.fun = 
  function(train.var.name,
           model.xgb1,
           final.data.feature,
           feature.amount=50
  ){
    
    feature = work.feature.fun(train.var.name,model.xgb1,feature.amount)
    
    final.feature.name = 
      feature[feature %in% colnames(final.data.feature)]
    var.feature = feature[!feature %in% final.feature.name]
    
    final.data.feature2 = subset(final.data.feature,
                                 select = c("Id",final.feature.name))
    return(list(var.feature,final.data.feature2))
  }

work.model.xgb2.fun=
  function(var.feature,
           final.data.feature2
  ){    
    
    train.numeric	=fread("train_numeric.csv",nrows=1183747,
                         select = c("Id",var.feature,"Response"))
    train.numeric = merge(train.numeric,final.data.feature2,by=c("Id"))
    gc()
    dtrain <- xgb.DMatrix( data= as.matrix(
      subset(train.numeric,select=-c(Id,Response) )
    )  , 
    label=train.numeric$Response)
    gc()  
    
    model.xgb2 = work.model.fun(dtrain)
    return(list(model.xgb2,dtrain,train.numeric))
  }

work.final.pred.fun=
  function(var.feature,final.data.feature2,model.xgb2){
    
    test.numeric	=fread("test_numeric.csv",
                        select = c("Id",var.feature))    
    test.numeric = merge(test.numeric,final.data.feature2,by=c("Id"))
    gc()
    
    dtest<- xgb.DMatrix( data= as.matrix(
      subset(test.numeric,select=-c(Id) ) )  )
    gc()    
    test.pred<-predict(model.xgb2,dtest) # rate=0.2
    test.pred[test.pred>rate]=1
    test.pred[test.pred<rate]=0    
    
    final.pred = data.table(Id = as.integer(test.numeric$Id) , 
                            Response = as.integer(test.pred))
    print(table(final.pred$Response))
    
    rm(test.numeric)
    gc()
    return(final.pred)
  }


work.myparams.xgbmodel.fun=
  function(var.feature,
           final.data.feature2,nrounds=50
  ){    
    
    train.numeric	=fread("train_numeric.csv",nrows=1183747,
                         select = c("Id",var.feature,"Response"))
    train.numeric = merge(train.numeric,final.data.feature2,by=c("Id"))
    gc()
    dtrain <- xgb.DMatrix( data= as.matrix(
      subset(train.numeric,select=-c(Id,Response) )
    )  , 
    label=train.numeric$Response)
    gc()  
    
    xgb_params=list( 	
      objective="reg:linear",
      booster = "gbtree",
      eta= 0.1, 
      max_depth= 10, 
      colsample_bytree= 0.7,
      subsample = 0.7
    )
    
    set.seed(100)
    clf <- xgb.train(params=xgb_params,
                     data=dtrain, 
                     nrounds =nrounds,
                     watchlist = list(train = dtrain),
                     eval_metric='rmse'
    )
    return(list(clf,dtrain,train.numeric))
  }


pred.fun=function(main.test,model,rate){
  
  pred = predict(model,xgb.DMatrix(data.matrix(
    main.test[,c( 2: (ncol(main.test)) ),with=FALSE]),
    missing=NA))
  
  pred[pred>rate]=1
  pred[pred<rate]=0
  
  #Id	Response
  result = data.table(Id=main.test$Id,Response=pred)
  
  return(result)
}

#算得分
mcc.evaluation.fun=function(tem){
  #mcc.evaluation.fun=function(Response,pred){
  #tem = table(Response,pred)
  tp = tem[1,1]*0.01 #%>% as.integer64(.)
  fn = tem[1,2]*0.01 #%>% as.integer64(.)
  fp = tem[2,1]*0.01 #%>% as.integer64(.)
  tn = tem[2,2]*0.01 #%>% as.integer64(.)
  up = tp*tn-fp*fn
  down = sqrt( (tp+fp)*(tp+fn)*(tn+fp)*(tn+fn) )
  
  #return( list(metric = "MCC",value = up/down) )
  return(up/down)
}
MCC<- function(pred, dtrain) {
  
  Response<- getinfo(dtrain, "label")
  value = MCC2(Response,pred)
  
  
  return(list(metric = "MCC", value = value ))
}

MCC2=function(Response,pred){
  
  pred[pred>rate]=1
  pred[pred<rate]=0
  t1 = table(Response,pred)
  #print(t1)
  
  value = 0
  if( nrow(t1)==2 && ncol(t1)==2){
    
    tp = t1[1,1] %>% as.integer64(.)
    fn = t1[1,2] %>% as.integer64(.)
    fp = t1[2,1] %>% as.integer64(.)
    tn = t1[2,2] %>% as.integer64(.)
    up = tp*tn-fp*fn
    down = sqrt( (tp+fp)*(tp+fn)*(tn+fp)*(tn+fn) )
    
    value = down/up
  }
  return(value)
}








