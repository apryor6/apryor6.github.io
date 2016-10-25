---
layout: dark-post
title:  "Combating the Opioid Epidemic with Machine Learning"
description: "Combating the Opioid Epidemic with Machine Learning"
tags: [sample post]
---


Fatal drug overdoses account for a significant portion of accidental deaths in adolescents and young adults in the United States. The majority of fatal drug overdoses involve [opioids](https://www.drugabuse.gov/publications/research-reports/prescription-drugs/opioids/what-are-opioids), a class of inhibitor molecules that disrupt transmission of pain signals through the nervous system. Medically, they are used as powerful pain relievers; however, they also produce feelings of euphoria. This makes them highly addictive and prone to abuse. The same mechanism that suppresses pain also suppresses respiration, which can lead to death in the case of an overdose.

Over the past 15 years, deaths from prescription opiates have [quadrupled](https://www.cdc.gov/drugoverdose/epidemic/#), but so has the amount of opiates prescribed. This massive increase in prescription rates has occurred while the levels of pain experienced by Americans has [remain largely unchanged](http://time.com/3663907/treating-pain-opioids-painkillers/). Intuitively it follows that unneccessary prescriptions potentially play a significant role in the increase in opioid overdoses. An effective strategy for identifying instances of overprescribing is therefore a potentially life saving endeavor.

Here is a visualization of the distribution of fatal overdose rate across the country. By the end of this post, you'll see exactly how such an image can be built.

![](../images/Identifying-Opioid-Prescribers/overdose-map.png)

The goal of this experiment is to demonstrate the possibility that predictive analytics with machine learning can be used to predict the likelihood that a given doctor is a significant prescriber of opiates. I'll compile a dataset, do some data cleaning and feature engineering, and finally build a predictive model using a gradient boosted classification tree ensemble with `gbm` and `caret` that predicts with &gt;80% accuracy that an arbitrary entry is a significant prescriber of opioids. I'll also do some analysis and visualization of my results combined with those pulled from other sources. If you are interested in the dataset, you can find it on Kaggle [here](https://www.kaggle.com/apryor6/us-opiate-prescriptions).

*Disclaimer I am absolutely not suggesting that doctors who prescribe opiates are culpable for overdoses. These are drugs with true medical value when used appropriately. The idea is rather that a systematic way for identifying sources may reveal trends in particular practices, fields, or regions of the country that could be used effectively to combat the problem.*

Building a Dataset
------------------

The primary source of the raw data I will be pulling from is [cms.org](https://www.cms.gov/Research-Statistics-Data-and-Systems/Statistics-Trends-and-Reports/Medicare-Provider-Charge-Data/Part-D-Prescriber.html). Part of Obamacare requires more visilibity into government aid programs, so this dataset is a compilation of drug prescriptions made to citizens claiming coverage under Class D Medicare. It contains approxiately 24 million entries in .csv format. Each row contains information about one doctor and one drug, so each doctor occurs multiple times (called long format). We want to pivot this data to wide format so that each row represents a single doctor and contains information on every drug.  

Those of you who have used Excel on large datasets will know painfully well that anything close to a million rows in Excel is painfully slow, so if you have ever wondered how to manage such a file, I've included the R code I used to build the dataset [here](https://github.com/apryor6/apryor6.github.io/tree/master/_posts/Identifying-Opioid-Prescribers).   

This kind of work is pretty code-dense and not exactly riveting, so I won't include the gory details here. Let's just skip to the fun part. The final trimmed result is a dataset containing 25,000 unique doctors and the numbers of prescriptions written for 250 drugs in the year 2014. Specifically, The data consists of the following characteristics for each prescriber

-   NPI – unique National Provider Identifier number
-   Gender - (M/F)
-   State - U.S. State by abbreviation
-   Credentials - set of initials indicative of medical degree
-   Specialty - description of type of medicinal practice A long list of drugs with numeric values indicating the total number of prescriptions written for the year by that individual
-   Opioid.Prescriber - a boolean label indicating whether or not that individual prescribed opiate drugs more than 10 times in the year

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

df <- data.frame(fread("prescriber-info.csv",nrows=-1))
~~~

    ## [1] 25000   256

First, we have to remove all of the information about opiate prescriptions from the data because that would be cheating. Conveniently, the same source that provided the raw data used to build this dataset also includes a list of all opiate drugs exactly as they are named in the data.

~~~ r
opioids <- read.csv("opioids.csv")
opioids <- as.character(opioids[,1])
opioids <- gsub("\ |-",".",opioids) # replace hyphens and spaces with periods to match the dataset
df <- df[, !names(df) %in% opioids]
~~~

    ## [1] 25000   245

Convert character columns to factors. 

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

    ## [1] 25000   295

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
    ##      1        1.3305             nan     0.1000    0.0125
    ##      2        1.3082             nan     0.1000    0.0112
    ##      3        1.2892             nan     0.1000    0.0092
    ##      4        1.2730             nan     0.1000    0.0083
    ##      5        1.2573             nan     0.1000    0.0076
    ##      6        1.2429             nan     0.1000    0.0069
    ##      7        1.2298             nan     0.1000    0.0064
    ##      8        1.2183             nan     0.1000    0.0058
    ##      9        1.2081             nan     0.1000    0.0050
    ##     10        1.1995             nan     0.1000    0.0043
    ##     20        1.1239             nan     0.1000    0.0038
    ##     40        1.0376             nan     0.1000    0.0014
    ##     60        0.9848             nan     0.1000    0.0008
    ##     80        0.9500             nan     0.1000    0.0008
    ##    100        0.9249             nan     0.1000    0.0003
    ##    120        0.9037             nan     0.1000    0.0002
    ##    140        0.8878             nan     0.1000    0.0002
    ##    150        0.8801             nan     0.1000    0.0001
    ## 
    ## - Fold1: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold1: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3194             nan     0.1000    0.0179
    ##      2        1.2883             nan     0.1000    0.0153
    ##      3        1.2608             nan     0.1000    0.0134
    ##      4        1.2362             nan     0.1000    0.0120
    ##      5        1.2122             nan     0.1000    0.0119
    ##      6        1.1920             nan     0.1000    0.0095
    ##      7        1.1739             nan     0.1000    0.0090
    ##      8        1.1562             nan     0.1000    0.0087
    ##      9        1.1416             nan     0.1000    0.0070
    ##     10        1.1277             nan     0.1000    0.0070
    ##     20        1.0287             nan     0.1000    0.0035
    ##     40        0.9412             nan     0.1000    0.0011
    ##     60        0.8960             nan     0.1000    0.0005
    ##     80        0.8634             nan     0.1000    0.0003
    ##    100        0.8403             nan     0.1000    0.0004
    ##    120        0.8214             nan     0.1000    0.0002
    ##    140        0.8075             nan     0.1000    0.0001
    ##    150        0.8023             nan     0.1000   -0.0000
    ## 
    ## - Fold1: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold1: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3099             nan     0.1000    0.0225
    ##      2        1.2702             nan     0.1000    0.0196
    ##      3        1.2368             nan     0.1000    0.0165
    ##      4        1.2079             nan     0.1000    0.0144
    ##      5        1.1808             nan     0.1000    0.0134
    ##      6        1.1597             nan     0.1000    0.0102
    ##      7        1.1385             nan     0.1000    0.0104
    ##      8        1.1194             nan     0.1000    0.0094
    ##      9        1.1008             nan     0.1000    0.0093
    ##     10        1.0847             nan     0.1000    0.0080
    ##     20        0.9816             nan     0.1000    0.0036
    ##     40        0.8919             nan     0.1000    0.0013
    ##     60        0.8473             nan     0.1000    0.0006
    ##     80        0.8187             nan     0.1000    0.0005
    ##    100        0.7979             nan     0.1000    0.0002
    ##    120        0.7823             nan     0.1000    0.0001
    ##    140        0.7701             nan     0.1000    0.0001
    ##    150        0.7643             nan     0.1000    0.0001
    ## 
    ## - Fold1: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold2: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3310             nan     0.1000    0.0121
    ##      2        1.3089             nan     0.1000    0.0108
    ##      3        1.2904             nan     0.1000    0.0091
    ##      4        1.2731             nan     0.1000    0.0086
    ##      5        1.2575             nan     0.1000    0.0081
    ##      6        1.2432             nan     0.1000    0.0069
    ##      7        1.2296             nan     0.1000    0.0066
    ##      8        1.2175             nan     0.1000    0.0058
    ##      9        1.2072             nan     0.1000    0.0049
    ##     10        1.1987             nan     0.1000    0.0042
    ##     20        1.1231             nan     0.1000    0.0029
    ##     40        1.0359             nan     0.1000    0.0016
    ##     60        0.9823             nan     0.1000    0.0011
    ##     80        0.9445             nan     0.1000    0.0005
    ##    100        0.9182             nan     0.1000    0.0006
    ##    120        0.8990             nan     0.1000    0.0003
    ##    140        0.8818             nan     0.1000    0.0002
    ##    150        0.8746             nan     0.1000    0.0001
    ## 
    ## - Fold2: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold2: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3206             nan     0.1000    0.0173
    ##      2        1.2895             nan     0.1000    0.0156
    ##      3        1.2622             nan     0.1000    0.0135
    ##      4        1.2367             nan     0.1000    0.0129
    ##      5        1.2143             nan     0.1000    0.0113
    ##      6        1.1934             nan     0.1000    0.0102
    ##      7        1.1742             nan     0.1000    0.0093
    ##      8        1.1575             nan     0.1000    0.0084
    ##      9        1.1421             nan     0.1000    0.0077
    ##     10        1.1282             nan     0.1000    0.0070
    ##     20        1.0303             nan     0.1000    0.0031
    ##     40        0.9371             nan     0.1000    0.0014
    ##     60        0.8888             nan     0.1000    0.0007
    ##     80        0.8587             nan     0.1000    0.0004
    ##    100        0.8369             nan     0.1000    0.0005
    ##    120        0.8190             nan     0.1000    0.0004
    ##    140        0.8049             nan     0.1000    0.0001
    ##    150        0.7994             nan     0.1000    0.0001
    ## 
    ## - Fold2: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold2: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3095             nan     0.1000    0.0224
    ##      2        1.2712             nan     0.1000    0.0192
    ##      3        1.2367             nan     0.1000    0.0174
    ##      4        1.2074             nan     0.1000    0.0141
    ##      5        1.1809             nan     0.1000    0.0131
    ##      6        1.1586             nan     0.1000    0.0106
    ##      7        1.1371             nan     0.1000    0.0107
    ##      8        1.1177             nan     0.1000    0.0095
    ##      9        1.1003             nan     0.1000    0.0083
    ##     10        1.0853             nan     0.1000    0.0073
    ##     20        0.9797             nan     0.1000    0.0033
    ##     40        0.8876             nan     0.1000    0.0009
    ##     60        0.8427             nan     0.1000    0.0007
    ##     80        0.8139             nan     0.1000    0.0005
    ##    100        0.7941             nan     0.1000    0.0005
    ##    120        0.7779             nan     0.1000    0.0001
    ##    140        0.7655             nan     0.1000    0.0001
    ##    150        0.7600             nan     0.1000    0.0004
    ## 
    ## - Fold2: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold3: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3307             nan     0.1000    0.0130
    ##      2        1.3078             nan     0.1000    0.0111
    ##      3        1.2894             nan     0.1000    0.0093
    ##      4        1.2726             nan     0.1000    0.0086
    ##      5        1.2574             nan     0.1000    0.0072
    ##      6        1.2434             nan     0.1000    0.0067
    ##      7        1.2298             nan     0.1000    0.0066
    ##      8        1.2185             nan     0.1000    0.0053
    ##      9        1.2075             nan     0.1000    0.0054
    ##     10        1.1992             nan     0.1000    0.0041
    ##     20        1.1252             nan     0.1000    0.0027
    ##     40        1.0386             nan     0.1000    0.0019
    ##     60        0.9865             nan     0.1000    0.0009
    ##     80        0.9520             nan     0.1000    0.0007
    ##    100        0.9271             nan     0.1000    0.0006
    ##    120        0.9084             nan     0.1000    0.0005
    ##    140        0.8907             nan     0.1000    0.0002
    ##    150        0.8832             nan     0.1000    0.0002
    ## 
    ## - Fold3: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold3: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3191             nan     0.1000    0.0181
    ##      2        1.2879             nan     0.1000    0.0155
    ##      3        1.2612             nan     0.1000    0.0131
    ##      4        1.2366             nan     0.1000    0.0124
    ##      5        1.2142             nan     0.1000    0.0108
    ##      6        1.1945             nan     0.1000    0.0098
    ##      7        1.1762             nan     0.1000    0.0090
    ##      8        1.1590             nan     0.1000    0.0086
    ##      9        1.1437             nan     0.1000    0.0076
    ##     10        1.1293             nan     0.1000    0.0071
    ##     20        1.0350             nan     0.1000    0.0034
    ##     40        0.9438             nan     0.1000    0.0011
    ##     60        0.8990             nan     0.1000    0.0007
    ##     80        0.8672             nan     0.1000    0.0003
    ##    100        0.8444             nan     0.1000    0.0003
    ##    120        0.8267             nan     0.1000    0.0005
    ##    140        0.8137             nan     0.1000    0.0002
    ##    150        0.8070             nan     0.1000    0.0004
    ## 
    ## - Fold3: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold3: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3102             nan     0.1000    0.0227
    ##      2        1.2718             nan     0.1000    0.0190
    ##      3        1.2398             nan     0.1000    0.0160
    ##      4        1.2117             nan     0.1000    0.0143
    ##      5        1.1845             nan     0.1000    0.0135
    ##      6        1.1620             nan     0.1000    0.0111
    ##      7        1.1410             nan     0.1000    0.0105
    ##      8        1.1230             nan     0.1000    0.0088
    ##      9        1.1061             nan     0.1000    0.0084
    ##     10        1.0915             nan     0.1000    0.0072
    ##     20        0.9865             nan     0.1000    0.0035
    ##     40        0.8978             nan     0.1000    0.0010
    ##     60        0.8508             nan     0.1000    0.0008
    ##     80        0.8236             nan     0.1000    0.0002
    ##    100        0.8019             nan     0.1000    0.0002
    ##    120        0.7864             nan     0.1000    0.0001
    ##    140        0.7745             nan     0.1000    0.0000
    ##    150        0.7688             nan     0.1000    0.0000
    ## 
    ## - Fold3: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold4: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3312             nan     0.1000    0.0120
    ##      2        1.3086             nan     0.1000    0.0112
    ##      3        1.2896             nan     0.1000    0.0093
    ##      4        1.2723             nan     0.1000    0.0085
    ##      5        1.2566             nan     0.1000    0.0076
    ##      6        1.2425             nan     0.1000    0.0069
    ##      7        1.2295             nan     0.1000    0.0065
    ##      8        1.2185             nan     0.1000    0.0055
    ##      9        1.2075             nan     0.1000    0.0053
    ##     10        1.1990             nan     0.1000    0.0042
    ##     20        1.1260             nan     0.1000    0.0026
    ##     40        1.0342             nan     0.1000    0.0020
    ##     60        0.9801             nan     0.1000    0.0010
    ##     80        0.9470             nan     0.1000    0.0005
    ##    100        0.9229             nan     0.1000    0.0004
    ##    120        0.9009             nan     0.1000    0.0004
    ##    140        0.8841             nan     0.1000    0.0005
    ##    150        0.8766             nan     0.1000    0.0003
    ## 
    ## - Fold4: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold4: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3206             nan     0.1000    0.0182
    ##      2        1.2902             nan     0.1000    0.0149
    ##      3        1.2628             nan     0.1000    0.0135
    ##      4        1.2365             nan     0.1000    0.0129
    ##      5        1.2143             nan     0.1000    0.0113
    ##      6        1.1938             nan     0.1000    0.0103
    ##      7        1.1751             nan     0.1000    0.0090
    ##      8        1.1579             nan     0.1000    0.0086
    ##      9        1.1425             nan     0.1000    0.0074
    ##     10        1.1286             nan     0.1000    0.0068
    ##     20        1.0283             nan     0.1000    0.0035
    ##     40        0.9390             nan     0.1000    0.0009
    ##     60        0.8912             nan     0.1000    0.0005
    ##     80        0.8600             nan     0.1000    0.0004
    ##    100        0.8387             nan     0.1000    0.0007
    ##    120        0.8206             nan     0.1000    0.0005
    ##    140        0.8054             nan     0.1000    0.0005
    ##    150        0.8007             nan     0.1000    0.0002
    ## 
    ## - Fold4: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold4: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3107             nan     0.1000    0.0222
    ##      2        1.2708             nan     0.1000    0.0197
    ##      3        1.2384             nan     0.1000    0.0162
    ##      4        1.2074             nan     0.1000    0.0152
    ##      5        1.1824             nan     0.1000    0.0120
    ##      6        1.1583             nan     0.1000    0.0120
    ##      7        1.1375             nan     0.1000    0.0100
    ##      8        1.1186             nan     0.1000    0.0097
    ##      9        1.1006             nan     0.1000    0.0091
    ##     10        1.0851             nan     0.1000    0.0074
    ##     20        0.9791             nan     0.1000    0.0039
    ##     40        0.8878             nan     0.1000    0.0016
    ##     60        0.8429             nan     0.1000    0.0010
    ##     80        0.8159             nan     0.1000    0.0003
    ##    100        0.7947             nan     0.1000    0.0005
    ##    120        0.7784             nan     0.1000    0.0002
    ##    140        0.7661             nan     0.1000    0.0001
    ##    150        0.7614             nan     0.1000    0.0001
    ## 
    ## - Fold4: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold5: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3305             nan     0.1000    0.0126
    ##      2        1.3079             nan     0.1000    0.0110
    ##      3        1.2896             nan     0.1000    0.0091
    ##      4        1.2724             nan     0.1000    0.0082
    ##      5        1.2568             nan     0.1000    0.0076
    ##      6        1.2421             nan     0.1000    0.0073
    ##      7        1.2287             nan     0.1000    0.0064
    ##      8        1.2172             nan     0.1000    0.0056
    ##      9        1.2064             nan     0.1000    0.0053
    ##     10        1.1979             nan     0.1000    0.0042
    ##     20        1.1231             nan     0.1000    0.0027
    ##     40        1.0373             nan     0.1000    0.0015
    ##     60        0.9817             nan     0.1000    0.0009
    ##     80        0.9491             nan     0.1000    0.0009
    ##    100        0.9234             nan     0.1000    0.0006
    ##    120        0.9033             nan     0.1000    0.0002
    ##    140        0.8871             nan     0.1000    0.0002
    ##    150        0.8786             nan     0.1000    0.0004
    ## 
    ## - Fold5: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold5: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3206             nan     0.1000    0.0181
    ##      2        1.2903             nan     0.1000    0.0146
    ##      3        1.2628             nan     0.1000    0.0139
    ##      4        1.2369             nan     0.1000    0.0128
    ##      5        1.2135             nan     0.1000    0.0114
    ##      6        1.1935             nan     0.1000    0.0103
    ##      7        1.1759             nan     0.1000    0.0086
    ##      8        1.1583             nan     0.1000    0.0088
    ##      9        1.1423             nan     0.1000    0.0079
    ##     10        1.1282             nan     0.1000    0.0071
    ##     20        1.0288             nan     0.1000    0.0038
    ##     40        0.9396             nan     0.1000    0.0014
    ##     60        0.8957             nan     0.1000    0.0004
    ##     80        0.8634             nan     0.1000    0.0007
    ##    100        0.8398             nan     0.1000    0.0003
    ##    120        0.8221             nan     0.1000    0.0005
    ##    140        0.8079             nan     0.1000    0.0001
    ##    150        0.8019             nan     0.1000    0.0000
    ## 
    ## - Fold5: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold5: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3113             nan     0.1000    0.0223
    ##      2        1.2715             nan     0.1000    0.0197
    ##      3        1.2392             nan     0.1000    0.0163
    ##      4        1.2091             nan     0.1000    0.0148
    ##      5        1.1819             nan     0.1000    0.0132
    ##      6        1.1586             nan     0.1000    0.0111
    ##      7        1.1366             nan     0.1000    0.0106
    ##      8        1.1169             nan     0.1000    0.0095
    ##      9        1.1003             nan     0.1000    0.0082
    ##     10        1.0854             nan     0.1000    0.0069
    ##     20        0.9809             nan     0.1000    0.0038
    ##     40        0.8917             nan     0.1000    0.0013
    ##     60        0.8453             nan     0.1000    0.0007
    ##     80        0.8158             nan     0.1000    0.0008
    ##    100        0.7964             nan     0.1000    0.0003
    ##    120        0.7810             nan     0.1000    0.0004
    ##    140        0.7681             nan     0.1000    0.0000
    ##    150        0.7625             nan     0.1000    0.0002
    ## 
    ## - Fold5: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Aggregating results
    ## Selecting tuning parameters
    ## Fitting n.trees = 150, interaction.depth = 3, shrinkage = 0.1, n.minobsinnode = 10 on full training set
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3117             nan     0.1000    0.0224
    ##      2        1.2716             nan     0.1000    0.0196
    ##      3        1.2387             nan     0.1000    0.0163
    ##      4        1.2090             nan     0.1000    0.0144
    ##      5        1.1821             nan     0.1000    0.0135
    ##      6        1.1593             nan     0.1000    0.0111
    ##      7        1.1401             nan     0.1000    0.0095
    ##      8        1.1209             nan     0.1000    0.0095
    ##      9        1.1029             nan     0.1000    0.0087
    ##     10        1.0871             nan     0.1000    0.0079
    ##     20        0.9840             nan     0.1000    0.0038
    ##     40        0.8943             nan     0.1000    0.0017
    ##     60        0.8502             nan     0.1000    0.0007
    ##     80        0.8206             nan     0.1000    0.0007
    ##    100        0.8005             nan     0.1000    0.0003
    ##    120        0.7843             nan     0.1000    0.0002
    ##    140        0.7717             nan     0.1000    0.0002
    ##    150        0.7659             nan     0.1000    0.0000

    ## Confusion Matrix and Statistics
    ## 
    ##           Reference
    ## Prediction   no  yes
    ##        no  1742  546
    ##        yes  298 2414
    ##                                           
    ##                Accuracy : 0.8312          
    ##                  95% CI : (0.8205, 0.8415)
    ##     No Information Rate : 0.592           
    ##     P-Value [Acc > NIR] : < 2.2e-16       
    ##                                           
    ##                   Kappa : 0.657           
    ##  Mcnemar's Test P-Value : < 2.2e-16       
    ##                                           
    ##             Sensitivity : 0.8155          
    ##             Specificity : 0.8539          
    ##          Pos Pred Value : 0.8901          
    ##          Neg Pred Value : 0.7614          
    ##              Prevalence : 0.5920          
    ##          Detection Rate : 0.4828          
    ##    Detection Prevalence : 0.5424          
    ##       Balanced Accuracy : 0.8347          
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

![](../images/Identifying-Opioid-Prescribers/unnamed-chunk-19-1.png)

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

![](../images/Identifying-Opioid-Prescribers/unnamed-chunk-20-1.png)

As you can see, it's a serious problem. Maybe we as data scientists have the tools to make a difference.
