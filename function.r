

#function
# i = 0:11
nrow.skip.fun=function(n=1183747,i=11){
  
  amount = 100000
  skip = 1+i*amount # i=0:11
  nrow = amount 
  #if(i==11) nrow = n-skip+1
  
  return(c(skip,nrow))
}


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


build.date.feature.fun=function(i=0, var.class = c("L0","L1","L2","L3")){
  print(i)
  # i = 0 : 11
  data = work.block.data.fun(i,var.class)
  #nrow(data)
  #===================================
  # it is much important, data.table is slower than matrix
  data = as.matrix(data) # matrix is fast
  #===================================
  data[1:5,1:5]
  
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
  
  date.feature =  do.call(rbind,temp) %>% data.table %>%
    arrange(Id) %>% 
    data.table
  rm(temp)
  gc()
  return(list(date.feature))
}

main.work.date.feature.fun=function(var.class = "L0"){
  # i = 0 : 11
  temp = sapply(c(0:11),function(x)
    build.date.feature.fun(i=x,var.class )
  )
  
  date.feature = do.call(rbind,temp)
  
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
work.final.data.feature.fun=function(){
  
  L0.date.feature = main.work.date.feature.fun( var.class = "L0" )
  L1.date.feature = main.work.date.feature.fun( var.class = "L1" )
  L2.date.feature = main.work.date.feature.fun( var.class = "L2" )
  L3.date.feature = main.work.date.feature.fun( var.class = "L3" )
  all.date.feature = main.work.date.feature.fun( 
    var.class = c("L1","L2","L3","L4") )
  
  final.date.feature = Reduce(function(x,y) merge(x,y,all=T,by=c("Id")), 
                              list(	L0.date.feature,
                                    L1.date.feature,
                                    L2.date.feature,
                                    L3.date.feature,
                                    all.date.feature))
  rm(L0.date.feature,L1.date.feature,L2.date.feature,L3.date.feature,
     all.date.feature)
  gc()
  return(final.date.feature)
}













