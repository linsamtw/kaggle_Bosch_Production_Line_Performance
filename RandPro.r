
library(RandPro)

# 假設已經透過 tm 套件建立了 tdm 矩陣，e.g. 15000 個詞彙 x 4000 篇文章
 
tdm2 = as.matrix(tdm)
 
library(RandPro)
 
# 算出最低轉換維度 , 4000 為文章數量
find_dim_JL(4000,0.5)
# [1] 398
 
# 將 15000 個詞彙/變數縮減維度到 398 個變數
R2 = form_sparse_matrix(398,15000,FALSE) 
 
tdm3 = R2 %*% tdm2
 
dtm3 = t(tdm3) # 4000 篇文章 x 398 個變數
 
# 接下來這個 dtm3 就可以直接拿去做 clustering/classification