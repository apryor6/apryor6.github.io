---
layout: dark-post
title: R-Markdown Sample Project
description: "A test post"
tags: [sample post]
---
The Opioid Epidemic
===================

Fatal drug overdoses account for a significant portion of accidental deaths in adolescents and young adults in the United States. The majority of fatal drug overdoses involve [opioids](https://www.drugabuse.gov/publications/research-reports/prescription-drugs/opioids/what-are-opioids), a class of inhibitor molecules that disrupt transmission of pain signals through the nervous system. Medically, they are used as powerful pain relievers; however, they also produce feelings of euphoria. This makes them highly addictive and prone to abuse. The same mechanism that suppresses pain also suppresses respiration, which can lead to death in the case of an overdose.

Over the past 15 years, deaths from prescription opiates have [quadrupled](https://www.cdc.gov/drugoverdose/epidemic/#), but so has the amount of opiates prescribed. This massive increase in prescription rates has occurred while the levels of pain experienced by Americans has [remain largely unchanged](http://time.com/3663907/treating-pain-opioids-painkillers/). Intuitively it follows that unneccessary prescriptions potentially play a significant role in the increase in opioid overdoses. An effective strategy for identifying instances of overprescribing is therefore a potentially life saving endeavor.

To that end, the goal of this experiment is to demonstrate the possibility that predictive analytics with machine learning can be used to predict the likelihood that a given doctor is a significant prescriber of opiates. I'll do some cleaning of the data, and build a predictive model using a gradient boosted classification tree ensemble with `gbm` and `caret` that predicts with &gt;80% accuracy that an arbitrary entry is a significant prescriber of opioids. I'll also do some analysis and visualization of my results combined with those pulled from other sources.

*Disclaimer* I am absolutely not suggesting that doctors who prescribe opiates are culpable for overdoses. These are drugs with true medical value when used appropriately. The idea is rather that a systematic way for identifying sources may reveal trends in particular practices, fields, or regions of the country that could be used effectively to combat the problem.

Data Cleaning
-------------

Load the relevant libraries and read the data

~~~ r
setwd('/home/aj/kaggle/Identifying-Opioid-Prescribers')
# setwd('/Users/ajpryor/kaggle/Identifying-Opioid-Prescribers')
library(dplyr)
library(magrittr)
library(ggplot2)
library(maps)
library(data.table)
library(lme4)
library(caret)

limit.rows <- 1000
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
char_cols <- c("NPI",names(df)[lapply(df,class) == "character"])
for (i in char_cols) df[[i]] <- as.factor(df[[i]])
~~~

Now let's clean up the factor variables

~~~ r
str(df[,1:5])
~~~

    ## 'data.frame':    1000 obs. of  5 variables:
    ##  $ NPI        : Factor w/ 1000 levels "1003009630","1003249343",..: 731 249 421 673 684 542 428 403 25 820 ...
    ##  $ Gender     : Factor w/ 2 levels "F","M": 2 1 1 2 2 2 2 1 2 1 ...
    ##  $ State      : Factor w/ 53 levels "AE","AK","AL",..: 46 3 36 5 35 40 32 40 46 51 ...
    ##  $ Credentials: Factor w/ 94 levels "","ACNP","ANP",..: 19 50 54 50 54 34 50 92 78 50 ...
    ##  $ Specialty  : Factor w/ 64 levels "Allergy/Immunology",..: 11 20 19 28 24 20 17 36 39 28 ...

Looks like the id's are unique and two genders is expected, but there's a few too many states and way too many credentials.

~~~ r
df %>%
  group_by(State) %>%
  dplyr::summarise(state.counts = n()) %>%
  arrange(state.counts)
~~~

    ## # A tibble: 53 × 2
    ##     State state.counts
    ##    <fctr>        <int>
    ## 1      AE            1
    ## 2      MT            1
    ## 3      SD            1
    ## 4      AK            2
    ## 5      DE            3
    ## 6      RI            3
    ## 7      VT            3
    ## 8      DC            4
    ## 9      ND            4
    ## 10     WY            4
    ## # ... with 43 more rows

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
## This bit of code can't be run on Kaggle, but you can run it locally. 

# library(htmltab)
# state.abbrevs <- data.frame(htmltab("http://www.infoplease.com/ipa/A0110468.html",which=2))
# state.abbrevs <- state.abbrevs$Postal.Code
# if (all(levels(df$State)[levels(df$State)!="other"] %in% state.abbrevs)){print("All abbreviations are valid")} else{print("Uh oh..")}
~~~

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

    ##          Credentials credential.counts
    ## 1               ACNP                 1
    ## 2               APNP                 1
    ## 3           APRN, BC                 1
    ## 4        APRN BC FNP                 1
    ## 5          APRN, CNS                 1
    ## 6           A.R.N.P.                 1
    ## 7          BDS,  DDS                 1
    ## 8                CNM                 1
    ## 9              C.N.P                 1
    ## 10               CNS                 1
    ## 11    D.D.S., A.P.C.                 1
    ## 12  D.D.S., F.A.G.D.                 1
    ## 13       D.D.S, M.D.                 1
    ## 14      D.D.S., M.D.                 1
    ## 15           DDS, MD                 1
    ## 16            DDS MS                 1
    ## 17          DMD,FAGD                 1
    ## 18     DMD, MD, PLLC                 1
    ## 19 DNP, APRN-BC, FNP                 1
    ## 20               D O                 1
    ## 21               D.O                 1
    ## 22    D.O., MPH & TM                 1
    ## 23            DPM MD                 1
    ## 24               DPT                 1
    ## 25            F.N.P.                 1

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
    ## 7                                           Obstetrics/Gynecology
    ## 8                                                       Optometry
    ## 9                                                      Cardiology
    ## 10                                                General Surgery
    ## 11                                                  Ophthalmology
    ## 12                                                     Psychiatry
    ## 13                                                       Podiatry
    ## 14                                             Orthopedic Surgery
    ## 15 Student in an Organized Health Care Education/Training Program
    ## 16                                               Gastroenterology
    ## 17                                                 Otolaryngology
    ## 18                                                        Urology
    ## 19                                         Psychiatry & Neurology
    ## 20                                                    Dermatology
    ## 21                                                     Nephrology
    ## 22                                               General Practice
    ## 23                                            Hematology/Oncology
    ## 24                                                      Neurology
    ## 25                                              Pulmonary Disease
    ##    specialty.counts
    ## 1               145
    ## 2               131
    ## 3               101
    ## 4                90
    ## 5                66
    ## 6                34
    ## 7                31
    ## 8                27
    ## 9                25
    ## 10               25
    ## 11               23
    ## 12               23
    ## 13               21
    ## 14               17
    ## 15               16
    ## 16               14
    ## 17               14
    ## 18               14
    ## 19               13
    ## 20               12
    ## 21               12
    ## 22               11
    ## 23               11
    ## 24               10
    ## 25                9

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

    ##             Specialty specialty.counts
    ## 1               other              394
    ## 2   Internal Medicine              145
    ## 3     Family Practice              131
    ## 4             Dentist              101
    ## 5  Nurse Practitioner               90
    ## 6             Surgeon               70
    ## 7 Physician Assistant               66
    ## 8     Pain.Management                3

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
    ##      1        1.3279            -nan     0.1000    0.0158
    ##      2        1.2991            -nan     0.1000    0.0140
    ##      3        1.2749            -nan     0.1000    0.0124
    ##      4        1.2521            -nan     0.1000    0.0106
    ##      5        1.2321            -nan     0.1000    0.0101
    ##      6        1.2143            -nan     0.1000    0.0090
    ##      7        1.1987            -nan     0.1000    0.0066
    ##      8        1.1845            -nan     0.1000    0.0062
    ##      9        1.1696            -nan     0.1000    0.0043
    ##     10        1.1566            -nan     0.1000    0.0069
    ##     20        1.0604            -nan     0.1000    0.0027
    ##     40        0.9490            -nan     0.1000    0.0011
    ##     60        0.8886            -nan     0.1000    0.0006
    ##     80        0.8494            -nan     0.1000    0.0005
    ##    100        0.8171            -nan     0.1000   -0.0006
    ##    120        0.7878            -nan     0.1000    0.0000
    ##    140        0.7704            -nan     0.1000   -0.0011
    ##    150        0.7628            -nan     0.1000   -0.0007
    ## 
    ## - Fold1: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold1: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3080            -nan     0.1000    0.0224
    ##      2        1.2710            -nan     0.1000    0.0172
    ##      3        1.2399            -nan     0.1000    0.0131
    ##      4        1.2077            -nan     0.1000    0.0153
    ##      5        1.1788            -nan     0.1000    0.0127
    ##      6        1.1537            -nan     0.1000    0.0104
    ##      7        1.1301            -nan     0.1000    0.0074
    ##      8        1.1071            -nan     0.1000    0.0101
    ##      9        1.0855            -nan     0.1000    0.0074
    ##     10        1.0667            -nan     0.1000    0.0068
    ##     20        0.9450            -nan     0.1000    0.0029
    ##     40        0.8405            -nan     0.1000   -0.0004
    ##     60        0.7800            -nan     0.1000   -0.0018
    ##     80        0.7432            -nan     0.1000   -0.0003
    ##    100        0.7112            -nan     0.1000   -0.0015
    ##    120        0.6813            -nan     0.1000   -0.0004
    ##    140        0.6552            -nan     0.1000   -0.0022
    ##    150        0.6451            -nan     0.1000   -0.0018
    ## 
    ## - Fold1: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold1: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3021            -nan     0.1000    0.0288
    ##      2        1.2549            -nan     0.1000    0.0245
    ##      3        1.2105            -nan     0.1000    0.0206
    ##      4        1.1705            -nan     0.1000    0.0176
    ##      5        1.1353            -nan     0.1000    0.0159
    ##      6        1.1007            -nan     0.1000    0.0134
    ##      7        1.0732            -nan     0.1000    0.0090
    ##      8        1.0455            -nan     0.1000    0.0111
    ##      9        1.0248            -nan     0.1000    0.0072
    ##     10        1.0059            -nan     0.1000    0.0084
    ##     20        0.8809            -nan     0.1000    0.0043
    ##     40        0.7737            -nan     0.1000   -0.0007
    ##     60        0.7084            -nan     0.1000    0.0008
    ##     80        0.6672            -nan     0.1000   -0.0001
    ##    100        0.6242            -nan     0.1000   -0.0007
    ##    120        0.5916            -nan     0.1000   -0.0018
    ##    140        0.5652            -nan     0.1000   -0.0008
    ##    150        0.5517            -nan     0.1000   -0.0005
    ## 
    ## - Fold1: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold2: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3228            -nan     0.1000    0.0179
    ##      2        1.2899            -nan     0.1000    0.0173
    ##      3        1.2616            -nan     0.1000    0.0129
    ##      4        1.2365            -nan     0.1000    0.0104
    ##      5        1.2171            -nan     0.1000    0.0086
    ##      6        1.2006            -nan     0.1000    0.0075
    ##      7        1.1842            -nan     0.1000    0.0057
    ##      8        1.1679            -nan     0.1000    0.0067
    ##      9        1.1534            -nan     0.1000    0.0056
    ##     10        1.1398            -nan     0.1000    0.0060
    ##     20        1.0488            -nan     0.1000    0.0030
    ##     40        0.9497            -nan     0.1000    0.0001
    ##     60        0.8954            -nan     0.1000    0.0005
    ##     80        0.8486            -nan     0.1000   -0.0005
    ##    100        0.8154            -nan     0.1000    0.0000
    ##    120        0.7912            -nan     0.1000   -0.0002
    ##    140        0.7719            -nan     0.1000    0.0006
    ##    150        0.7600            -nan     0.1000   -0.0011
    ## 
    ## - Fold2: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold2: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3060            -nan     0.1000    0.0234
    ##      2        1.2673            -nan     0.1000    0.0168
    ##      3        1.2334            -nan     0.1000    0.0156
    ##      4        1.2014            -nan     0.1000    0.0138
    ##      5        1.1696            -nan     0.1000    0.0140
    ##      6        1.1413            -nan     0.1000    0.0109
    ##      7        1.1163            -nan     0.1000    0.0101
    ##      8        1.0925            -nan     0.1000    0.0085
    ##      9        1.0734            -nan     0.1000    0.0084
    ##     10        1.0558            -nan     0.1000    0.0063
    ##     20        0.9347            -nan     0.1000    0.0024
    ##     40        0.8369            -nan     0.1000    0.0004
    ##     60        0.7789            -nan     0.1000   -0.0015
    ##     80        0.7345            -nan     0.1000   -0.0004
    ##    100        0.7020            -nan     0.1000   -0.0014
    ##    120        0.6728            -nan     0.1000   -0.0001
    ##    140        0.6472            -nan     0.1000   -0.0013
    ##    150        0.6330            -nan     0.1000   -0.0004
    ## 
    ## - Fold2: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold2: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3046            -nan     0.1000    0.0271
    ##      2        1.2516            -nan     0.1000    0.0236
    ##      3        1.2054            -nan     0.1000    0.0214
    ##      4        1.1675            -nan     0.1000    0.0177
    ##      5        1.1342            -nan     0.1000    0.0154
    ##      6        1.1053            -nan     0.1000    0.0129
    ##      7        1.0759            -nan     0.1000    0.0120
    ##      8        1.0519            -nan     0.1000    0.0104
    ##      9        1.0306            -nan     0.1000    0.0076
    ##     10        1.0101            -nan     0.1000    0.0087
    ##     20        0.8754            -nan     0.1000    0.0023
    ##     40        0.7669            -nan     0.1000    0.0001
    ##     60        0.7063            -nan     0.1000    0.0004
    ##     80        0.6541            -nan     0.1000    0.0006
    ##    100        0.6143            -nan     0.1000   -0.0000
    ##    120        0.5829            -nan     0.1000   -0.0012
    ##    140        0.5533            -nan     0.1000   -0.0018
    ##    150        0.5434            -nan     0.1000   -0.0006
    ## 
    ## - Fold2: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold3: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3207            -nan     0.1000    0.0152
    ##      2        1.2943            -nan     0.1000    0.0115
    ##      3        1.2711            -nan     0.1000    0.0089
    ##      4        1.2497            -nan     0.1000    0.0100
    ##      5        1.2312            -nan     0.1000    0.0083
    ##      6        1.2158            -nan     0.1000    0.0065
    ##      7        1.1999            -nan     0.1000    0.0066
    ##      8        1.1839            -nan     0.1000    0.0068
    ##      9        1.1713            -nan     0.1000    0.0033
    ##     10        1.1585            -nan     0.1000    0.0053
    ##     20        1.0622            -nan     0.1000    0.0021
    ##     40        0.9521            -nan     0.1000    0.0012
    ##     60        0.8877            -nan     0.1000    0.0001
    ##     80        0.8481            -nan     0.1000    0.0004
    ##    100        0.8181            -nan     0.1000   -0.0002
    ##    120        0.7889            -nan     0.1000   -0.0000
    ##    140        0.7688            -nan     0.1000    0.0002
    ##    150        0.7614            -nan     0.1000   -0.0002
    ## 
    ## - Fold3: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold3: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3152            -nan     0.1000    0.0223
    ##      2        1.2790            -nan     0.1000    0.0186
    ##      3        1.2435            -nan     0.1000    0.0174
    ##      4        1.2106            -nan     0.1000    0.0136
    ##      5        1.1832            -nan     0.1000    0.0111
    ##      6        1.1586            -nan     0.1000    0.0121
    ##      7        1.1353            -nan     0.1000    0.0098
    ##      8        1.1142            -nan     0.1000    0.0082
    ##      9        1.0944            -nan     0.1000    0.0065
    ##     10        1.0774            -nan     0.1000    0.0065
    ##     20        0.9511            -nan     0.1000    0.0033
    ##     40        0.8357            -nan     0.1000    0.0004
    ##     60        0.7791            -nan     0.1000    0.0003
    ##     80        0.7347            -nan     0.1000   -0.0016
    ##    100        0.6987            -nan     0.1000    0.0002
    ##    120        0.6730            -nan     0.1000   -0.0019
    ##    140        0.6500            -nan     0.1000   -0.0015
    ##    150        0.6441            -nan     0.1000   -0.0007
    ## 
    ## - Fold3: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold3: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3024            -nan     0.1000    0.0239
    ##      2        1.2540            -nan     0.1000    0.0211
    ##      3        1.2092            -nan     0.1000    0.0201
    ##      4        1.1710            -nan     0.1000    0.0182
    ##      5        1.1370            -nan     0.1000    0.0132
    ##      6        1.1086            -nan     0.1000    0.0121
    ##      7        1.0833            -nan     0.1000    0.0112
    ##      8        1.0630            -nan     0.1000    0.0073
    ##      9        1.0421            -nan     0.1000    0.0082
    ##     10        1.0210            -nan     0.1000    0.0092
    ##     20        0.8857            -nan     0.1000    0.0005
    ##     40        0.7753            -nan     0.1000    0.0009
    ##     60        0.7200            -nan     0.1000   -0.0011
    ##     80        0.6674            -nan     0.1000   -0.0005
    ##    100        0.6233            -nan     0.1000   -0.0018
    ##    120        0.5857            -nan     0.1000    0.0001
    ##    140        0.5578            -nan     0.1000   -0.0009
    ##    150        0.5469            -nan     0.1000   -0.0010
    ## 
    ## - Fold3: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold4: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3234            -nan     0.1000    0.0166
    ##      2        1.2934            -nan     0.1000    0.0139
    ##      3        1.2694            -nan     0.1000    0.0105
    ##      4        1.2473            -nan     0.1000    0.0094
    ##      5        1.2303            -nan     0.1000    0.0075
    ##      6        1.2112            -nan     0.1000    0.0079
    ##      7        1.1947            -nan     0.1000    0.0062
    ##      8        1.1812            -nan     0.1000    0.0042
    ##      9        1.1704            -nan     0.1000    0.0049
    ##     10        1.1577            -nan     0.1000    0.0040
    ##     20        1.0634            -nan     0.1000    0.0041
    ##     40        0.9674            -nan     0.1000   -0.0005
    ##     60        0.9108            -nan     0.1000    0.0014
    ##     80        0.8705            -nan     0.1000   -0.0006
    ##    100        0.8406            -nan     0.1000   -0.0004
    ##    120        0.8152            -nan     0.1000   -0.0004
    ##    140        0.7959            -nan     0.1000   -0.0001
    ##    150        0.7848            -nan     0.1000   -0.0006
    ## 
    ## - Fold4: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold4: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3125            -nan     0.1000    0.0231
    ##      2        1.2694            -nan     0.1000    0.0197
    ##      3        1.2315            -nan     0.1000    0.0153
    ##      4        1.2033            -nan     0.1000    0.0116
    ##      5        1.1756            -nan     0.1000    0.0091
    ##      6        1.1523            -nan     0.1000    0.0102
    ##      7        1.1282            -nan     0.1000    0.0096
    ##      8        1.1115            -nan     0.1000    0.0068
    ##      9        1.0904            -nan     0.1000    0.0091
    ##     10        1.0722            -nan     0.1000    0.0074
    ##     20        0.9643            -nan     0.1000    0.0004
    ##     40        0.8650            -nan     0.1000    0.0003
    ##     60        0.8069            -nan     0.1000    0.0001
    ##     80        0.7667            -nan     0.1000    0.0000
    ##    100        0.7301            -nan     0.1000   -0.0006
    ##    120        0.7015            -nan     0.1000   -0.0009
    ##    140        0.6763            -nan     0.1000   -0.0010
    ##    150        0.6669            -nan     0.1000   -0.0002
    ## 
    ## - Fold4: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold4: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3037            -nan     0.1000    0.0261
    ##      2        1.2562            -nan     0.1000    0.0228
    ##      3        1.2150            -nan     0.1000    0.0186
    ##      4        1.1837            -nan     0.1000    0.0101
    ##      5        1.1498            -nan     0.1000    0.0157
    ##      6        1.1225            -nan     0.1000    0.0126
    ##      7        1.0937            -nan     0.1000    0.0108
    ##      8        1.0684            -nan     0.1000    0.0100
    ##      9        1.0469            -nan     0.1000    0.0098
    ##     10        1.0293            -nan     0.1000    0.0067
    ##     20        0.9089            -nan     0.1000    0.0031
    ##     40        0.7972            -nan     0.1000    0.0001
    ##     60        0.7297            -nan     0.1000   -0.0020
    ##     80        0.6775            -nan     0.1000   -0.0003
    ##    100        0.6394            -nan     0.1000   -0.0017
    ##    120        0.6114            -nan     0.1000   -0.0005
    ##    140        0.5866            -nan     0.1000   -0.0013
    ##    150        0.5731            -nan     0.1000   -0.0010
    ## 
    ## - Fold4: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## + Fold5: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3226            -nan     0.1000    0.0132
    ##      2        1.2929            -nan     0.1000    0.0138
    ##      3        1.2684            -nan     0.1000    0.0111
    ##      4        1.2459            -nan     0.1000    0.0107
    ##      5        1.2271            -nan     0.1000    0.0069
    ##      6        1.2102            -nan     0.1000    0.0069
    ##      7        1.1940            -nan     0.1000    0.0071
    ##      8        1.1813            -nan     0.1000    0.0052
    ##      9        1.1664            -nan     0.1000    0.0057
    ##     10        1.1521            -nan     0.1000    0.0044
    ##     20        1.0635            -nan     0.1000    0.0033
    ##     40        0.9620            -nan     0.1000    0.0009
    ##     60        0.9052            -nan     0.1000    0.0008
    ##     80        0.8640            -nan     0.1000    0.0002
    ##    100        0.8299            -nan     0.1000    0.0001
    ##    120        0.8020            -nan     0.1000    0.0008
    ##    140        0.7826            -nan     0.1000   -0.0016
    ##    150        0.7729            -nan     0.1000   -0.0004
    ## 
    ## - Fold5: shrinkage=0.1, interaction.depth=1, n.minobsinnode=10, n.trees=150 
    ## + Fold5: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3147            -nan     0.1000    0.0224
    ##      2        1.2767            -nan     0.1000    0.0154
    ##      3        1.2409            -nan     0.1000    0.0148
    ##      4        1.2118            -nan     0.1000    0.0123
    ##      5        1.1827            -nan     0.1000    0.0110
    ##      6        1.1561            -nan     0.1000    0.0106
    ##      7        1.1326            -nan     0.1000    0.0093
    ##      8        1.1102            -nan     0.1000    0.0069
    ##      9        1.0916            -nan     0.1000    0.0078
    ##     10        1.0716            -nan     0.1000    0.0084
    ##     20        0.9655            -nan     0.1000   -0.0007
    ##     40        0.8471            -nan     0.1000    0.0015
    ##     60        0.7881            -nan     0.1000   -0.0003
    ##     80        0.7445            -nan     0.1000    0.0002
    ##    100        0.7117            -nan     0.1000   -0.0009
    ##    120        0.6774            -nan     0.1000   -0.0007
    ##    140        0.6544            -nan     0.1000    0.0000
    ##    150        0.6434            -nan     0.1000   -0.0002
    ## 
    ## - Fold5: shrinkage=0.1, interaction.depth=2, n.minobsinnode=10, n.trees=150 
    ## + Fold5: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3081            -nan     0.1000    0.0239
    ##      2        1.2588            -nan     0.1000    0.0199
    ##      3        1.2219            -nan     0.1000    0.0156
    ##      4        1.1818            -nan     0.1000    0.0187
    ##      5        1.1521            -nan     0.1000    0.0125
    ##      6        1.1209            -nan     0.1000    0.0123
    ##      7        1.0978            -nan     0.1000    0.0086
    ##      8        1.0769            -nan     0.1000    0.0074
    ##      9        1.0551            -nan     0.1000    0.0088
    ##     10        1.0345            -nan     0.1000    0.0080
    ##     20        0.9024            -nan     0.1000    0.0010
    ##     40        0.7898            -nan     0.1000   -0.0014
    ##     60        0.7279            -nan     0.1000   -0.0010
    ##     80        0.6802            -nan     0.1000   -0.0009
    ##    100        0.6357            -nan     0.1000   -0.0014
    ##    120        0.6032            -nan     0.1000   -0.0016
    ##    140        0.5750            -nan     0.1000   -0.0008
    ##    150        0.5619            -nan     0.1000   -0.0013
    ## 
    ## - Fold5: shrinkage=0.1, interaction.depth=3, n.minobsinnode=10, n.trees=150 
    ## Aggregating results
    ## Selecting tuning parameters
    ## Fitting n.trees = 150, interaction.depth = 3, shrinkage = 0.1, n.minobsinnode = 10 on full training set
    ## Iter   TrainDeviance   ValidDeviance   StepSize   Improve
    ##      1        1.3030            -nan     0.1000    0.0244
    ##      2        1.2538            -nan     0.1000    0.0235
    ##      3        1.2165            -nan     0.1000    0.0157
    ##      4        1.1794            -nan     0.1000    0.0155
    ##      5        1.1458            -nan     0.1000    0.0152
    ##      6        1.1190            -nan     0.1000    0.0104
    ##      7        1.0954            -nan     0.1000    0.0102
    ##      8        1.0727            -nan     0.1000    0.0097
    ##      9        1.0526            -nan     0.1000    0.0082
    ##     10        1.0317            -nan     0.1000    0.0082
    ##     20        0.9002            -nan     0.1000   -0.0001
    ##     40        0.7969            -nan     0.1000   -0.0005
    ##     60        0.7349            -nan     0.1000   -0.0001
    ##     80        0.6946            -nan     0.1000   -0.0014
    ##    100        0.6589            -nan     0.1000   -0.0004
    ##    120        0.6273            -nan     0.1000   -0.0002
    ##    140        0.6026            -nan     0.1000   -0.0005
    ##    150        0.5882            -nan     0.1000   -0.0004

    ## Confusion Matrix and Statistics
    ## 
    ##           Reference
    ## Prediction no yes
    ##        no  71  22
    ##        yes 14  93
    ##                                           
    ##                Accuracy : 0.82            
    ##                  95% CI : (0.7596, 0.8706)
    ##     No Information Rate : 0.575           
    ##     P-Value [Acc > NIR] : 1.467e-13       
    ##                                           
    ##                   Kappa : 0.6362          
    ##  Mcnemar's Test P-Value : 0.2433          
    ##                                           
    ##             Sensitivity : 0.8087          
    ##             Specificity : 0.8353          
    ##          Pos Pred Value : 0.8692          
    ##          Neg Pred Value : 0.7634          
    ##              Prevalence : 0.5750          
    ##          Detection Rate : 0.4650          
    ##    Detection Prevalence : 0.5350          
    ##       Balanced Accuracy : 0.8220          
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

![](analysis_files/figure-markdown_github/unnamed-chunk-19-1.png)

Our best feature was a drug called [Gabapentin](https://www.drugs.com/gabapentin.html), which unsurprisingly is used to treat nerve pain caused by things like shingles. It's not an opiate, but likely gets prescribed at the same time. The `Surgeon` feature we engineered has done quite well. The other drugs are for various conditions including inflamatation, cancer, and athritis among others.

It probably doesn't surprise anybody that surgeons commonly prescribe pain medication, or that the people taking cancer drugs are also taking pain pills. But with a very large feature set it becomes entirely intractable for a human to make maximal use of the available information. I would expect a human analyzing this data would immediately classify candidates based upon their profession, but machine learning has enabled us to break it down further based upon the specific drug prescription trends doctor by doctor. Truly a powerful tool.

Summary/Analysis
----------------

We succeeded in building a pretty good opiate-prescription detection algorithm based primarily on their profession and prescription rates of non-opiate drugs. This could be used to combat overdoses in a number of ways. Professions who show up with high importance in the model can reveal medical fields that could benefit in the long run from curriculum shifts towards awareness of the potential dangers. Science evolves rapidly, and this sort of dynamic shift of the "state-of-the-art" opinion is quite common. It's also possible that individual drugs that are strong detectors may identify more accurately a sub-specialty of individual prescribers that could be of interest, or even reveal hidden avenues of illegitimate drug access.

As a parting way of illustrating how widespread this problem is across the country, I'll generate a map plot showing the relative number of fatal overdoses across the country.

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

![](analysis_files/figure-markdown_github/unnamed-chunk-20-1.png)

As you can see, it's a serious problem. Maybe we as data scientists have the tools to make a difference.
