# 製程分析
 kaggle_Production_Line
 website : 
 https://www.kaggle.com/c/bosch-production-line-performance

該問題提供以下data 

|data|size|
|----|----|
|numeric|2.1GB|
|date|2.9GB|
|categorical|2.7GB|

製程分析與我過去處理過的資料---銷售/庫存預測非常不同，90%以上都是NA，
而在生產線上，這是合理的，我們必須找出哪個製程出現問題，即重要變數。
問題是，NA過多，一般統計方法 AIC/BIC/lasso 無法處理missing value，
因此轉往使用 XGB 內建的 importance 找出重要變數。
首先單純使用 numeeric data 中進行預測，表現差，轉往使用其他 data ，
並參考kernel中第二名的作法，對 date data 進行 Feature Engineering 。

kernel : https://www.kaggle.com/danielfg/xgboost-reg-linear-lb-0-485/code/code
PS:RandPro 隨機降維可能是不錯的方法，http://steve-chen.tw/?p=611

# 特徵工程

在生產線上，可能在某一時段機器故障，導致產品出現問題，所以對 date data 進行特徵工程，
 
|feature|解釋|
|-------|---|
|first|進入該製成時間點|
|min|製成時間點最小值|
|last|離開該製成時間點|
|max|製成時間點最大值|
|class.amount|該製成時間點種類數量|
|na.amount|na數量，如果時間點完全記錄，那該變數代表未經過製程的數量|

由於 data 過大，分段製造 feature ，並在 linux 環境下使用 mclapply 平行運算加速


