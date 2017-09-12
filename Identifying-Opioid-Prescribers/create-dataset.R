
library(tidyr)
library(magrittr)
library(data.table)
library(dplyr)
t0 <- proc.time()
row.number.limit <- 25000
num_drugs <- 250 # maximum number of prescription drugs to randomly select from the total pool, will be truncated if too large


NROWS = -1 # negative number will use all rows in the original data
# Read data files
prescriber.info <- data.frame(fread("PartD_Prescriber_PUF_NPI_Drug_14.txt",header=TRUE,sep="\t",nrows=NROWS)) # contains information for each drug and prescription writer
meta <- data.frame(fread("PartD_Prescriber_PUF_NPI_14.txt",header=TRUE,sep="\t")) # contains details about prescription writer

# I'll choose the most common drugs. This is biased, but with so many features I want to capture some meaningful information without the dataset being enormous
drug_names <- prescriber.info %>%
  group_by(DRUG_NAME) %>%
  summarise(occurences = n()) %>%
  arrange(desc(occurences))
tot_num_drugs <- length(drug_names$DRUG_NAME)

# Select a sample of the total drugs
num_drugs <- ifelse(tot_num_drugs <= num_drugs,tot_num_drugs,num_drugs)
#drugs <- as.character(drug_names[sample(tot_num_drugs,num_drugs)])
drugs <- as.character(drug_names$DRUG_NAME[1:num_drugs])

print(paste("Total Number of Drugs:",num_drugs))

# Replace any hypenated or compound drug names with periods
drugs <- sort(gsub("\ |-",".",drugs))
prescriber.info$DRUG_NAME <- gsub("\ |-",".",prescriber.info$DRUG_NAME)

# Only consider entries that prescribed at least one of the drugs
prescriber.info %<>% filter(DRUG_NAME %in% drugs)
prescriber.info <- data.frame(prescriber.info)

# Combine the prescriptions for drugs that are repeated (multiple entries for the same drug for the same prescriber)
prescriber.info <- prescriber.info %>%
  group_by(NPI,NPPES_PROVIDER_LAST_ORG_NAME,NPPES_PROVIDER_FIRST_NAME,DRUG_NAME) %>%
  mutate(TOTAL_CLAIM_COUNT=sum(TOTAL_CLAIM_COUNT,na.rm=TRUE)) %>%
  filter(!duplicated(DRUG_NAME)) %>%
  ungroup()

# Convert from long to wide format and collapse the rows to one row per prescriber with the number of prescriptions written for each drug
prescriber.info <- prescriber.info %>% 
  select(NPI,DRUG_NAME, TOTAL_CLAIM_COUNT) %>%
  spread(key=DRUG_NAME, value=TOTAL_CLAIM_COUNT,fill=0) %>%
  select(NPI, one_of(drugs))

head(prescriber.info %>% arrange(NPI),n=10)

# Merge with metadata about the prescriber

prescriber.info <- prescriber.info %>% 
  merge(meta, by="NPI") %>%
  mutate(Opioid.Prescriber=ifelse( (OPIOID_BENE_COUNT<10 | is.na(OPIOID_BENE_COUNT)) & (OPIOID_CLAIM_COUNT<10 | is.na(OPIOID_CLAIM_COUNT)) ,0,1)) %>%
  select(NPI, Gender=NPPES_PROVIDER_GENDER, State=NPPES_PROVIDER_STATE, Credentials=NPPES_CREDENTIALS, Specialty=SPECIALTY_DESCRIPTION, one_of(drugs), Opioid.Prescriber) %>%
  slice(sample(nrow(prescriber.info),row.number.limit))

# head(prescriber.info %>% arrange(NPI),n=10)
write.csv(prescriber.info,'prescriber-info.csv',row.names=FALSE)
print(sprintf("Finished in %f seconds",(proc.time()-t0)[3]))

# Create data containing overdoses and state populations
od <- read.csv("drug_poisoning_deaths_by_state-_us_2013_2014-v7.csv")
state.abbrevs <- data.frame(htmltab("http://www.infoplease.com/ipa/A0110468.html",which=2))
od <- od %>%
  select(Postal.Code=State,Deaths=X2014Number) %>%
  merge(state.abbrevs,by="Postal.Code") %>%
  select(State,Deaths)
pops <- htmltab("http://www.enchantedlearning.com/usa/states/population.shtml")
names(pops) <-c("State","Rank","Population")
od %<>%
  merge(pops, by="State") %>%
  select(State,Population,Deaths)
write.csv(od,"overdoses.csv",row.names=FALSE)
