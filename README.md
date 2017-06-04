# kaggle_Production_Line

kaggle website : 
https://www.kaggle.com/c/bosch-production-line-performance

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


