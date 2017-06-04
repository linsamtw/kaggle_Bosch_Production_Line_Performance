
##### PARAMETERS & SETTINGS
settings <- list(path_raw_data = '../input/')
params <- list(cores=8)


##### FUNCTIONS
library(data.table)
library(xgboost)
library(parallel)

read_raw_data <- function(fileID, filterID=NULL, train=F, test=F, 
                          n_batch=1, n_chunks=1, select=NULL, 
                          t_function=NULL, params=NULL, delete.unziped=F) {
  # Libraries
  library(data.table)
  
  # Check parameters
  if (!fileID %in% c('numeric','date','categorical')) {
    cat("\nFileID ERROR")
    return()
  }
  if (!(train | test)) {
    cat("\nEmpty request")
    return()
  }
  
  # Unzip files
  train_filename <- paste0(settings$path_raw_data,"train_",fileID,".csv")
  test_filename <- paste0(settings$path_raw_data,"test_",fileID,".csv")
  if (train & !file.exists(train_filename)) unzip(paste0(train_filename,".zip"), exdir=settings$path_raw_data)
  if (test & !file.exists(test_filename)) unzip(paste0(test_filename,".zip"), exdir=settings$path_raw_data)
  
  # Read header and set columns to read
  if (train) {col_names <- fread(paste0(settings$path_raw_data,'train_',fileID,".csv"), nrows = 0L, skip = 0L)
  } else {col_names <- fread(paste0(settings$path_raw_data,'test_',fileID,".csv"), nrows = 0L, skip = 0L)}
  col_names <- colnames(col_names)
  col_table <- data.table(idx = 1:length(col_names), name = col_names,
                          do.call(rbind, sapply(col_names, function(x) strsplit(x,"_"))))
  col_idx <- c(2:nrow(col_table))
  if (!is.null(select)) {
    idx_selected <- c(col_table$idx[col_table$name %in% select],
                      col_table$idx[col_table$V1 %in% select],
                      col_table$idx[col_table$V2 %in% select],
                      col_table$idx[col_table$V3 %in% select])
    idx_selected <- unique(idx_selected)
    col_idx <- idx_selected[order(idx_selected)]
  } else {
    if (fileID == 'numeric' & train & test) {
      col_idx <- col_idx[1:(length(col_idx)-1)] # remove Response
    }
  }
  ifelse(n_batch>1, col_bat  <- cut(col_idx, n_batch, labels = c(1:n_batch)), col_bat  <- rep(1, length(col_idx)))
  
  # Set total rows
  n_train <- 1183747
  n_test <- 1183748
  train_chunk_size <- floor(n_train / n_chunks)
  test_chunk_size <- floor(n_test / n_chunks)
  
  # Set columns classes
  if (fileID == 'categorical') {
    colClasses <- c('numeric', rep('categorical', nrow(col_table)-1))
    na.strings <- ""
  } else {
    colClasses <- 'numeric'
    na.strings <- "NA"
  }
  
  for (chunk_number in 0:(n_chunks-1)) {
    train_skip <- train_chunk_size*chunk_number + 1
    test_skip <- test_chunk_size*chunk_number + 1
    if (chunk_number != (n_chunks-1)) {
      train_nrows <- train_chunk_size
      test_nrows <- test_chunk_size
    } else {
      train_nrows <- n_train - train_skip +1
      test_nrows <- n_test - test_skip +1
    }
    
    for(i in 1:n_batch) {
      if (train) DT_train <- fread(paste0(settings$path_raw_data,"train_",fileID,".csv"),
                                   showProgress = F, select = c(1, col_idx[col_bat == i]),
                                   skip = train_skip, nrows = train_nrows,
                                   colClasses = colClasses, na.strings = na.strings)
      if (test) DT_test <- fread(paste0(settings$path_raw_data,"test_",fileID,".csv"),
                                 showProgress = F, select = c(1, col_idx[col_bat == i]),
                                 skip = test_skip, nrows = test_nrows,
                                 colClasses = colClasses, na.strings = na.strings)
      if (train & test) {
        tmp_DT <- rbind(DT_train, DT_test)
      } else {
        ifelse(train, tmp_DT <- DT_train, tmp_DT <- DT_test)
      }
      
      setnames(tmp_DT, col_names[c(1, col_idx[col_bat == i])])
      setkey(tmp_DT, Id)
      
      if (!is.null(filterID)) {
        tmp_DT <- tmp_DT[Id %in% filterID]
      }
      
      if (!is.null(t_function)) {
        tmp_DT <- t_function(tmp_DT, params)
      }
      
      ifelse(i==1, DT <- tmp_DT, DT <- cbind(DT, tmp_DT[,2:ncol(tmp_DT), with=F]))
      
      # Clean memory
      rm(tmp_DT)
      if (train) rm(DT_train)
      if (test) rm(DT_test)
      gc()
    }
    
    ifelse(chunk_number==0, complete_DT <- DT, complete_DT <- rbind(complete_DT, DT))
    
    # Clean memory
    rm(DT); gc()
    
    
  }
  
  # Delete files
  if (train & delete.unziped) file.remove(paste0(settings$path_raw_data,"train_",fileID,".csv"))
  if (test & delete.unziped) file.remove(paste0(settings$path_raw_data,"test_",fileID,".csv"))
  
  setkey(complete_DT, Id)
  
  return(complete_DT)
}

tf_date_structure <- function(DT, params=list('cores'=1)) {
  
  # Libraries
  library(data.table)
  library(parallel)
  
  mDT <- as.matrix(DT)
  
  feats <- mclapply(1:nrow(DT), function (i) {
    
    result <- mDT[i, 1]
    result_names <- c('Id')
    
    fs <- 2:ncol(mDT)
    
    x <- mDT[i, fs]
    result <- c(result, 
                ifelse(all(is.na(x)), NA, x[!is.na(x)][1]),
                ifelse(all(is.na(x)), NA, min(x, na.rm=T)),
                ifelse(all(is.na(x)), NA, rev(x[!is.na(x)])[1]),
                ifelse(all(is.na(x)), NA, max(x, na.rm=T)),
                ifelse(any(is.na(x)), length(unique(x))-1, length(unique(x))),
                sum(is.na(x))
    )
    
    result_names <- c(result_names, 'fst', 'min', 'lst', 'max', 'unique', 'NAs')
    
    names(result) <- result_names
    
    return(result)
    
  }, mc.cores=params['cores'], mc.preschedule = T)
  feats <- do.call(rbind, feats)
  feats <- as.data.table(feats)
  setkey(feats, Id)
  
  return(feats)
}

tf_stations_mean <- function(DT, params=list('cores'=1)) {
  
  # Libraries
  library(data.table)
  library(parallel)
  
  c_names <- colnames(DT)
  col_table <- data.table(idx = 1:length(c_names), name = c_names,
                          do.call(rbind, sapply(c_names, function(x) strsplit(x,"_"))))
  stations <- unique(col_table$V2[2:nrow(col_table)])
  stat_list <- lapply(stations, function(x) col_table$idx[col_table$V2 == x])
  mDT <- as.matrix(DT)
  
  feats <- mclapply(1:nrow(DT), function (i) {
    
    result <- mDT[i, 1]
    result_names <- c('Id')
    
    for (s in 1:length(stat_list)) {
      x <- mDT[i, stat_list[[s]] ]
      result <- c(result,
                  mean(x, na.rm = T)
      )
      result_names <- c(result_names, paste0(stations[s], c('.mean')))
    }
    
    names(result) <- result_names
    
    return(result)
    
  }, mc.cores=params['cores'], mc.preschedule = T)
  feats <- do.call(rbind, feats)
  feats <- as.data.table(feats)
  setkey(feats, Id)
  
  return(feats)
}

eval_mcc <- function(y_true, y_prob, result='mcc') {
  DT <- data.table(y_true = y_true, y_prob = y_prob, key="y_prob")
  
  nump <- sum(y_true)
  numn <- length(y_true)- nump
  
  DT[, tn_v:= cumsum(y_true == 0)]
  DT[, fp_v:= cumsum(y_true == 1)]
  DT[, fn_v:= numn - tn_v]
  DT[, tp_v:= nump - fp_v]
  DT[, tp_v:= nump - fp_v]
  DT[, mcc_v:= (tp_v * tn_v - fp_v * fn_v) / sqrt((tp_v + fp_v) * (tp_v + fn_v) * (tn_v + fp_v) * (tn_v + fn_v))]
  DT[, mcc_v:= ifelse(!is.finite(mcc_v), 0, mcc_v)]
  
  ifelse(result=='mcc', return(max(DT[['mcc_v']])), return(DT[['y_prob']][which.max(DT[['mcc_v']])]))
}

find_prob <- function(y_prob, select) {
  rev(sort(y_prob))[select+1]
} 


##### MAIN

## Read data
print("Read data: DATE")
DTn <- read_raw_data(fileID="date", train=T, test=T, n_chunks=18, 
                     t_function=tf_date_structure, params=params)

print("Read data: DATE_L3")
DT3 <- read_raw_data(fileID="date", train=T, test=T, n_chunks=7, select="L3",
                     t_function=tf_date_structure, params=params)
setnames(DT3, c('Id', paste0('L3.',colnames(DT3)[2:ncol(DT3)])))

#print("Read data: DATE_L3_mean")
#DTs <- read_raw_data(fileID="date", train=T, test=T, n_chunks=3, select="L3",
#                     t_function=tf_stations_mean, params=params)
#setnames(DTs, c('Id', paste0('S.',colnames(DTs)[2:ncol(DTs)])))

print("Read data: TARGET")
target <- read_raw_data(fileID="numeric", train=T, select="Response")

print("Read data: NUMERIC")
select <- c('L1_S24_F1846', 'L3_S32_F3850','L1_S24_F1695', 'L1_S24_F1632','L3_S33_F3855', 'L1_S24_F1604',
            'L3_S29_F3407', 'L3_S33_F3865','L3_S38_F3952', 'L1_S24_F1723')
tmpDT0 <- read_raw_data(fileID="numeric", train=T, test=T, select=select)

print("Read data: CATEGORICAL")
tmpDT1 <- read_raw_data(fileID="categorical", train=T, test=T, select=c('S32'))

print("Merging Data")
DT <- cbind(DTn, DT3, tmpDT0, tmpDT1) #, DTs)
DT <- DT[, unique(colnames(DT)), with=F]
DT <- merge(DT, target, all.x=T, by='Id')
setcolorder(DT, c('Id', 'Response', setdiff(colnames(DT), c('Id', 'Response'))))
setnames(DT, c('Id', 'Response'), c('ID', 'target'))
setkey(DT, ID)

rm(DTn, DT3, tmpDT0, tmpDT1, target) #, DTs)
invisible(gc())


## Feature Engineering (1)
print("Generating Features")
tmpDT <- copy(DT[, c('ID', 'target','fst'), with=F])
setkey(tmpDT, ID)
tmpDT$fst[is.na(tmpDT$fst)] <- -tmpDT$ID[is.na(tmpDT$fst)] 
tmpDT[, next1:=as.numeric(fst == c(fst[2:nrow(DT)], 0))]
tmpDT[, prev1:=as.numeric(fst == c(0, fst[2:nrow(DT) - 1]))]
tmpDT[, nORp:=next1 + prev1]
tmpDT[, P1:=nORp > 0]
tmpDT[, ord:=Reduce(function(x,y){sum(c(x,y), na.rm=T)*y}, prev1, accumulate = T) + (nORp > 0)]
tmpDT[, group:=cumsum(ord==1) * as.numeric(ord>0)]
tmp <- tmpDT[, list(group_len=.N), by='group']
tmpDT <- merge(tmpDT, tmp, by='group', all.x=T, sort = F)
setkey(tmpDT, ID)


## Feature Engineering (2)
new_DT <- cbind(DT, tmpDT[,c('ord','P1','group_len','fst'),with=F])
setkeyv(new_DT, c('ID'))
new_DT[, time_L3:=L3.max-L3.min]
new_DT[, time_dtL3:= time_L3 - c(NA, time_L3[2:nrow(DT)-1])]
new_DT[, time_idtL3:= time_L3 - c(time_L3[2:nrow(DT)-0], NA)]
new_DT[, NAs_dtL3:= L3.NAs - c(NA, L3.NAs[2:nrow(DT)-1])]
new_DT[, NAs_idtL3:= L3.NAs - c(L3.NAs[2:nrow(DT)-0], NA)]


## Select features
LK_DT <- new_DT[,c('ID','target','P1', 'ord', 'group_len', 'fst',
                   #'S.S32.mean', 'S.S33.mean', 'S.S38.mean',
                   'L3.fst', 'L3.lst', 'time_dtL3', 'time_idtL3',
                   'NAs_dtL3', 'NAs_idtL3',
                   'L3_S32_F3851', 'L3_S32_F3853', 'L3_S32_F3854',
                   'L1_S24_F1846', 'L3_S32_F3850', 'L1_S24_F1695', 
                   'L1_S24_F1632', 'L3_S33_F3855', 'L1_S24_F1604',
                   'L3_S29_F3407', 'L3_S33_F3865', 'L3_S38_F3952', 
                   'L1_S24_F1723'),with=F]
setkey(LK_DT, ID)
## Categorical to nuemric
LK_DT[, L3_S32_F3851:= as.numeric(factor(L3_S32_F3851, ordered = T))]
LK_DT[, L3_S32_F3853:= as.numeric(factor(L3_S32_F3851, ordered = T))]
LK_DT[, L3_S32_F3854:= as.numeric(factor(L3_S32_F3851, ordered = T))]
## Add prev&next target
LK_DT[, target_prev:= c(NA, target[1:(nrow(LK_DT)-1)])]
LK_DT$target_prev[LK_DT$ord <= 1] <- NA
LK_DT[, target_next:= c(target[2:(nrow(LK_DT))], NA)]
LK_DT$target_next[c(LK_DT$ord[2:nrow(LK_DT)] < LK_DT$ord[1:(nrow(LK_DT)-1)], TRUE)] <- NA
LK_DT$target_next[LK_DT$ord == 0] <- NA

rm(DT, new_DT, tmp); invisible(gc())


## Train & Predict
print("Train & Predict")
dtrain <- xgb.DMatrix(data = as.matrix(LK_DT[!is.na(LK_DT$target), 3:ncol(LK_DT), with=F]), 
                      label = LK_DT$target[!is.na(LK_DT$target)], missing = NA)
dtest  <- xgb.DMatrix(data = as.matrix(LK_DT[is.na(LK_DT$target), 3:ncol(LK_DT), with=F]), 
                      missing = NA)

XGBparams <- list(nthread = 16, max_depth = 10, 
                  subsample = 0.9, colsample_bytree = 0.5, eta=0.1,
                  objective   = "reg:linear", booster="gbtree")
set.seed(999)
modelXGB <- xgb.train(data = dtrain, XGBparams, nrounds = 65, watchlist = list(train=dtrain))
pred <- predict(modelXGB, dtest)
prob <- find_prob(pred, 2700)


## Submission
submission <- read.csv(paste0(settings$path_raw_data, 'sample_submission.csv'))
submission$Response <- as.numeric(pred > prob)
write.csv(submission, "submission.csv", row.names = F)
