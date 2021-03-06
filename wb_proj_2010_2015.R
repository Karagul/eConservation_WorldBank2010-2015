
setwd("E:/bicheor/econservation/eConservation_March2016")

###############   Set Working directory  ####################
#######################################################
setwd("~/econservation/eConservation_March2016")

###############   Needed Packages  ####################
#######################################################
library(plyr)
library(spatstat)
library(rgdal)
library(maptools)
library(sp)

################  Needed Functions  ###################
#######################################################
## Function to count how the number of NA in one variavble
count_NA <- function(x) sum(is.na(x))

## Function to count how the number of NA in each column of a data frame 
propmiss <- function(dataframe) {
  m <- sapply(dataframe, function(x) {
    data.frame(
      nmiss=sum(is.na(x)), 
      n=length(x), 
      propmiss=sum(is.na(x))/length(x) 
    )
  })
  d <- data.frame(t(m))
  d <- sapply(d, unlist)
  d <- as.data.frame(d)
  d$variable <- row.names(d)
  row.names(d) <- NULL
  d <- cbind(d[ncol(d)],d[-ncol(d)])
  return(d[order(d$propmiss), ])
}

## Function to convert capital letter text in lower case except the first letter
r_ucfirst <- function (str) {
  paste(toupper(substring(str, 1, 1)), tolower(substring(str, 2)), sep = "")
}

## Function to convert capital letter text in lower case except the first letter of each word
simpleCap <- function(x) {
  s <- strsplit(x, " ")[[1]]
  paste(toupper(substring(s, 1,1)), tolower(substring(s, 2)),
        sep="", collapse=" ")
}

## Funtion to remove leading and trailing whitespace
trim <- function (x) gsub("^\\s+|\\s+$", "", x)

## Funtion to remove all extra leading and trailing whitespace
trim_blank  <-  function (x) gsub("^([ \t\n\r\f\v]+)|([ \t\n\r\f\v]+)$", "", x)

## Funtion to remove leading and trailing punctuation
trim_punct <- function (x) gsub("([,;])$", "", x)
#######################################################
#######################################################



#######################################################
# I. Access, filter and clean the World Bank data

# I.1. Load the data from the website
wb_web <- read.csv("http://search.worldbank.org/api/projects/all.csv",  header=T, sep=",", quote = "", na.strings = NA, colClasses="character")

# I.2. Filter the data
## I.2.1. Subset only projects about Biodiversity
wb_web_biodiv <- wb_web[with(wb_web, grepl("Biodiversity",theme1)|grepl("Biodiversity", theme2)|grepl("Biodiversity", theme3)|
                               grepl("Biodiversity", theme4)|grepl("Biodiversity", theme5)|grepl("Biodiversity", theme)),]
## I.2.2. Remove projects that have been dropped or are still in the pipeline
wb_web_biodiv <- subset(wb_web_biodiv, wb_web_biodiv$status %in% c("Active", "Closed"))
## I.2.3. Convert empty fields to NA
wb_web_biodiv[wb_web_biodiv==""] <- NA
## I.2.4. Extract only the projects starting in 2010-2015
### I.2.4.1. Convert date variables to date format
wb_web_biodiv$boardapprovaldate <- gsub("T00:00:00Z", "", wb_web_biodiv$boardapprovaldate)
wb_web_biodiv$closingdate <- gsub("T00:00:00Z", "", wb_web_biodiv$closingdate)  
wb_web_biodiv$boardapprovaldate <- as.Date(wb_web_biodiv$boardapprovaldate, "%Y-%m-%d")
wb_web_biodiv$closingdate <- as.Date(wb_web_biodiv$closingdate, "%Y-%m-%d")
### I.2.4.2. Subset the projects starting in 2010-2015
# wb_web_biodiv_10_15 <- subset(wb_web_biodiv, wb_web_biodiv$project_start_date>="2010-01-01")
wb_web_biodiv_10_15 <- subset(wb_web_biodiv, wb_web_biodiv$boardapprovaldate>="2010-01-01" & wb_web_biodiv$boardapprovaldate<="2016-02-01")

# I.3. Clean the data
## I.3.1. Remove unnecessary variables
wb_web_biodiv_10_15 <- wb_web_biodiv_10_15[,-c(4:11, 14, 17:20, 24:30, 32:36, 44:50, 51,56, 57)]
## I.3.2. Aggregate the theme variables into one
wb_web_biodiv_10_15$theme <- paste(wb_web_biodiv_10_15$theme1, wb_web_biodiv_10_15$theme2, wb_web_biodiv_10_15$theme3, wb_web_biodiv_10_15$theme4, wb_web_biodiv_10_15$theme5, sep=";")
wb_web_biodiv_10_15$theme1 <- NULL
wb_web_biodiv_10_15$theme2 <- NULL 
wb_web_biodiv_10_15$theme3 <- NULL
wb_web_biodiv_10_15$theme4 <- NULL
wb_web_biodiv_10_15$theme5 <- NULL
## I.3.3. Rename variables
wb_web_biodiv_10_15 <- rename(wb_web_biodiv_10_15, replace=c("id"="id_proj_from_provider",
                                                             "project_name"="title",
                                                             "boardapprovaldate"="project_start_date",
                                                             "closingdate"="project_end_date",
                                                             "lendprojectcost"="budget",
                                                             "url"="proj_link"))
## I.3.4. Remove semicolon in the budget variable
wb_web_biodiv_10_15$budget <- as.numeric(gsub(";", "", wb_web_biodiv_10_15$budget))
## I.3.5. Clean up the project titles
wb_web_biodiv_10_15$title <- gsub("Proejct", "Project", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("%th", "Fifth", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("PIAU&#205;", "PIAUÍ", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("CO Mainstreaming Sust. Cattle Ranching Project AF", "Colombia - Additional Financing for the Mainstreaming Sustainable Cattle Ranching Project", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title[c(41,59,86,113,115,122)] <- r_ucfirst(wb_web_biodiv_10_15$title[c(41,59,86,113,115,122)])
wb_web_biodiv_10_15$title <- gsub("piauí", "Piauí", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title[122] <- gsub("mali", "Mali", wb_web_biodiv_10_15$title[122])
wb_web_biodiv_10_15$title <- gsub("Devt", "Development", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("AF", "Additional Financing", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("  ", " ", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("Svcs", "Services", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub(";", ",", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- trim_blank(wb_web_biodiv_10_15$title) # has to be done before trim_punct
wb_web_biodiv_10_15$title <- trim_punct(wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("\\|", " - ", wb_web_biodiv_10_15$title) # replace all pipes in the titles so pipes can be used as a field separator
wb_web_biodiv_10_15$title <- gsub("[\r\n]", "", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("\"", "", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("[\t]", "", wb_web_biodiv_10_15$title)
wb_web_biodiv_10_15$title <- gsub("N/A", NA, wb_web_biodiv_10_15$title)

# I.4. Add the missing variable to respect the eConservation database structure
## I.4.1. Add the update date, the provider and the user name
wb_web_biodiv_10_15$provider <- "World Bank"
wb_web_biodiv_10_15$puser <- "BdB,OB"
wb_web_biodiv_10_15$currency <- "USD"
wb_web_biodiv_10_15$update_date <- "2016-02-02"
## I.4.2. Create a unique numerical ID for the projects (starting from a number higher than the length of the current eConservation database to avoid duplicate ID)
wb_web_biodiv_10_15$id_proj_from_postgres <- seq(1000000, 1000000-1+nrow(wb_web_biodiv_10_15)) 
## I.4.3. Convert date variables to date format
wb_web_biodiv_10_15$update_date <- as.Date(wb_web_biodiv_10_15$update_date, "%Y-%m-%d")  

# I.5. Summary of missing values
## I.5.1. Summary table of missing values 
missing_wb_web_biodiv_10_15 <- propmiss(wb_web_biodiv_10_15)
## I.5.2. Evaluate the completeness of the data per project
### I.5.2.1.  Per Variable
df <- data.frame(id_proj=wb_web_biodiv_10_15$id_proj_from_provider)
df$budget <- ifelse(is.na(wb_web_biodiv_10_15$budget), 0, 1)
df$borrower <- ifelse(is.na(wb_web_biodiv_10_15$borrower), 0, 1)
df$impagency <- ifelse(is.na(wb_web_biodiv_10_15$impagency), 0, 1)
df$sector <- ifelse(is.na(wb_web_biodiv_10_15$sector), 0, 1)
df$mjsector <- ifelse(is.na(wb_web_biodiv_10_15$mjsector), 0, 1)
df$theme <- ifelse(is.na(wb_web_biodiv_10_15$theme), 0, 1)
df$species <- 0
df$title <- ifelse(is.na(wb_web_biodiv_10_15$title), 0, 1)
df$summary <- 0
df$description <- 0
df$donor <- 0
df$latitude <- ifelse(is.na(wb_web_biodiv_10_15$Latitude), 0, 1)
df$longitude <- ifelse(is.na(wb_web_biodiv_10_15$Longitude), 0, 1)
df$sitename <- ifelse(is.na(wb_web_biodiv_10_15$GeoLocName), 0, 1)
df$regionname <- ifelse(is.na(wb_web_biodiv_10_15$regionname), 0, 1)
df$countryname <- ifelse(is.na(wb_web_biodiv_10_15$countryname), 0, 1)
df$project_start_date <- ifelse(is.na(wb_web_biodiv_10_15$project_start_date), 0, 1)
df$project_end_date <- ifelse(is.na(wb_web_biodiv_10_15$project_end_date), 0, 1)
df$id_proj_from_provider <- ifelse(is.na(wb_web_biodiv_10_15$id_proj_from_provider), 0, 1)
df$proj_link <- ifelse(is.na(wb_web_biodiv_10_15$proj_link), 0, 1)
### I.5.2.2. Per needed information
df$ni_budget <- ifelse(is.na(wb_web_biodiv_10_15$budget), 0, 1)
df$ni_impl_agency <- ifelse(!is.na(wb_web_biodiv_10_15$borrower) | !is.na(wb_web_biodiv_10_15$impagency), 1, 0)
df$ni_proj_focus <- ifelse(!is.na(wb_web_biodiv_10_15$title) | !is.na(wb_web_biodiv_10_15$sector) | !is.na(wb_web_biodiv_10_15$mjsector) | !is.na(wb_web_biodiv_10_15$theme), 1, 0)
df$ni_donor <- 0
df$ni_site_coord <- ifelse(!is.na(wb_web_biodiv_10_15$Latitude) | !is.na(wb_web_biodiv_10_15$Longitude), 1, 0)
df$ni_site_info <- ifelse(!is.na(wb_web_biodiv_10_15$GeoLocName) | !is.na(wb_web_biodiv_10_15$regionname) | !is.na(wb_web_biodiv_10_15$countryname), 1, 0)
df$ni_project_dates <- ifelse(is.na(wb_web_biodiv_10_15$project_start_date), 0, 1)
df$ni_project_end_date <- ifelse(is.na(wb_web_biodiv_10_15$project_end_date), 0, 1)
df$ni_id_proj_from_provider <- ifelse(is.na(wb_web_biodiv_10_15$id_proj_from_provider), 0, 1)
df$ni_proj_link <- ifelse(is.na(wb_web_biodiv_10_15$proj_link), 0, 1)
### I.5.2.3.   Per group of information
for (i in 1:136){
  df$content[i] <- sum(df$ni_budget[i], df$ni_impl_agency[i], df$ni_proj_focus[i], df$ni_donor[i]) / 4
  df$spat_info[i] <- sum(df$ni_site_coord[i], df$ni_site_info[i]) /2
  df$aux_info[i] <- sum(df$ni_project_dates[i], df$ni_project_end_date[i], df$ni_id_proj_from_provider[i], df$ni_proj_link[i]) /4
}
## I.5.3. Evaluate the completeness of the data per variable
df$id_proj <- as.character(df$id_proj)
df["Total" ,2:34] <- colSums(df["Total",2:34])
df["Total_prop" ,2:34] <- df["Total",2:34]/136
## I.5.3. Add a variable to the projects indicating the completness of the data
wb_web_biodiv_10_15 <- merge(wb_web_biodiv_10_15, df[,c("id_proj","content","spat_info","aux_info")], by.x="id_proj_from_provider", by.y="id_proj")
wb_web_biodiv_10_15 <- rename(wb_web_biodiv_10_15, replace=c("content"="complete_content",
                                                             "spat_info"="complete_spatinfo",
                                                             "aux_info"="complete_auxinfo"))

# I.6. Complete the missing data
## I.6.2. Complete the missing dates
dates <- subset(wb_web_biodiv_10_15, select=c("id_proj_from_provider" ,"project_start_date","project_end_date"))
propmiss(dates) # Check for missing values
# Date found in various parts of the online documents on the World Bank project page. 
# When the missing dates were project end dates for additional financing for an existing project, the initial project end date was used if not clearly stated otherwise in the additional financing documentation.
# When the information could not be found, the project start date was used
dates_missing <- dates[is.na(dates$project_end_date),]
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P112106"] <- as.Date("2014-10-18", "%Y-%m-%d")   
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P116734"] <- as.Date("2013-06-30", "%Y-%m-%d")   
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P119725"] <- as.Date("2012-05-01", "%Y-%m-%d")  
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P120039"] <- as.Date(wb_web_biodiv_10_15$project_start_date[wb_web_biodiv_10_15$id_proj_from_provider=="P120039"], "%Y-%m-%d") # No date nor documentation available. The project start date was put as the end date to avoid NA
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P126542"] <- as.Date("2015-03-31", "%Y-%m-%d")  
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P128392"] <- as.Date("2021-06-30", "%Y-%m-%d")  # The date in the documents was 2021-06-31 which does not exist
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P132100"] <- as.Date("2016-02-15", "%Y-%m-%d")
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P144183"] <- as.Date("2021-01-31", "%Y-%m-%d") 
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P144902"] <- as.Date("2015-02-28", "%Y-%m-%d")  
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P145732"] <- as.Date("2017-08-23", "%Y-%m-%d")  
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P152066"] <- as.Date("2021-06-30", "%Y-%m-%d")    
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P153721"] <- as.Date("2021-09-30", "%Y-%m-%d") # But documentation under P151102
wb_web_biodiv_10_15$project_end_date[wb_web_biodiv_10_15$id_proj_from_provider=="P153958"] <- as.Date("2015-06-30", "%Y-%m-%d")  

# I.7. Save the table as csv
write.table(wb_web_biodiv_10_15, paste(getwd(), "/eConservation_WB_2010_2015/Main_tables/data_all_projects_wb_10_15.csv", sep=""),
            row.names=FALSE, sep="|", fileEncoding = "latin1", na = "")




#######################################################
# II. Create the PROJECT table

# II.1. Subset the variables needed
wb_web_biodiv_10_15_projects <- subset(wb_web_biodiv_10_15, select=c("id_proj_from_provider", "title", 
                                                                     "project_start_date","project_end_date",
                                                                     "proj_link", "budget", "currency",
                                                                     "update_date" , "puser","id_proj_from_postgres",
                                                                     "complete_content", "complete_spatinfo", "complete_auxinfo"))

# II.2. Create the variables missing from the WB data needed because they are provided by other data providers
wb_web_biodiv_10_15_projects$proj_summary <- NA
wb_web_biodiv_10_15_projects$description <- NA
wb_web_biodiv_10_15_projects$pcomments <- NA

# II.3. Link the projects to the existing project ID in the current eConservation database
codes_proj <- read.csv(paste(getwd(), "~/econservation/eConservation_2014/eConservation_database_2014_clean/Main_tables/codes_id_proj.csv", sep=""), header=T)
codes_proj <- rename(codes_proj, replace=c("id_proj_from_postgres"="id_proj_from_eCons"))
wb_web_biodiv_10_15_projects <- merge(wb_web_biodiv_10_15_projects, codes_proj, by="id_proj_from_provider", all.x=T, all.y=F)

# II.3. Save the project table
write.table(wb_web_biodiv_10_15_projects, paste(getwd(), "/eConservation_WB_2010_2015/Main_tables/wb_web_biodiv_10_15_projects.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "latin1", na = "")






#######################################################
# III. Create the IMPLEMENTING AGENCIES table

# III.1.  Clean up the implementing agencies names 
## III.1.1. A first cleaning of the names, one by one, needs to be done by hand in excel
df_impl_agency <- subset(wb_web_biodiv_10_15, select=c("id_proj_from_provider" ,"borrower","impagency"))
write.csv(df_impl_agency, paste(getwd(), "/Temp/df_impl_agency.csv", sep=""), row.names = F) # Export to excel
df_impl_agency <- read.csv(paste(getwd(), "/Temp/df_impl_agency.csv", sep=""), na.strings = NA,
                           header=T, sep=",", encoding="latin1")  # Load cleaned file from excel
wb_web_biodiv_10_15 <- merge(wb_web_biodiv_10_15, df_impl_agency, by="id_proj_from_provider", all.x=T) # Include it back to the data

# III.2. Create the implementing agencies table. 
## III.2.1. Decompose the implementing agencies name variable to have only one row per projects-implementing agency combination
df_impl_agency$impl_agency <- as.character(df_impl_agency$impl_agency)
s <- (strsplit(as.character(df_impl_agency$impl_agency), split = ";"))
wb_web_biodiv_lt_proj_agency <- data.frame(id_proj_from_provider = rep(df_impl_agency$id_proj_from_provider, sapply(s, length)), impl_agency = unlist(s)) # This is the first step to the creation of the lookup table project - implementing agency
wb_web_biodiv_lt_proj_agency$impl_agency <- trim_blank(wb_web_biodiv_lt_proj_agency$impl_agency)
## III.2.2. Extract the unique implementing agencies from the lookup table
wb_web_biodiv_implementing_agency <- data.frame(impl_agency = unique(wb_web_biodiv_lt_proj_agency$impl_agency))
## III.2.3. Complete the implementing agencies information (acronym, website, address, etc.) by hand in excel
write.csv(wb_web_biodiv_implementing_agency, paste(getwd(), "/Temp/wb_web_biodiv_implementing_agency.csv", sep=""), row.names = F)
wb_web_biodiv_implementing_agency <- read.csv(paste(getwd(), "/Temp/wb_web_biodiv_implementing_agency.csv", sep=""), na.strings = NA,
                                              header=T, sep=",", encoding="latin1")
## III.2.4. Clean the implementing agencies table
wb_web_biodiv_implementing_agency$impl_agency <- trim_blank(wb_web_biodiv_implementing_agency$impl_agency)
wb_web_biodiv_implementing_agency <- wb_web_biodiv_implementing_agency[!duplicated(wb_web_biodiv_implementing_agency),]
wb_web_biodiv_implementing_agency <- rename(wb_web_biodiv_implementing_agency, replace=c("comments"="acomments"))
wb_web_biodiv_implementing_agency$impl_agency <- gsub("\\|", " - ", wb_web_biodiv_implementing_agency$impl_agency)
wb_web_biodiv_implementing_agency$acomments <- gsub("\\|", " - ", wb_web_biodiv_implementing_agency$acomments)
wb_web_biodiv_implementing_agency$ngo_link <- gsub("\\|", " - ", wb_web_biodiv_implementing_agency$ngo_link)
wb_web_biodiv_implementing_agency$impl_agency <- gsub("[\r\n]", "", wb_web_biodiv_implementing_agency$impl_agency)
wb_web_biodiv_implementing_agency$acomments <- gsub("[\r\n]", "", wb_web_biodiv_implementing_agency$acomments)
wb_web_biodiv_implementing_agency$ngo_link <- gsub("[\r\n]", " - ", wb_web_biodiv_implementing_agency$ngo_link)
wb_web_biodiv_implementing_agency$impl_agency <- gsub("\"", "", wb_web_biodiv_implementing_agency$impl_agency)
wb_web_biodiv_implementing_agency$acomments <- gsub("\"", "", wb_web_biodiv_implementing_agency$acomments)
wb_web_biodiv_implementing_agency$ngo_link <- gsub("\"", " - ", wb_web_biodiv_implementing_agency$ngo_link)
wb_web_biodiv_implementing_agency$impl_agency <- gsub("[\t]", "", wb_web_biodiv_implementing_agency$impl_agency)
wb_web_biodiv_implementing_agency$acomments <- gsub("[\t]", "", wb_web_biodiv_implementing_agency$acomments)
wb_web_biodiv_implementing_agency$ngo_link <- gsub("[\t]", " - ", wb_web_biodiv_implementing_agency$ngo_link)
wb_web_biodiv_implementing_agency$impl_agency <- gsub("N/A", NA, wb_web_biodiv_implementing_agency$impl_agency)
wb_web_biodiv_implementing_agency$acomments <- gsub("N/A", NA, wb_web_biodiv_implementing_agency$acomments)
wb_web_biodiv_implementing_agency$ngo_link <- gsub("N/A", NA, wb_web_biodiv_implementing_agency$ngo_link)
wb_web_biodiv_implementing_agency$impl_agency <- trim_blank(wb_web_biodiv_implementing_agency$impl_agency)
## III.2.5. Create a unique numerical ID for the implementing agencies (starting from a number higher than the length of the current eConservation database to avoid duplicate ID)
wb_web_biodiv_implementing_agency$id_impl_agency <- seq(2000, 2000-1+nrow(wb_web_biodiv_implementing_agency)) 
## III.2.6. Save the implementing agencies table
write.table(wb_web_biodiv_implementing_agency, paste(getwd(),"/eConservation_WB_2010_2015/Main_tables/wb_web_biodiv_implementing_agency.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "latin1", na = "")

# III.3. Create the  lookup table project - implementing agencies. 
## III.3.1. Select only the ID variables and merge the table to the created numerical project ID
wb_web_biodiv_lt_proj_agency <- merge(wb_web_biodiv_lt_proj_agency, wb_web_biodiv_implementing_agency[,c("impl_agency","id_impl_agency")])
wb_web_biodiv_lt_proj_agency <- subset(wb_web_biodiv_lt_proj_agency, select=c(id_proj_from_provider, id_impl_agency))
wb_web_biodiv_lt_proj_agency <- merge(wb_web_biodiv_lt_proj_agency, 
                                      subset(wb_web_biodiv_10_15_projects, select=c(id_proj_from_provider, id_proj_from_postgres)), 
                                      by="id_proj_from_provider", all.x=T, all.y=F)
## III.3.2. Save the lookup table
write.table(wb_web_biodiv_lt_proj_agency, paste(getwd(),"/eConservation_WB_2010_2015/Lookup_tables/wb_web_biodiv_lt_proj_agency.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "UTF-8", na = "")




#######################################################
# IV. Create the SITES table

# IV.1. Clean up of sites
wb_web_biodiv_sites <- subset(wb_web_biodiv_10_15, select=c("id_proj_from_provider", "id_proj_from_postgres","Latitude","Longitude"))
## IV.1.1. Sites without coordinates: The georeferencing was undertaken following the procedure described by Bowy. It was done in excel:
sites_missing <- wb_web_biodiv_sites[is.na(wb_web_biodiv_sites$Latitude),] # Subset the projects without associated sites coordinates
write.csv(sites_missing, paste(getwd(), "/Temp/sites_missing.csv", sep=""), row.names = F) # Export to excel
lt_proj_sites_missing_wb <- read.csv(paste(getwd(), "/Temp/sites_missing.csv", sep=""), 
                                     na.strings = NA, header=T, sep=",", dec=".", encoding="latin1") # Load back the cleaned file
lt_proj_sites_missing_wb$site_name <- trim_blank(lt_proj_sites_missing_wb$site_name)
lt_proj_sites_missing_wb$geonames <- trim_blank(lt_proj_sites_missing_wb$geonames)
## IV.1.2. Sites without coordinates: Decompose the coordinates variables (Latitude and Longitude) to have only one row per projects-site combination
### The information about the sites, other that the coordinates, will need to be handled by hand
### IV.1.2.1. Decompose coordinates variables 
sites_non_missing <- subset(wb_web_biodiv_sites, !wb_web_biodiv_sites$id_proj_from_provider %in% sites_missing$id_proj_from_provider) # remove the projects without associated sites coordinates
s3 <- (strsplit(as.character(sites_non_missing$Latitude), split = ";"))
s4 <- (strsplit(as.character(sites_non_missing$Longitude), split = ";"))
wb_web_biodiv_lt_proj_sites_coord <- data.frame(id_proj_from_provider = rep(sites_non_missing$id_proj_from_provider, sapply(s3, length)),
                                                latitude = unlist(s3),
                                                longitude = unlist(s4))
wb_web_biodiv_lt_proj_sites_coord <- wb_web_biodiv_lt_proj_sites_coord[!duplicated(wb_web_biodiv_lt_proj_sites_coord),]
wb_web_biodiv_lt_proj_sites_coord$latitude <- as.numeric(as.character(wb_web_biodiv_lt_proj_sites_coord$latitude))
wb_web_biodiv_lt_proj_sites_coord$longitude <- as.numeric(as.character(wb_web_biodiv_lt_proj_sites_coord$longitude))
### IV.1.2.2. Remove sites with coordinate error
wb_web_biodiv_lt_proj_sites_coord <- subset(wb_web_biodiv_lt_proj_sites_coord, wb_web_biodiv_lt_proj_sites_coord$latitude < 90)
wb_web_biodiv_lt_proj_sites_coord <- subset(wb_web_biodiv_lt_proj_sites_coord, wb_web_biodiv_lt_proj_sites_coord$latitude > -90)
wb_web_biodiv_lt_proj_sites_coord <- subset(wb_web_biodiv_lt_proj_sites_coord, wb_web_biodiv_lt_proj_sites_coord$longitude < 180)
wb_web_biodiv_lt_proj_sites_coord <- subset(wb_web_biodiv_lt_proj_sites_coord, wb_web_biodiv_lt_proj_sites_coord$longitude > -180)
## Add a precision code of "2" to sites for which coordinates were provided by the World Bank
wb_web_biodiv_lt_proj_sites_coord$precision_id <- 2
### IV.1.3. Combine the table projects-sites extracted from the web database to the table projects-sites georeferenced by hand 
wb_web_biodiv_lt_proj_sites <- rbind.fill(wb_web_biodiv_lt_proj_sites_coord, lt_proj_sites_missing_wb)
wb_web_biodiv_lt_proj_sites <- wb_web_biodiv_lt_proj_sites[!duplicated(wb_web_biodiv_lt_proj_sites),]

# IV.2. Create the SITES table
## IV.2.1. Extract the unique sites from the lookup table
wb_web_biodiv_sites <- subset(wb_web_biodiv_lt_proj_sites, select=-id_proj_from_provider)
wb_web_biodiv_sites <- wb_web_biodiv_sites[!duplicated(wb_web_biodiv_sites),]
wb_web_biodiv_sites <- wb_web_biodiv_sites[order(wb_web_biodiv_sites$precision_id, decreasing=TRUE),]
wb_web_biodiv_sites_wNA <- wb_web_biodiv_sites[is.na(wb_web_biodiv_sites$latitude),]
wb_web_biodiv_sites_woNA <- wb_web_biodiv_sites[!is.na(wb_web_biodiv_sites$latitude),]
wb_web_biodiv_sites_woNA <- wb_web_biodiv_sites_woNA[!duplicated(wb_web_biodiv_sites_woNA[,c('latitude', 'longitude')]),]
wb_web_biodiv_sites <- rbind(wb_web_biodiv_sites_woNA, wb_web_biodiv_sites_wNA)
## IV.2.2. Create a unique numerical ID for the sites (starting from a number higher than the length of the current eConservation database to avoid duplicate ID)
wb_web_biodiv_sites$id_site_from_postgres <- seq(200000, 200000-1+nrow(wb_web_biodiv_sites)) 
## IV.2.3. Save the SITES table
write.table(wb_web_biodiv_sites, paste(getwd(),"/eConservation_WB_2010_2015/Main_tables/wb_web_biodiv_sites.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "latin1", na = "")

# IV.3. Associate sites with countries and with WDPA, when applicable
## IV.3.1. Refer to code GetSiteWDPA.R
## IV.3.2. Clean the new SITES table 
wb_web_biodiv_sites_POINTS <- readShapePoints(paste(getwd(),"/eConservation_GIS/WB_2010_2015_sites/wb_web_biodiv_sites_POINTS_MinDistWDPA.shp", sep=""))
wb_web_biodiv_sites <- wb_web_biodiv_sites_POINTS@data
wb_web_biodiv_sites <- rename(wb_web_biodiv_sites, replace=c("precision_"="precision_id", "wdpa_id"="inter_wdpaPOLY",
                                                             "link_to_si"="link_to_site", "id_site_fr"="id_site_from_postgres"))
wb_web_biodiv_sites$coords_x1.1 <- NULL
wb_web_biodiv_sites$coords_x2.1 <- NULL
## IV.3.3. Save the new SITES table
write.table(wb_web_biodiv_sites, paste(getwd(),"/eConservation_WB_2010_2015/Main_tables/wb_web_biodiv_sites.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "latin1", na = "")

# IV.4. Create the lookup table projects - sites
## IV.4.1. Complete the table projects-sites with the new sites id 
wb_web_biodiv_lt_proj_sites <- wb_web_biodiv_lt_proj_sites[,1:3]
wb_web_biodiv_lt_proj_sites <- merge(wb_web_biodiv_lt_proj_sites, 
                                     subset(wb_web_biodiv_sites, select=c(latitude, longitude, id_site_from_postgres)), 
                                     by=c("latitude","longitude"), all.x=T, all.y=F)
wb_web_biodiv_lt_proj_sites <- wb_web_biodiv_lt_proj_sites[!is.na(wb_web_biodiv_lt_proj_sites$id_site_from_postgres),]
## IV.4.2. Select only the ID variables and merge the table to the created numerical project ID
wb_web_biodiv_lt_proj_sites <- subset(wb_web_biodiv_lt_proj_sites, select=c("id_proj_from_provider", "id_site_from_postgres"))
wb_web_biodiv_lt_proj_sites <- wb_web_biodiv_lt_proj_sites[!duplicated(wb_web_biodiv_lt_proj_sites),]
codes_wb_sites <- subset(wb_web_biodiv_10_15, select=c("id_proj_from_provider", "id_proj_from_postgres"))
wb_web_biodiv_lt_proj_sites <- merge(wb_web_biodiv_lt_proj_sites, codes_wb_sites, by="id_proj_from_provider", all.x=T, all.y=F)
## IV.4.3. Save the projects-sites lookup table
write.table(wb_web_biodiv_lt_proj_sites, paste(getwd(),"/eConservation_WB_2010_2015/Lookup_tables/wb_web_biodiv_lt_proj_sites.csv", sep=""), row.names=FALSE, sep="|", fileEncoding = "UTF-8", na = "")


# IV.5. Create the site-WDPA lookup table 
wb_web_biodiv_lt_sites_wdpa <- subset(wb_web_biodiv_sites, select=c(id_site_from_postgres, WDPAID))
s5 <- (strsplit(as.character(wb_web_biodiv_lt_sites_wdpa$WDPAID), split = ","))
wb_web_biodiv_lt_sites_wdpa <- data.frame(id_site_from_postgres = rep(wb_web_biodiv_lt_sites_wdpa$id_site_from_postgres, sapply(s5, length)),
                                          WDPAID = unlist(s5))
wb_web_biodiv_lt_sites_wdpa <- wb_web_biodiv_lt_sites_wdpa[!duplicated(wb_web_biodiv_lt_sites_wdpa),]
wb_web_biodiv_lt_sites_wdpa$WDPAID <- as.numeric(as.character(wb_web_biodiv_lt_sites_wdpa$WDPAID))
write.table(wb_web_biodiv_lt_sites_wdpa,  paste(getwd(), "/eConservation_WB_2010_2015/Lookup_tables/wb_web_biodiv_lt_sites_wdpa.csv", sep=""), row.names=FALSE, sep="|", fileEncoding = "UTF-8", na = "")







#######################################################
# V. Create the DONORS table

# V.1. The donor information was not specified in the WB donwload data. It was completed by hand by searching online documentation of projects on the WB website
wb_web_biodiv_donors <- read.csv(paste(getwd(), "/Temp/wb_donor.csv", sep=""),
                                 na.strings = NA, header=T, sep=",", dec=".", encoding="latin1") # Import the table with project ID and donor names that has been completed into Excel

# V.2. Create the DONORS table
## V.2.1. Decompose the coordinates variables (Latitude and Longitude) to have only one row per project-donor combination
s <- (strsplit(as.character(wb_web_biodiv_donors$donor_name), split = ";"))
wb_web_biodiv_lt_proj_donors <- data.frame(id_proj_from_provider = rep(wb_web_biodiv_donors$id_proj_from_provider, sapply(s, length)),
                                           donor_name = unlist(s))
## V.2.2. Extract the unique donors                                          
wb_web_biodiv_donors <- unique(wb_web_biodiv_donors$donor_name)
## V.2.3. Create a unique numerical ID for the donors (starting from a number higher than the length of the current eConservation database to avoid duplicate ID)
wb_web_biodiv_donors$id_donor <- seq(150, (150-1+nrow(wb_web_biodiv_donors)))
## V.2.4. Complete the donors information (acronym, website, address, etc.) by hand in excel
write.csv(wb_web_biodiv_donors, paste(getwd(), "/Temp/donors_to_complete.csv", sep=""), row.names = F) # Export to Excel
wb_web_biodiv_donors <- read.csv(paste(getwd(), "/Temp/donors_to_complete.csv", sep=""),
                                 na.strings = NA, header=T, sep=",", dec=".", encoding="latin1") # Import the completed table back
## V.2.5. Clean donors
wb_web_biodiv_donors$donor_name <- gsub("\\|", " - ", wb_web_biodiv_donors$donor_name)
wb_web_biodiv_donors$address <- gsub("\\|", " - ", wb_web_biodiv_donors$address)
wb_web_biodiv_donors$Description <- gsub("\\|", " - ", wb_web_biodiv_donors$Description)
wb_web_biodiv_donors$donor_name <- gsub("[\r\n]", "", wb_web_biodiv_donors$donor_name)
wb_web_biodiv_donors$address <- gsub("[\r\n]", "", wb_web_biodiv_donors$address)
wb_web_biodiv_donors$Description <- gsub("[\r\n]", "", wb_web_biodiv_donors$Description)
wb_web_biodiv_donors$donor_name <- gsub("\"", "", wb_web_biodiv_donors$donor_name)
wb_web_biodiv_donors$address <- gsub("\"", "", wb_web_biodiv_donors$address)
wb_web_biodiv_donors$Description <- gsub("\"", "", wb_web_biodiv_donors$Description)
wb_web_biodiv_donors$donor_name <- gsub("[\t]", "", wb_web_biodiv_donors$donor_name)
wb_web_biodiv_donors$address <- gsub("[\t]", "", wb_web_biodiv_donors$address)
wb_web_biodiv_donors$Description <- gsub("[\t]", "", wb_web_biodiv_donors$Description)
wb_web_biodiv_donors$donor_name <- gsub("N/A", NA, wb_web_biodiv_donors$donor_name)
wb_web_biodiv_donors$address <- gsub("N/A", NA, wb_web_biodiv_donors$address)
wb_web_biodiv_donors$Description <- gsub("N/A", NA, wb_web_biodiv_donors$Description)
wb_web_biodiv_donors$date_oldest_project <- NA
wb_web_biodiv_donors$date_latest_project <- NA
## V.2.6. Save the DONORS table
write.table(wb_web_biodiv_donors, paste(getwd(),"/eConservation_WB_2010_2015/Main_tables/wb_web_biodiv_donors.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "latin1", na = "")

# V.3. Create the lookup table projects - donors
# V.3.1. Complete the table projects-donors with the new donor id 
wb_web_biodiv_lt_proj_donors <- merge(wb_web_biodiv_lt_proj_donors, wb_web_biodiv_donors, by="donor_name", all.x=T, all.y=F)
wb_web_biodiv_lt_proj_donors <- subset(wb_web_biodiv_lt_proj_donors, select=c("id_proj_from_provider", "id_donor"))
wb_web_biodiv_lt_proj_donors <- merge(wb_web_biodiv_lt_proj_donors, 
                                      subset(wb_web_biodiv_10_15_projects, select=c(id_proj_from_provider, id_proj_from_postgres)), 
                                      by="id_proj_from_provider", all.x=T, all.y=F)
# V.3.2. Save the projects - donors lookup table
write.table(wb_web_biodiv_lt_proj_donors,  paste(getwd(),"/eConservation_WB_2010_2015/Lookup_tables/wb_web_biodiv_lt_proj_donors.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "UTF-8", na = "")




#######################################################
# VI. Create the project - provider lookup table
wb_web_biodiv_lt_proj_provider <- subset(wb_web_biodiv_10_15, select=c(id_proj_from_provider, id_proj_from_postgres))
wb_web_biodiv_lt_proj_provider$id_provider <- 10  # the eConservation ID for the World Bank as a data provider is 10
wb_web_biodiv_lt_proj_provider <- wb_web_biodiv_lt_proj_provider[!duplicated(wb_web_biodiv_lt_proj_provider),]
write.table(wb_web_biodiv_lt_proj_provider, paste(getwd(),"/eConservation_WB_2010_2015/Lookup_tables/wb_web_biodiv_lt_proj_provider.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "UTF-8", na = "")


#######################################################
# VII. Create the project - species lookup table

# VII.1. Create target species variables
wb_web_biodiv_10_15$species_name <- NA
wb_web_biodiv_10_15$iucn_species_id <- NA
wb_web_biodiv_10_15$scientific_name <- NA

# VII.2. Complete the species data
## VII.2.1. The target species was not clearly indicated in the WB download data. The information was searched trhough a visual scan of the projects titles
### only one project had information about a specific target species
wb_web_biodiv_10_15$species_name[wb_web_biodiv_10_15$id_proj_from_provider=="P113860"] <- "Tiger"
wb_web_biodiv_10_15$scientific_name[wb_web_biodiv_10_15$id_proj_from_provider=="P113860"] <- "Panthera tigris"
wb_web_biodiv_10_15$iucn_species_id[wb_web_biodiv_10_15$id_proj_from_provider=="P113860"] <- 15955
## VII.2.1. Save the information ono the main data table
write.table(wb_web_biodiv_10_15, paste(getwd(),"/eConservation_WB_2010_2015/Main_tables/data_all_projects_wb_10_15.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "latin1", na = "")

# VII.3. Create the project - species lookup table 
wb_web_biodiv_lt_proj_species <- subset(wb_web_biodiv_10_15, select=c(id_proj_from_provider, id_proj_from_postgres, iucn_species_id))
wb_web_biodiv_lt_proj_species <- wb_web_biodiv_lt_proj_species[!duplicated(wb_web_biodiv_lt_proj_species),]
write.table(wb_web_biodiv_lt_proj_species, paste(getwd(),"/eConservation_WB_2010_2015/Lookup_tables/wb_web_biodiv_lt_proj_species.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "UTF-8", na = "")



#######################################################
# VIII. Create the project - focus lookup table

## VII.1. The project focus was not clearly indicated in the WB download data, but could be extracted by hand from the "title", “sector”, “mjsector” and “theme” variables.
wb_web_biodiv_focus <- subset(wb_web_biodiv_10_15, select=c(id_proj_from_provider, id_proj_from_postgres, title, sector, mjsector, theme))
write.table(wb_web_biodiv_focus, paste(getwd(), "/Temp/wb_web_biodiv_focus.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "UTF-8", na = "NA") # Export table to Excel
wb_web_biodiv_focus <- read.csv(paste(getwd(), "/Temp/wb_web_biodiv_focus.csv", sep=""),
                                na.strings = NA, header=T, sep=",", dec=".", encoding="latin1") # Import the completed table back

## VII.2. Create the project - IUCN category lookup table 
wb_web_biodiv_lt_proj_category <- subset(wb_web_biodiv_focus, select=c(id_proj_from_provider, id_proj_from_postgres, iucn_cat_id))
wb_web_biodiv_lt_proj_category <- wb_web_biodiv_lt_proj_category[!duplicated(wb_web_biodiv_lt_proj_category),]
write.table(wb_web_biodiv_lt_proj_category, paste(getwd(),"/eConservation_WB_2010_2015/Lookup_tables/wb_web_biodiv_lt_proj_category.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "UTF-8", na = "")

## VII.3. Create the project - Aichi targets lookup table 
wb_web_biodiv_lt_proj_aichi <- subset(wb_web_biodiv_focus, select=c(id_proj_from_provider, id_proj_from_postgres, aichi_id))
wb_web_biodiv_lt_proj_aichi <- wb_web_biodiv_lt_proj_aichi[!duplicated(wb_web_biodiv_lt_proj_aichi),]
write.table(wb_web_biodiv_lt_proj_aichi, paste(getwd(),"/eConservation_WB_2010_2015/Lookup_tables/wb_web_biodiv_lt_proj_aichi.csv", sep=""), 
            row.names=FALSE, sep="|", fileEncoding = "UTF-8", na = "")
