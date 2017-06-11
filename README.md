# Bosch Production Line Performance, NO.74/top 6%
 kaggle_Production_Line
 website : 
 https://www.kaggle.com/c/bosch-production-line-performance
 # 緒論
 在現今的產業上，對於產品製造，大多都傾向自動化，因此我選擇該問題進行製程分析。 
 製程分析與我過去處理過的資料---銷售/庫存預測非常不同，90%以上都是NA，
 而在生產線上，這是合理的，我們必須找出哪個製程出錯，即重要變數。
 問題是，NA過多，一般統計方法 AIC/BIC/lasso 無法處理missing value，
 因此轉往使用 XGB 內建的 importance 找出重要變數。
 並參考kernel中[Daniel FG](https://www.kaggle.com/danielfg/xgboost-reg-linear-lb-0-485)的作法，
 進行 Feature Engineering 。
 
 # 資料介紹
 Bosch Production Line Performance 是關於生產線( 製程 )的分析，
 在自動化製造產品的過程中，可能由於設備老舊或人為疏失，導致不良品的產生，
 但是我們不可能單純利用人工檢驗哪個環節出錯，因為整個製程中超過 3000 道程序。
 因此，我們希望藉由製程分析，找出導致不良品產生的因素。
 
 由於我沒有相關製程經驗，也無實際接觸生產線，所以參考kernel中
 [Daniel FG](https://www.kaggle.com/danielfg/xgboost-reg-linear-lb-0-485)
 的 code ，並加入我的想法，主要重點在於 --- Feature Engineering 。

 # 資料準備 
 Kaggle 所提供的資料，可以分為以下三種 :
 
|data|size|n (資料筆數)|p (變數數量)|
|----|----|-----------|-----------|
|train_numeric|2.1GB|100萬筆|970個|
|train_date|2.9GB|100萬筆|970個|
|train_categorical|2.7GB|100萬筆|970個|
|test_numeric|2.7GB|100萬筆|970個|
|test_date|2.7GB|100萬筆|970個|
|test_categorical|2.7GB|100萬筆|970個|

主要變數如下 :
|變數名稱|意義|
|-------|----|
|Response|目標值, 0 : 良品, 1 : 不良品|
|Id|產品代號|
|Lx_Sx_Fx|L : line，S : station，F : feature number|

舉例來說，L3_S36_F3939，代表第 3 條生產線上，第 36 個設備中的第 3939 個特徵值，
而 numeric 中代表的是，產品在該設備中收集到的值， date 代表產品經過該設備的時間點 ，
我們並沒有使用 categorical，因此並不清楚該變數意義。


# 特徵工程

在生產線上，可能在某一時段機器故障，導致產品出現問題，所以對 date data 進行特徵工程。
 
|feature|解釋|
|-------|---|
|first|進入該製成時間點|
|min|製成時間點最小值|
|last|離開該製成時間點|
|max|製成時間點最大值|
|class.amount|該製成時間點種類數量|
|na.amount|na數量，如果時間點完全記錄，那該變數代表未經過製程的數量|

以上分別對 所有生產線、L0、L1、L2、L3 進行特徵工程。
由於 data 過大，分段製造 feature ，並在 linux 環境下使用 mclapply 平行運算加速，<br>
以上仍無法提高預測準確率，因此進行 特徵工程-2

# 特徵工程2

在生產線上，同一時間製造多個產品，它們的表現可能有高度相關，因此進行以下特徵工程。<br>
注意：first[is.na(first)]=0，否則對其他feature製造會產生na

|feature|解釋|code|
|-------|----|----|
|next|下一個產品是否為同時製造的產品||
|prev|上一個產品是否為同時製造的產品||
|total|total|next+prev|
|same.time|是否同時製造|total>0|
|order.same.time|在同時製造的產品中，該產品是第幾個|(cumsum(prev)+1) * same.time|
|group|第幾群同時製造的產品，同時製造代表可能有相同表現||
|group.length|該群數量|table(group)|
|cost.time|該製程耗時，耗時過長或過短，可能是因為產品出問題|max-min|
|pcost.time|與上一個產品相比，製程耗時差距，差距過大，可能是因為產品出問題|cost.time-c(NA,cost.time[1:length(cost.time)-1])|
|ncost.time|與下一個產品相比，製程耗時差距，差距過大，可能是因為產品出問題|cost.time-c(cost.time[2:length(cost.time)],NA)|
|pna.amount|與上一個產品相比，na數量，差距過大，可能是因為產品出問題|na.amount--c(NA,na.amount[1:length(na.amount)-1])|
|nna.amount|與下一個產品相比，na數量，差距過大，可能是因為產品出問題|na.amount--c(na.amount[2:length(na.amount)],NA)|
|prev.target|上一個產品表現，彼此間可能相關|c(NA,target[1:(nrow(target)-1)])|
|next.target|下一個產品表現，彼此間可能相關|c(target[2:nrow(target)],NA)|











