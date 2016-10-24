---
layout: dark-post
title: Combating the Opioid Epidemic with Machine Learning
description: "A test post"
tags: [sample post]
---


Fatal drug overdoses account for a significant portion of accidental deaths in adolescents and young adults in the United States. The majority of fatal drug overdoses involve [opioids](https://www.drugabuse.gov/publications/research-reports/prescription-drugs/opioids/what-are-opioids), a class of inhibitor molecules that disrupt transmission of pain signals through the nervous system. Medically, they are used as powerful pain relievers; however, they also produce feelings of euphoria. This makes them highly addictive and prone to abuse. The same mechanism that suppresses pain also suppresses respiration, which can lead to death in the case of an overdose.

Over the past 15 years, deaths from prescription opiates have [quadrupled](https://www.cdc.gov/drugoverdose/epidemic/#), but so has the amount of opiates prescribed. This massive increase in prescription rates has occurred while the levels of pain experienced by Americans has [remain largely unchanged](http://time.com/3663907/treating-pain-opioids-painkillers/). Intuitively it follows that unneccessary prescriptions potentially play a significant role in the increase in opioid overdoses. An effective strategy for identifying instances of overprescribing is therefore a potentially life saving endeavor.

Here is a visualization of the distribution of fatal overdose rate across the country. By the end of this post, you'll see exactly how such an image can be built.

![](../../images/Identifying-Opioid-Prescribers/overdose-map.png)
<!-- more -->
The goal of this experiment is to demonstrate the possibility that predictive analytics with machine learning can be used to predict the likelihood that a given doctor is a significant prescriber of opiates. I'll compile a dataset, do some data cleaning and feature engineering, and finally build a predictive model using a gradient boosted classification tree ensemble with `gbm` and `caret` that predicts with &gt;80% accuracy that an arbitrary entry is a significant prescriber of opioids. I'll also do some analysis and visualization of my results combined with those pulled from other sources.  

If you are interested in the dataset, you can find it on Kaggle [here](https://www.kaggle.com/apryor6/us-opiate-prescriptions).

*Disclaimer* I am absolutely not suggesting that doctors who prescribe opiates are culpable for overdoses. These are drugs with true medical value when used appropriately. The idea is rather that a systematic way for identifying sources may reveal trends in particular practices, fields, or regions of the country that could be used effectively to combat the problem.

Building a Dataset
------------------

The primary source of the raw data I will be pulling from is [cms.org](https://www.cms.gov/Research-Statistics-Data-and-Systems/Statistics-Trends-and-Reports/Medicare-Provider-Charge-Data/Part-D-Prescriber.html). Part of Obamacare requires more visilibity into government aid programs, so this dataset is a compilation of drug prescriptions made to citizens claiming coverage under Class D Medicare. It contains approxiately 24 million entries in .csv format. Each row contains information about one doctor and one drug, so each doctor occurs multiple times (called long format). We want to pivot this data to wide format so that each row represents a single doctor and contains information on every drug. Those of you who have used Excel on large datasets will know painfully well that anything close to a million rows in Excel is painfully slow, so if you have ever wondered how to manage such a file, I've included the R code I used to build the dataset [here](https://github.com/apryor6/apryor6.github.io/tree/master/_posts/Identifying-Opioid-Prescribers). This kind of work is pretty code-dense and not exactly riveting, so I won't include the gory details here. Let's just skip to the fun part. The final trimmed result is a dataset containing 25,000 unique doctors and the numbers of prescriptions written for 250 drugs in the year 2014. Specifically, The data consists of the following characteristics for each prescriber

-NPI – unique National Provider Identifier number -Gender - (M/F) -State - U.S. State by abbreviation -Credentials - set of initials indicative of medical degree -Specialty - description of type of medicinal practice A long list of drugs with numeric values indicating the total number of prescriptions written for the year by that individual -Opioid.Prescriber - a boolean label indicating whether or not that individual prescribed opiate drugs more than 10 times in the year

Data Cleaning
-------------

The dataset was grouped and assembled into the right shape, but the data itself needs cleaning up.

Load the relevant libraries and read in the dataset

~~~ r
# setwd('/home/aj/kaggle/Identifying-Opioid-Prescribers')
setwd('/Users/ajpryor/kaggle/Identifying-Opioid-Prescribers')
library(dplyr)
library(magrittr)
library(ggplot2)
library(maps)
library(data.table)
library(lme4)
library(caret)

limit.rows <- 25000
df <- data.frame(fread("prescriber-info.csv",nrows=limit.rows))
~~~

First, we have to remove all of the information about opiate prescriptions from the data because that would be cheating. Conveniently, the same source that provided the raw data used to build this dataset also includes a list of all opiate drugs exactly as they are named in the data.

~~~ r
opioids <- read.csv("opioids.csv",skip=2)
opioids <- as.character(opioids[,2]) # second column contains the names of the opiates
opioids <- gsub("\ |-",".",opioids) # replace hyphens and spaces with periods to match the dataset
df <- df[, !names(df) %in% opioids]
~~~

Convert character columns to factors. I'm sure there is a nicer way to code this, but it's late and this works for now. Feel free to comment the better way.

~~~ r
char_cols <- c("NPI",names(df)[vapply(df,is.character,TRUE)])
df[,char_cols] <- lapply(df[,char_cols],as.factor)
~~~

Now let's clean up the factor variables

~~~ r
str(df[,1:5])
~~~

    ## 'data.frame':    25000 obs. of  5 variables:
    ##  $ NPI        : Factor w/ 25000 levels "1003002320","1003004771",..: 18016 6106 10728 16695 16924 13862 10913 10107 679 20644 ...
    ##  $ Gender     : Factor w/ 2 levels "F","M": 2 1 1 2 2 2 2 1 2 1 ...
    ##  $ State      : Factor w/ 57 levels "AA","AE","AK",..: 48 4 38 6 37 42 34 42 48 54 ...
    ##  $ Credentials: Factor w/ 888 levels "","(DMD)","A.N.P.",..: 244 507 403 507 403 314 507 839 697 507 ...
    ##  $ Specialty  : Factor w/ 109 levels "Addiction Medicine",..: 19 29 28 42 36 29 25 63 66 42 ...

Looks like the id's are unique and two genders is expected, but there's a few too many states and way too many credentials.

~~~ r
df %>%
  group_by(State) %>%
  dplyr::summarise(state.counts = n()) %>%
  arrange(state.counts)
~~~

    ## # A tibble: 57 x 2
    ##     State state.counts
    ##    <fctr>        <int>
    ## 1      AA            1
    ## 2      AE            2
    ## 3      GU            2
    ## 4      ZZ            2
    ## 5      VI            3
    ## 6      WY           38
    ## 7      AK           39
    ## 8      VT           65
    ## 9      ND           66
    ## 10     MT           77
    ## # ... with 47 more rows

[This site](http://www.infoplease.com/ipa/A0110468.html) indicates that some of these are legitimate, but rare, labels Like Guam (GU), but others appear to be typos. Let's create an "other" category for the rarely occurring abbreviations

~~~ r
rare.abbrev <- df %>%
  group_by(State) %>%
  dplyr::summarise(state.counts = n()) %>%
  arrange(state.counts) %>%
  filter(state.counts < 10) %>%
  select(State)

# Insert a new level into the factor, then remove the old names 
levels(df$State) <- c(levels(df$State),"other")
df$State[df$State %in% rare.abbrev$State] <- "other"
df$State <- droplevels(df$State)
~~~

As a quick sanity check to make sure we still don't have any bogus states, let's pull that table from the web and make sure our abbreviations are valid

~~~ r
library(htmltab)
state.abbrevs <- data.frame(htmltab("http://www.infoplease.com/ipa/A0110468.html",which=2))
state.abbrevs <- state.abbrevs$Postal.Code
if (all(levels(df$State)[levels(df$State)!="other"] %in% state.abbrevs)){print("All abbreviations are valid")} else{print("Uh oh..")}
~~~

    ## [1] "All abbreviations are valid"

Looking ahead, I'm going to be interested in the variable importance state-by-state, so instead of using a single factor I'll convert to dummy variables so each can be scored separately.

~~~ r
df <- cbind(df[names(df)!="State"],dummy(df$State))
~~~

Let's look at `Credentials` now

~~~ r
df %>%
  group_by(Credentials) %>%
  dplyr::summarise(credential.counts = n()) %>%
  arrange(credential.counts) %>% 
  data.frame() %>% 
  head(n=25)
~~~

    ##            Credentials credential.counts
    ## 1                (DMD)                 1
    ## 2        A.P.R.N. N.P.                 1
    ## 3       A.P.R.N., B.C.                 1
    ## 4   A.P.R.N., W.H.N.P.                 1
    ## 5  A.R.N.P. , PMHNP-BC                 1
    ## 6        A.R.N.P.-B.C.                 1
    ## 7   A.T.,C. , C.S.C.S.                 1
    ## 8        ACNP-BC, CCNS                 1
    ## 9         ACNP-BC, MSN                 1
    ## 10            ACNP/FNP                 1
    ## 11             ACNS-BC                 1
    ## 12            ADULT NP                 1
    ## 13              AGACNP                 1
    ## 14                AGNP                 1
    ## 15           AGPCNP-BC                 1
    ## 16               AHCNS                 1
    ## 17 ANNA TAVAKKOLI M.D.                 1
    ## 18             ANP B-C                 1
    ## 19         ANP-BC, GNP                 1
    ## 20          ANP-FNP-BC                 1
    ## 21              ANP,BC                 1
    ## 22                ANP.                 1
    ## 23             ANP/CNP                 1
    ## 24                ANRP                 1
    ## 25           APN FNP-C                 1

The credentials are quite the mess. Titles are inconsistently entered with periods, spaces, hyphens, etc, and many people have multiple credentials. While it's easy to make use of regular expressions to clean them, I won't bother because I suspect most of the predictive information contained in `Credentials` will be captured by `Specialty`.

~~~ r
# 7 years of college down the drain
df %<>%
  select(-Credentials)
~~~

On that note, let's look at `Specialty`

~~~ r
df %>%
  group_by(Specialty) %>%
  dplyr::summarise(specialty.counts = n()) %>%
  arrange(desc(specialty.counts)) %>% 
  data.frame() %>% 
  head(n=25)
~~~

    ##                                                         Specialty
    ## 1                                               Internal Medicine
    ## 2                                                 Family Practice
    ## 3                                                         Dentist
    ## 4                                              Nurse Practitioner
    ## 5                                             Physician Assistant
    ## 6                                              Emergency Medicine
    ## 7                                                      Psychiatry
    ## 8                                                      Cardiology
    ## 9                                           Obstetrics/Gynecology
    ## 10                                             Orthopedic Surgery
    ## 11                                                      Optometry
    ## 12 Student in an Organized Health Care Education/Training Program
    ## 13                                                  Ophthalmology
    ## 14                                                General Surgery
    ## 15                                               Gastroenterology
    ## 16                                                      Neurology
    ## 17                                                       Podiatry
    ## 18                                                    Dermatology
    ## 19                                                        Urology
    ## 20                                         Psychiatry & Neurology
    ## 21                                              Pulmonary Disease
    ## 22                                                 Otolaryngology
    ## 23                                               General Practice
    ## 24                                                     Nephrology
    ## 25                                            Hematology/Oncology
    ##    specialty.counts
    ## 1              3194
    ## 2              2975
    ## 3              2800
    ## 4              2512
    ## 5              1839
    ## 6              1087
    ## 7               691
    ## 8               688
    ## 9               615
    ## 10              575
    ## 11              571
    ## 12              547
    ## 13              519
    ## 14              487
    ## 15              399
    ## 16              371
    ## 17              369
    ## 18              344
    ## 19              328
    ## 20              266
    ## 21              262
    ## 22              260
    ## 23              247
    ## 24              236
    ## 25              218

There's a ton of ways to go about attacking this feature. Since there does not appear to be too much name clashing/redundancy, I'll use a couple of keywords to collapse some specialties together, and I'll also lump the rarely occurring ones together into an "other" category like before.

~~~ r
# Get the common specialties, we won't change those
common.specialties <- df %>%
  group_by(Specialty) %>%
  dplyr::summarise(specialty.counts = n()) %>%
  arrange(desc(specialty.counts)) %>% 
  filter(specialty.counts > 50) %>%
  select(Specialty)
common.specialties <- levels(droplevels(common.specialties$Specialty))


# Default to "other", then fill in. I'll make special levels for surgeons and collapse any category containing the word pain
new.specialties <- factor(x=rep("other",nrow(df)),levels=c(common.specialties,"Surgeon","other","Pain.Management"))
new.specialties[df$Specialty %in% common.specialties] <- df$Specialty[df$Specialty %in% common.specialties]
new.specialties[grepl("surg",df$Specialty,ignore.case=TRUE)] <- "Surgeon"
new.specialties[grepl("pain",df$Specialty,ignore.case=TRUE)] <- "Pain.Management"
new.specialties <- droplevels(new.specialties)
df$Specialty <- new.specialties
~~~

~~~ r
df %>%
  group_by(Specialty) %>%
  dplyr::summarise(specialty.counts = n()) %>%
  arrange(desc(specialty.counts)) %>% 
  data.frame() %>% 
  head(n=25)
~~~

    ##                                                         Specialty
    ## 1                                               Internal Medicine
    ## 2                                                 Family Practice
    ## 3                                                         Dentist
    ## 4                                              Nurse Practitioner
    ## 5                                             Physician Assistant
    ## 6                                                         Surgeon
    ## 7                                              Emergency Medicine
    ## 8                                                      Psychiatry
    ## 9                                                      Cardiology
    ## 10                                          Obstetrics/Gynecology
    ## 11                                                      Optometry
    ## 12 Student in an Organized Health Care Education/Training Program
    ## 13                                                  Ophthalmology
    ## 14                                                          other
    ## 15                                               Gastroenterology
    ## 16                                                      Neurology
    ## 17                                                       Podiatry
    ## 18                                                    Dermatology
    ## 19                                                        Urology
    ## 20                                         Psychiatry & Neurology
    ## 21                                              Pulmonary Disease
    ## 22                                                 Otolaryngology
    ## 23                                               General Practice
    ## 24                                                     Nephrology
    ## 25                                            Hematology/Oncology
    ##    specialty.counts
    ## 1              3194
    ## 2              2975
    ## 3              2800
    ## 4              2512
    ## 5              1839
    ## 6              1689
    ## 7              1087
    ## 8               691
    ## 9               688
    ## 10              615
    ## 11              571
    ## 12              547
    ## 13              519
    ## 14              454
    ## 15              399
    ## 16              371
    ## 17              369
    ## 18              344
    ## 19              328
    ## 20              266
    ## 21              262
    ## 22              260
    ## 23              247
    ## 24              236
    ## 25              218

Looks good. Like we did with `states`, let's make it a dummy so we can score the importance by specialty.

~~~ r
df <- df[!is.na(df$Specialty),]
df <- cbind(df[,names(df)!="Specialty"],dummy(df$Specialty))
~~~

Because this data is a subset of a larger dataset, it is possible that there are drugs here that aren't prescribed in any of the rows (i.e. the instances where they were prescribed got left behind). This would result in columns of all 0, which is bad. Multicollinear features are already bad because they mean the feature matrix is rank-deficient and, therefore, [non-invertible](https://en.wikipedia.org/wiki/Invertible_matrix#Other_properties). But beyond that, pure-zero features are a special kind of useless. Let's remove them.

~~~ r
df <- df[vapply(df,function(x) if (is.numeric(x)){sum(x)>0}else{TRUE},FUN.VALUE=TRUE)]
~~~

I used `vapply` because [sapply is unpredictable](https://blog.rstudio.org/2016/01/06/purrr-0-2-0/)

Model Building
--------------

I'll use a gradient boosted classification tree ensemble with `gbm` and `caret`. My reasoning is that with so many different features in the form of individual drugs, it's extremely likely that some of them are highly correlated (i.e. high blood pressure, heart medication, Aspirin). Something like an L1 regularized logistic regression followed by feature trimming would also work, but one of the nice things about this type of tree model is that it doesn't care about multicollinear features.

First, split the data.

~~~ r
train_faction <- 0.8
train_ind <- sample(nrow(df),round(train_faction*nrow(df)))
~~~

Remove the non-features, and convert the target label to something non-numeric (this package requires that)

~~~ r
df %<>% select(-NPI)
df$Opioid.Prescriber <- as.factor(ifelse(df$Opioid.Prescriber==1,"yes","no"))
train_set <- df[train_ind,]
test_set <- df[-train_ind,]
~~~

Now we build the model. I'll use a 5-fold cross validation to optimize hyperparameters for the boosted tree ensemble. A downside of trees is they take a while to train (though they predict quickly). For this reason I'll just use the default parameters and scan tree depths of 1-3 and total number of trees 50, 100, and 150. For a production model, one should do a more exhaustive search, but to keep this kernel relatively lightweight this is fine. I'll run this and go grab some coffee.

    ## + Fold1: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2657             nan     0.1000    0.0448
    ##      2        1.1923             nan     0.1000    0.0369
    ##      3        1.1315             nan     0.1000    0.0307
    ##      4        1.0799             nan     0.1000    0.0260
    ##      5        1.0356             nan     0.1000    0.0218
    ##      6        0.9984             nan     0.1000    0.0186
    ##      7        0.9667             nan     0.1000    0.0158
    ##      8        0.9395             nan     0.1000    0.0136
    ##      9        0.9157             nan     0.1000    0.0118
    ##     10        0.8950             nan     0.1000    0.0101
    ##     20        0.7702             nan     0.1000    0.0036
    ##     40        0.6652             nan     0.1000    0.0013
    ##     60        0.6203             nan     0.1000    0.0009
    ##     80        0.5886             nan     0.1000    0.0005
    ##    100        0.5673             nan     0.1000    0.0004
    ##    120        0.5502             nan     0.1000    0.0001
    ##    140        0.5381             nan     0.1000    0.0001
    ##    150        0.5335             nan     0.1000    0.0001
    ## 
    ## - Fold1: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold1: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2484             nan     0.1000    0.0533
    ##      2        1.1614             nan     0.1000    0.0437
    ##      3        1.0892             nan     0.1000    0.0363
    ##      4        1.0282             nan     0.1000    0.0306
    ##      5        0.9768             nan     0.1000    0.0258
    ##      6        0.9329             nan     0.1000    0.0219
    ##      7        0.8940             nan     0.1000    0.0192
    ##      8        0.8598             nan     0.1000    0.0164
    ##      9        0.8312             nan     0.1000    0.0140
    ##     10        0.8062             nan     0.1000    0.0125
    ##     20        0.6615             nan     0.1000    0.0047
    ##     40        0.5756             nan     0.1000    0.0019
    ##     60        0.5415             nan     0.1000    0.0015
    ##     80        0.5213             nan     0.1000    0.0003
    ##    100        0.5084             nan     0.1000    0.0001
    ##    120        0.4967             nan     0.1000   -0.0000
    ##    140        0.4881             nan     0.1000    0.0001
    ##    150        0.4852             nan     0.1000    0.0001
    ## 
    ## - Fold1: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold1: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2428             nan     0.1000    0.0565
    ##      2        1.1505             nan     0.1000    0.0463
    ##      3        1.0721             nan     0.1000    0.0384
    ##      4        1.0068             nan     0.1000    0.0329
    ##      5        0.9506             nan     0.1000    0.0277
    ##      6        0.9024             nan     0.1000    0.0238
    ##      7        0.8614             nan     0.1000    0.0204
    ##      8        0.8262             nan     0.1000    0.0175
    ##      9        0.7951             nan     0.1000    0.0155
    ##     10        0.7679             nan     0.1000    0.0135
    ##     20        0.6167             nan     0.1000    0.0041
    ##     40        0.5351             nan     0.1000    0.0008
    ##     60        0.5063             nan     0.1000    0.0006
    ##     80        0.4913             nan     0.1000    0.0001
    ##    100        0.4790             nan     0.1000   -0.0000
    ##    120        0.4701             nan     0.1000    0.0001
    ##    140        0.4621             nan     0.1000    0.0003
    ##    150        0.4588             nan     0.1000   -0.0000
    ## 
    ## - Fold1: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold2: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2659             nan     0.1000    0.0446
    ##      2        1.1925             nan     0.1000    0.0370
    ##      3        1.1318             nan     0.1000    0.0307
    ##      4        1.0797             nan     0.1000    0.0258
    ##      5        1.0363             nan     0.1000    0.0219
    ##      6        0.9995             nan     0.1000    0.0185
    ##      7        0.9682             nan     0.1000    0.0159
    ##      8        0.9408             nan     0.1000    0.0138
    ##      9        0.9171             nan     0.1000    0.0117
    ##     10        0.8964             nan     0.1000    0.0102
    ##     20        0.7721             nan     0.1000    0.0048
    ##     40        0.6712             nan     0.1000    0.0014
    ##     60        0.6201             nan     0.1000    0.0015
    ##     80        0.5910             nan     0.1000    0.0005
    ##    100        0.5686             nan     0.1000    0.0004
    ##    120        0.5524             nan     0.1000    0.0001
    ##    140        0.5397             nan     0.1000    0.0003
    ##    150        0.5359             nan     0.1000    0.0001
    ## 
    ## - Fold2: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold2: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2499             nan     0.1000    0.0529
    ##      2        1.1633             nan     0.1000    0.0435
    ##      3        1.0911             nan     0.1000    0.0362
    ##      4        1.0302             nan     0.1000    0.0304
    ##      5        0.9795             nan     0.1000    0.0258
    ##      6        0.9361             nan     0.1000    0.0219
    ##      7        0.8977             nan     0.1000    0.0190
    ##      8        0.8640             nan     0.1000    0.0169
    ##      9        0.8348             nan     0.1000    0.0145
    ##     10        0.8095             nan     0.1000    0.0127
    ##     20        0.6641             nan     0.1000    0.0038
    ##     40        0.5774             nan     0.1000    0.0007
    ##     60        0.5443             nan     0.1000    0.0005
    ##     80        0.5254             nan     0.1000    0.0003
    ##    100        0.5105             nan     0.1000    0.0002
    ##    120        0.5008             nan     0.1000    0.0003
    ##    140        0.4906             nan     0.1000    0.0000
    ##    150        0.4879             nan     0.1000    0.0001
    ## 
    ## - Fold2: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold2: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2422             nan     0.1000    0.0561
    ##      2        1.1505             nan     0.1000    0.0457
    ##      3        1.0730             nan     0.1000    0.0385
    ##      4        1.0068             nan     0.1000    0.0326
    ##      5        0.9520             nan     0.1000    0.0276
    ##      6        0.9051             nan     0.1000    0.0235
    ##      7        0.8641             nan     0.1000    0.0205
    ##      8        0.8287             nan     0.1000    0.0175
    ##      9        0.7978             nan     0.1000    0.0154
    ##     10        0.7705             nan     0.1000    0.0133
    ##     20        0.6188             nan     0.1000    0.0041
    ##     40        0.5392             nan     0.1000    0.0014
    ##     60        0.5107             nan     0.1000    0.0002
    ##     80        0.4955             nan     0.1000    0.0002
    ##    100        0.4840             nan     0.1000    0.0000
    ##    120        0.4725             nan     0.1000    0.0001
    ##    140        0.4637             nan     0.1000    0.0000
    ##    150        0.4594             nan     0.1000    0.0000
    ## 
    ## - Fold2: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold3: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2671             nan     0.1000    0.0444
    ##      2        1.1943             nan     0.1000    0.0369
    ##      3        1.1336             nan     0.1000    0.0305
    ##      4        1.0823             nan     0.1000    0.0256
    ##      5        1.0391             nan     0.1000    0.0218
    ##      6        1.0024             nan     0.1000    0.0184
    ##      7        0.9702             nan     0.1000    0.0159
    ##      8        0.9433             nan     0.1000    0.0136
    ##      9        0.9197             nan     0.1000    0.0117
    ##     10        0.8995             nan     0.1000    0.0101
    ##     20        0.7745             nan     0.1000    0.0048
    ##     40        0.6715             nan     0.1000    0.0008
    ##     60        0.6221             nan     0.1000    0.0004
    ##     80        0.5913             nan     0.1000    0.0011
    ##    100        0.5702             nan     0.1000    0.0002
    ##    120        0.5552             nan     0.1000    0.0001
    ##    140        0.5436             nan     0.1000    0.0002
    ##    150        0.5374             nan     0.1000    0.0001
    ## 
    ## - Fold3: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold3: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2491             nan     0.1000    0.0529
    ##      2        1.1622             nan     0.1000    0.0434
    ##      3        1.0897             nan     0.1000    0.0360
    ##      4        1.0284             nan     0.1000    0.0302
    ##      5        0.9779             nan     0.1000    0.0249
    ##      6        0.9338             nan     0.1000    0.0222
    ##      7        0.8959             nan     0.1000    0.0190
    ##      8        0.8628             nan     0.1000    0.0161
    ##      9        0.8337             nan     0.1000    0.0145
    ##     10        0.8085             nan     0.1000    0.0123
    ##     20        0.6651             nan     0.1000    0.0044
    ##     40        0.5825             nan     0.1000    0.0007
    ##     60        0.5454             nan     0.1000    0.0005
    ##     80        0.5266             nan     0.1000    0.0001
    ##    100        0.5119             nan     0.1000    0.0003
    ##    120        0.5023             nan     0.1000    0.0001
    ##    140        0.4938             nan     0.1000    0.0000
    ##    150        0.4904             nan     0.1000    0.0001
    ## 
    ## - Fold3: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold3: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2435             nan     0.1000    0.0559
    ##      2        1.1512             nan     0.1000    0.0463
    ##      3        1.0750             nan     0.1000    0.0381
    ##      4        1.0089             nan     0.1000    0.0326
    ##      5        0.9538             nan     0.1000    0.0274
    ##      6        0.9055             nan     0.1000    0.0236
    ##      7        0.8644             nan     0.1000    0.0204
    ##      8        0.8289             nan     0.1000    0.0178
    ##      9        0.7986             nan     0.1000    0.0151
    ##     10        0.7714             nan     0.1000    0.0136
    ##     20        0.6200             nan     0.1000    0.0045
    ##     40        0.5389             nan     0.1000    0.0012
    ##     60        0.5134             nan     0.1000    0.0003
    ##     80        0.4961             nan     0.1000    0.0002
    ##    100        0.4835             nan     0.1000    0.0006
    ##    120        0.4740             nan     0.1000    0.0000
    ##    140        0.4669             nan     0.1000    0.0000
    ##    150        0.4628             nan     0.1000    0.0001
    ## 
    ## - Fold3: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold4: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2665             nan     0.1000    0.0446
    ##      2        1.1927             nan     0.1000    0.0366
    ##      3        1.1318             nan     0.1000    0.0304
    ##      4        1.0810             nan     0.1000    0.0257
    ##      5        1.0378             nan     0.1000    0.0219
    ##      6        1.0010             nan     0.1000    0.0187
    ##      7        0.9688             nan     0.1000    0.0160
    ##      8        0.9415             nan     0.1000    0.0137
    ##      9        0.9180             nan     0.1000    0.0118
    ##     10        0.8978             nan     0.1000    0.0103
    ##     20        0.7699             nan     0.1000    0.0048
    ##     40        0.6628             nan     0.1000    0.0021
    ##     60        0.6119             nan     0.1000    0.0015
    ##     80        0.5822             nan     0.1000    0.0002
    ##    100        0.5617             nan     0.1000    0.0004
    ##    120        0.5458             nan     0.1000    0.0006
    ##    140        0.5343             nan     0.1000    0.0001
    ##    150        0.5274             nan     0.1000    0.0005
    ## 
    ## - Fold4: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold4: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2482             nan     0.1000    0.0535
    ##      2        1.1609             nan     0.1000    0.0436
    ##      3        1.0880             nan     0.1000    0.0364
    ##      4        1.0263             nan     0.1000    0.0306
    ##      5        0.9756             nan     0.1000    0.0255
    ##      6        0.9305             nan     0.1000    0.0224
    ##      7        0.8921             nan     0.1000    0.0190
    ##      8        0.8583             nan     0.1000    0.0169
    ##      9        0.8293             nan     0.1000    0.0143
    ##     10        0.8030             nan     0.1000    0.0127
    ##     20        0.6597             nan     0.1000    0.0041
    ##     40        0.5706             nan     0.1000    0.0007
    ##     60        0.5379             nan     0.1000    0.0011
    ##     80        0.5187             nan     0.1000    0.0002
    ##    100        0.5046             nan     0.1000    0.0001
    ##    120        0.4944             nan     0.1000    0.0000
    ##    140        0.4873             nan     0.1000   -0.0000
    ##    150        0.4830             nan     0.1000    0.0001
    ## 
    ## - Fold4: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold4: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2414             nan     0.1000    0.0570
    ##      2        1.1494             nan     0.1000    0.0465
    ##      3        1.0712             nan     0.1000    0.0388
    ##      4        1.0048             nan     0.1000    0.0331
    ##      5        0.9480             nan     0.1000    0.0280
    ##      6        0.8999             nan     0.1000    0.0237
    ##      7        0.8585             nan     0.1000    0.0203
    ##      8        0.8222             nan     0.1000    0.0181
    ##      9        0.7915             nan     0.1000    0.0152
    ##     10        0.7643             nan     0.1000    0.0135
    ##     20        0.6119             nan     0.1000    0.0044
    ##     40        0.5322             nan     0.1000    0.0008
    ##     60        0.5057             nan     0.1000    0.0004
    ##     80        0.4884             nan     0.1000    0.0004
    ##    100        0.4765             nan     0.1000    0.0001
    ##    120        0.4676             nan     0.1000   -0.0000
    ##    140        0.4600             nan     0.1000   -0.0000
    ##    150        0.4565             nan     0.1000   -0.0000
    ## 
    ## - Fold4: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold5: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2666             nan     0.1000    0.0447
    ##      2        1.1924             nan     0.1000    0.0370
    ##      3        1.1315             nan     0.1000    0.0308
    ##      4        1.0794             nan     0.1000    0.0258
    ##      5        1.0351             nan     0.1000    0.0217
    ##      6        0.9983             nan     0.1000    0.0185
    ##      7        0.9665             nan     0.1000    0.0158
    ##      8        0.9396             nan     0.1000    0.0137
    ##      9        0.9161             nan     0.1000    0.0118
    ##     10        0.8955             nan     0.1000    0.0102
    ##     20        0.7698             nan     0.1000    0.0051
    ##     40        0.6666             nan     0.1000    0.0023
    ##     60        0.6212             nan     0.1000    0.0009
    ##     80        0.5858             nan     0.1000    0.0004
    ##    100        0.5669             nan     0.1000    0.0002
    ##    120        0.5516             nan     0.1000    0.0001
    ##    140        0.5407             nan     0.1000    0.0000
    ##    150        0.5323             nan     0.1000    0.0006
    ## 
    ## - Fold5: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold5: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2486             nan     0.1000    0.0532
    ##      2        1.1615             nan     0.1000    0.0436
    ##      3        1.0891             nan     0.1000    0.0364
    ##      4        1.0273             nan     0.1000    0.0303
    ##      5        0.9762             nan     0.1000    0.0256
    ##      6        0.9323             nan     0.1000    0.0220
    ##      7        0.8947             nan     0.1000    0.0191
    ##      8        0.8604             nan     0.1000    0.0170
    ##      9        0.8315             nan     0.1000    0.0142
    ##     10        0.8054             nan     0.1000    0.0127
    ##     20        0.6615             nan     0.1000    0.0042
    ##     40        0.5743             nan     0.1000    0.0014
    ##     60        0.5418             nan     0.1000    0.0002
    ##     80        0.5232             nan     0.1000    0.0003
    ##    100        0.5100             nan     0.1000    0.0002
    ##    120        0.4959             nan     0.1000    0.0001
    ##    140        0.4872             nan     0.1000   -0.0001
    ##    150        0.4842             nan     0.1000    0.0000
    ## 
    ## - Fold5: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold5: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2436             nan     0.1000    0.0566
    ##      2        1.1513             nan     0.1000    0.0466
    ##      3        1.0738             nan     0.1000    0.0386
    ##      4        1.0076             nan     0.1000    0.0333
    ##      5        0.9510             nan     0.1000    0.0276
    ##      6        0.9032             nan     0.1000    0.0241
    ##      7        0.8613             nan     0.1000    0.0206
    ##      8        0.8252             nan     0.1000    0.0176
    ##      9        0.7946             nan     0.1000    0.0153
    ##     10        0.7670             nan     0.1000    0.0136
    ##     20        0.6164             nan     0.1000    0.0041
    ##     40        0.5372             nan     0.1000    0.0009
    ##     60        0.5091             nan     0.1000    0.0004
    ##     80        0.4928             nan     0.1000    0.0001
    ##    100        0.4776             nan     0.1000    0.0001
    ##    120        0.4683             nan     0.1000    0.0001
    ##    140        0.4595             nan     0.1000    0.0000
    ##    150        0.4560             nan     0.1000    0.0001
    ## 
    ## - Fold5: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Aggregating results
    ## Selecting tuning parameters
    ## Fitting n.trees = 150, interaction.depth = 3, shrinkage = 0.1, n.minobsinnode = 10 on full training set
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.2416             nan     0.1000    0.0563
    ##      2        1.1490             nan     0.1000    0.0462
    ##      3        1.0711             nan     0.1000    0.0383
    ##      4        1.0055             nan     0.1000    0.0328
    ##      5        0.9501             nan     0.1000    0.0274
    ##      6        0.9035             nan     0.1000    0.0233
    ##      7        0.8624             nan     0.1000    0.0202
    ##      8        0.8264             nan     0.1000    0.0180
    ##      9        0.7958             nan     0.1000    0.0149
    ##     10        0.7684             nan     0.1000    0.0137
    ##     20        0.6170             nan     0.1000    0.0046
    ##     40        0.5363             nan     0.1000    0.0012
    ##     60        0.5075             nan     0.1000    0.0005
    ##     80        0.4933             nan     0.1000    0.0002
    ##    100        0.4811             nan     0.1000    0.0001
    ##    120        0.4706             nan     0.1000    0.0002
    ##    140        0.4630             nan     0.1000    0.0005
    ##    150        0.4603             nan     0.1000    0.0000

    ## Confusion Matrix and Statistics
    ## 
    ##           Reference
    ## Prediction   no  yes
    ##        no  1999  414
    ##        yes   65 2522
    ##                                           
    ##                Accuracy : 0.9042          
    ##                  95% CI : (0.8957, 0.9122)
    ##     No Information Rate : 0.5872          
    ##     P-Value [Acc > NIR] : < 2.2e-16       
    ##                                           
    ##                   Kappa : 0.8072          
    ##  Mcnemar's Test P-Value : < 2.2e-16       
    ##                                           
    ##             Sensitivity : 0.8590          
    ##             Specificity : 0.9685          
    ##          Pos Pred Value : 0.9749          
    ##          Neg Pred Value : 0.8284          
    ##              Prevalence : 0.5872          
    ##          Detection Rate : 0.5044          
    ##    Detection Prevalence : 0.5174          
    ##       Balanced Accuracy : 0.9137          
    ##                                           
    ##        'Positive' Class : yes             
    ## 

Looks like we did a good job, the accuracy is not bad for a first attempt. I would be very interested to see others fork this kernel and make it even more accurate. If our goal is to predict significant sources of opioid prescriptions for the purpose of some government agency doing investigative work, then we would likely care more about precision (Pos Pred Value in this package) than accuracy. The reason is because a false positive is potentially sending people on a wild goose chase, wasting money and time.

The other nice thing about trees is the ability to view the importance of the features in the decision making process. This is done by cycling through each feature, randomly shuffling its values about, and seeing how much that hurts your cross-validation results. If shuffling a feature screws you up, then it must be pretty important. Let's extract the importance from our model with `varImp` and make a bar plot.

~~~ r
importance <- as.data.frame(varImp(model)[1])
importance <- cbind(row.names(importance), Importance=importance)
row.names(importance)<-NULL
names(importance) <- c("Feature","Importance")
importance %>% arrange(desc(Importance)) %>%
  mutate(Feature=factor(Feature,levels=as.character(Feature))) %>%
  slice(1:15) %>%
  ggplot() + geom_bar(aes(x=Feature,y=(Importance)),stat="identity",fill="blue") + 
  theme(axis.text.x=element_text(angle=45,vjust = 1,hjust=1),axis.ticks.x = element_blank()) +ylab("Importance") +ggtitle("Feature Importance for Detecting Opioid Prescription")
~~~

![](../../images/Identifying-Opioid-Prescribers/unnamed-chunk-19-1.png)

Our best feature was a drug called [Gabapentin](https://www.drugs.com/gabapentin.html), which unsurprisingly is used to treat nerve pain caused by things like shingles. It's not an opiate, but likely gets prescribed at the same time. The `Surgeon` feature we engineered has done quite well. The other drugs are for various conditions including inflamatation, cancer, and athritis among others.

It probably doesn't surprise anybody that surgeons commonly prescribe pain medication, or that the people taking cancer drugs are also taking pain pills. But with a very large feature set it becomes entirely intractable for a human to make maximal use of the available information. I would expect a human analyzing this data would immediately classify candidates based upon their profession, but machine learning has enabled us to break it down further based upon the specific drug prescription trends doctor by doctor. Truly a powerful tool.

Summary/Analysis
----------------

We succeeded in building a pretty good opiate-prescription detection algorithm based primarily on their profession and prescription rates of non-opiate drugs. This could be used to combat overdoses in a number of ways. Professions who show up with high importance in the model can reveal medical fields that could benefit in the long run from curriculum shifts towards awareness of the potential dangers. Science evolves rapidly, and this sort of dynamic shift of the "state-of-the-art" opinion is quite common. It's also possible that individual drugs that are strong detectors may identify more accurately a sub-specialty of individual prescribers that could be of interest, or even reveal hidden avenues of illegitimate drug access.

And, finally, as promised here is the code I used to generate the image at the beginning of the post.

~~~ r
all_states <- map_data("state")
od <- read.csv("overdoses.csv",stringsAsFactors = FALSE)
od$State <- as.factor(od$State)
od$Population <- as.numeric(gsub(",","",od$Population))
od$Deaths<- as.numeric(gsub(",","",od$Deaths))

od %>%
  mutate(state.lower=tolower(State), Population=as.numeric(Population)) %>%
  merge(all_states,by.x="state.lower",by.y="region") %>%
  select(-subregion,-order) %>% 
  ggplot() + geom_map(map=all_states, aes(x=long, y=lat, map_id=state.lower,fill=Deaths/Population*1e6) )  + ggtitle("U.S. Opiate Overdose Death Rate") +
  geom_text(data=data.frame(state.center,od$Abbrev),aes(x=x, y=y,label=od.Abbrev),size=3) +
  scale_fill_continuous(low='gray85', high='darkred',guide=guide_colorbar(ticks=FALSE,barheight=1,barwidth=10,title.vjust=.8,values=c(0.2,0.3)),name="Deaths per Million") + theme(axis.text=element_blank(),axis.title=element_blank(),axis.ticks=element_blank(),legend.position="bottom",plot.title=element_text(size=20))
~~~

![](../../images/Identifying-Opioid-Prescribers/unnamed-chunk-20-1.png)

As you can see, it's a serious problem. Maybe we as data scientists have the tools to make a difference.
