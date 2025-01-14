#___________________________________________________________________________
# This file is part of the SOcial Contact RATES (SOCRATES) modelling project
# 
# => PREPROCESS AND SAVE COUNTRY-SPECIFIC SURVEY DATA
# 
# Retrieving data from ZENODO is time consuming, so we make a local copy
#
#  Copyright 2024, SIMID, UNIVERSITY OF ANTWERP & HASSELT UNIVERSITY
#___________________________________________________________________________

# clear workspace
rm(list=ls())

# load social mixr package
library(socialmixr)
library(data.table)

# updated socialmixr function(s)
source('R/contact_matrix_fix.R')

# specify output directory
output_dir <- 'data2'

# RETRIEVE FROM ZENODO ----

# get list with all available datasets
#survey_meta_data <- list_surveys()
#saveRDS(survey_meta_data,file='data/survey_meta_data.rds')
survey_meta_data <- readRDS('data/survey_meta_data.rds')

# add column for country
survey_meta_data[grepl('Peru',title),country:='peru']
survey_meta_data[grepl('Hong Kong',title),country:='hong_kong']
survey_meta_data[grepl('Russia',title),country:='russia']
survey_meta_data[grepl('Vietnam',title),country:='vietnam']
survey_meta_data[grepl('POLYMOD',title),country:='polymod']
survey_meta_data[grepl('CODA',title),country:='zambia_south_africa']
survey_meta_data[grepl('China',title),country:='china']
survey_meta_data[grepl('Zimbabwe',title),country:='zimbabwe']
survey_meta_data[grepl('France',title),country:='france']
survey_meta_data[grepl('UK',title),country:='uk']
survey_meta_data[grepl('Belgium',title),country:='belgium']
survey_meta_data[grepl('Netherlands',title),country:='netherlands']
survey_meta_data[grepl('Gambia',title),country:='gambia']
survey_meta_data[grepl('Somaliland',title),country:='somaliland']
survey_meta_data[grepl('Taiwan',title),country:='taiwan']
survey_meta_data[grepl('Thailand',title),country:='thailand']

# check year and title
survey_meta_data$date_added
survey_meta_data$title

# for Comix Surveys
survey_meta_data[,is_comix := grepl('CoMix social contact data',survey_meta_data$title)]
survey_meta_data[(is_comix),country:=gsub('.*\\(','',tolower(title))]
survey_meta_data[(is_comix),country:=gsub('\\)','',tolower(country))]
survey_meta_data[(is_comix),country:=gsub(' ','',tolower(country))]
survey_meta_data[(is_comix),]
survey_meta_data$title
which(survey_meta_data$is_comix)

# CoMix last round BE, CH, NL, UK
survey_meta_data[grepl('CoMix 2.0 social contact data',title),country:='comix_multi']
survey_meta_data[grepl('last round in BE, CH, NL and UK',title),country:='comix_update']

# check country
survey_meta_data$country
survey_meta_data[is.na(country),]

# Remove data for France (Béraud et al 2015)
# ==>> this is handled in a separate script
survey_meta_data[survey_meta_data$creator != 'Guillaume Béraud',]

# make sure the tmp data folder exists
if(!dir.exists(output_dir)){
  dir.create(output_dir)
}

# add data file tag
survey_meta_data$tag <- ''
survey_meta_data[grepl('older adults',title),tag := '_elderly']
survey_meta_data[grepl('Pienter',title),tag := '_pienter']
survey_meta_data[grepl('Household',title),tag := '_household']
survey_meta_data[grepl('Children',title),tag := '_children']


# files <- dir('data_zenodo_all/',pattern='comix_pl',full.names = TRUE)
# files <- dir('data_zenodo_all/',pattern='comix_be',full.names = TRUE)
# survey <- load_survey(files)
# survey <- clean(survey)
# survey$participants$part_age
# survey$participants$part_age_est_min

# get dataset from ZENODO and save as RDS
i <- 1
survey_meta_data[i,]
for(i in 1:nrow(survey_meta_data)){

  # manual download and selection for "comix 2.0"
  if(survey_meta_data$country[i] == "comix_multi"){
    files       <- download_survey(survey_meta_data$url[i])
    files       <- files[grepl('comix_2',files) | grepl('json',files)]
    survey_data <- load_survey(files)
  } else if(survey_meta_data$country[i] == "zimbabwe"){
    files       <- download_survey(survey_meta_data$url[i])
  
    # two sday records for 1 participant is causing issues in the merge, hence select the first one.
    # this will cause a warning to match time_use_common for the second studyday, but that is OK for now
    zimbabwe_sday <- read.csv(files[grepl('sday',files)])
    zimbabwe_sday <- zimbabwe_sday[zimbabwe_sday$studyDay == 1,]
    zimbabwe_sday <- write.csv(zimbabwe_sday,files[grepl('sday',files)],row.names = FALSE)
    
    survey_data <- load_survey(files)
    
    # select contacts from first survey day
    survey_data$contacts         <- survey_data$contacts[survey_data$contacts$studyDay == 1,]
    
  } else {
    # load data
    survey_data <- get_survey(survey_meta_data$url[i])
  }
    
  # get survey year for rds file name
   syear <- min(substr(survey_data$contacts$sday_id,0,4),
               substr(survey_data$participants$sday_id,0,4),na.rm=T)
  if(is.na(syear)){
    syear <- year(survey_meta_data$date_added[i])
  }
  
  if(survey_meta_data$country[i] == 'zambia_south_africa'){ syear = 2011 }
  if(survey_meta_data$country[i] == 'polymod'){ syear = 2008 } # use the year of the publication
  if(survey_meta_data$country[i] == 'zimbabwe'){ syear = 2013 }
  
  # save as .rds file
  saveRDS(survey_data, file=paste0(output_dir,'/survey_',survey_meta_data$country[i],syear,
                                   ifelse(survey_meta_data$is_comix[i],'_comix',''),
                                   survey_meta_data$tag[i],'.rds'))
}

# DATA SELECTION FROM ZENODO ----

# get file names
files_survey <- dir(output_dir,pattern = 'rds',full.names = TRUE)

# set new output dir (forced)
new_data_dir <- paste0(output_dir,'_clean')

# clear and make new output dir (forced)
unlink(new_data_dir,recursive=TRUE,force = TRUE)
dir.create(new_data_dir)

# specific changes
# BE 2006, has 2 waves, but participants details are included only once
# remove for now
files_survey <- files_survey[!grepl('belgium2006',files_survey)]

# check and select data columns
pdata_age  <- c('part_age','part_age_est_min','part_age_est_max')
pdata_type <- c('part_id',
                    'part_gender',
                    'country',
                    'dayofweek'
                    ) # sday_id
pdata_required <- c(pdata_age, pdata_type, 'holiday','wave',
                    'day', 'month','year','panel','sday_id')

cdata_type <- c('part_id','cnt_age_exact',"cnt_age_est_min", "cnt_age_est_max",
                    'cnt_gender',"frequency_multi","phys_contact","duration_multi")
cdata_location <- c('cnt_home','cnt_work','cnt_school',"cnt_transport", "cnt_leisure", "cnt_otherplace")
cdata_required <- c(cdata_type,cdata_location)

i_file <- 8
 for(i_file in 1:length(files_survey)){
#  for(i_file in 1:10){
  
  print(files_survey[i_file])
  survey_zenodo <- readRDS(files_survey[i_file])
  
  survey_zenodo$reference
  names(survey_zenodo$contacts)
  names(survey_zenodo$participants)
  dim(survey_zenodo$participants)
  
  # initiate
  survey_clean <- survey_zenodo
  
  # select columns
  survey_clean$participants <- survey_clean$participants[, .SD, .SDcols = names(survey_clean$participants) %in% pdata_required]
  survey_clean$contacts     <- survey_clean$contacts[, .SD, .SDcols = names(survey_clean$contacts) %in% cdata_required]
  
  # if location location is not a standard category, hence is missing in the selection, set to "otherplace"
  cnt_missing <- rowSums(survey_clean$contacts[, .SD, .SDcols = names(survey_clean$contacts) %in% cdata_location]) == 0
  if(length(cnt_missing)>0){
    survey_clean$contacts[cnt_missing,cnt_otherplace:=TRUE]
  }
  
  # if some location types are missing, add them with FALSE
  missing_locations <- cdata_location[!cdata_location %in% names(survey_clean$contacts)]
  if(length(missing_locations)>0 && length(missing_locations)<length(cdata_location)){
    survey_clean$contacts[,`:=`(eval(missing_locations), FALSE)]
    print(c('locations added:',missing_locations))
  } 

  # if an age range is given for the participant, remove the "exact" age
  if(all(c('part_age_est_min','part_age_est_max') %in% names(survey_clean$participants))){
    survey_clean$participants$part_age <- NULL
  }
  
  #check if all columns are there
  if(!(all(pdata_type %in% names(survey_clean$participants)) & any(pdata_age %in% names(survey_clean$participants)))){
    print(c('issue on pdata:',pdata_type[!pdata_type %in% names(survey_clean$participants)]))
  }
  if(!all(cdata_required %in% names(survey_clean$contacts))){
    print(c('issue on cdata:',cdata_required[!cdata_required %in% names(survey_clean$contacts)]))
    }

  # specific changes
  # Belgium 2010 household study
  if(grepl('belgium2010_household',files_survey[i_file])){
    survey_clean$participants$country <- 'Belgium'
  }
  
  # Zimbabwe 2013 study
  if(grepl('survey_zimbabwe2013',files_survey[i_file])){
    survey_clean$participants$country <- 'Zimbabwe'
  }
  
  if(grepl('uk2020_comix',files_survey[i_file])){
    survey_clean$participants$country <- 'United Kingdom'
    survey_clean$participants$year <- survey_clean$participants$year + 2000 # notation: 20, 21, 22
  }
  
  if(grepl('uk2018',files_survey[i_file])){
    survey_clean$participants$country <- 'United Kingdom'
  }
  
  if(grepl('belgium2020_comix',files_survey[i_file])){
    # merge "Panel B" and "Panel BC", and rename to "BC"
    survey_clean$participants[,panel := gsub('Panel B.*','BC',panel)]
    # table(survey_clean$participants$panel,
    #       survey_clean$participants$wave)
  }
  
  if(grepl('zambia_south_africa',files_survey[i_file])){
    table(survey_clean$participants$sday_id,
                 survey_clean$participants$country)
    # Some surveys were registered with the date 13/12/1091, which appears to be erroneous.
    # Assuming the weekday (Saturday) is correct, the correct date should likely be 12, with 13 as a typo for the month 3 (March).
    # February 2011 data from Zambia seems to consistently span at least two consecutive days, and there is no data for the 11th or 13th
    # SOCRATES focuses on the day of the week and does not conduct longitudinal analysis, so as long as the date falls within the overall min-max date range, there is no issue.
    survey_clean$participants <- survey_clean$participants %>% 
                                    mutate(
                                      day = if_else(sday_id == 19011213, 12, day),
                                      month = if_else(sday_id == 19011213, 3, month),
                                      year = if_else(sday_id == 19011213, 2011, year),
                                      sday_id = if_else(sday_id == 19011213, 20110302, sday_id)
                                    )
  }
  
  # store
  saveRDS(survey_clean,gsub(output_dir,new_data_dir,files_survey[i_file]))
  
  }
  

# COMIX ----
# check comix waves and additional datasets

# files <- dir('data4',full.names = TRUE)
files <- dir(new_data_dir,full.names = TRUE)
comix_multi <- readRDS(files[grepl('comix_multi',files)])
names(comix_multi$participants)
names(comix_multi$contacts)
table(comix_multi$participants$country,
      comix_multi$participants$wave)
comix_multi$reference$author

comix_update <- readRDS(files[grepl('comix_update',files)])
sort(names(comix_update$participants))
table(comix_update$participants$country,
      comix_update$participants$sday_id)
comix_update$reference$author

comix_be <- readRDS(files[grepl('belgium2020_comix.rds',files)])
names(comix_be$participants)
table(comix_be$participants$wave)
table(comix_be$participants$sday_id)

a_list <- c(comix_update$reference$author,comix_be$reference$author)
clean_author_list <- function(a_list){
  i <- 1
  for(i in 1:length(a_list)){
    if(grepl(', ',a_list[i])){
      # swith first and last name
      a_list[i] <- paste(unlist(strsplit(a_list[i],', '))[2:1],collapse=' ')
    }
  }
  a_list
  
  # remove double space
  a_list <- gsub('  ',' ',a_list)
  
  # remove duplications
  a_list <- unique(a_list)
  
  # check for issues with additional surnames
  if(any(grepl(' . ',a_list))){
    
    # remove initials
    a_list_tmp <- gsub(' . ',' ',a_list)

    # if unique list is shorter, because some are with and some without initials, use the updated one
    if(length(unique(a_list_tmp)) != length(a_list_tmp)){
      a_list <- unique(a_list_tmp)      
    }
  }
  
  return(a_list)
}

comix_aggr <- comix_multi
comix_country <- comix_be
extend_comix_country_data <- function(comix_country, comix_aggr, country_str){
  
  if(!country_str %in% comix_aggr$participants$country){
    warning("The given country name is not valid!!")
    return(NULL)
  }
  
  # get country specific subset
  comix_selection <- comix_aggr
  comix_selection$participants <- comix_selection$participants[country == country_str,]
  comix_selection$contacts <- comix_selection$contacts[part_id %in% comix_selection$participants$part_id,]

  if(any(comix_selection$participants$part_id %in% comix_country$participants$part_id)){
    warning("Participant id's are not unique!!")
  }
  
  # add participant details to comix_country
  if(sum(names(comix_selection$participants) %in% names(comix_country$participants)) == ncol(comix_country$participants)){
    comix_country$participants <- rbind(comix_country$participants,
                                     comix_selection$participants[,.SD, .SDcols = names(comix_country$participants)])
  } else {
    warning("Participant data does not match")
  }
  
  # add contact details to comix_country
  if(sum(names(comix_selection$contacts) %in% names(comix_country$contacts)) == ncol(comix_country$contacts)){
    comix_country$contacts <- rbind(comix_country$contacts,
                                     comix_selection$contacts[,.SD, .SDcols = names(comix_country$contacts)])
  } else{
    warning("Contact data does not match")
  }
  
  # merge reference details
  comix_country$reference$title <- paste(comix_country$reference$title,comix_selection$reference$title,sep=' & ')
  comix_country$reference$author <- clean_author_list(c(comix_country$reference$author,comix_selection$reference$author))

  return(comix_country)
}

comix_country = readRDS(files[grepl('belgium2020_comix.rds',files)])
comix_country_update <- extend_comix_country_data(comix_country = comix_country,
                                                  comix_aggr = comix_multi,
                                                  country_str = 'Belgium')

comix_update$participants$wave <- 48
comix_country_update <- extend_comix_country_data(comix_country = comix_country_update,
                                                  comix_aggr = comix_update,
                                                  country_str = 'Belgium')

table(comix_country_update$participants$wave)
saveRDS(comix_country_update,gsub('_comix','_comix_incl48',files[grepl('belgium2020_comix.rds',files)]))

#TODO: update other comix countries with data from comix_update and/or comix_multi


# Optional: compare updated datasets ####
if(0==1){ # not executed by default
  
  files_orig <- dir('data',pattern = 'rds',full.names = T)
  files_new <- dir('data2_clean',pattern = 'rds',full.names = T)
  
  # remove redundant version of belgium2020 comix
  files_new <- files_new[!grepl('belgium2020_comix.rds',files_new)]
  
  files_orig  
  files_new

  # align db
  db_orig <- data.frame(name_orig = files_orig,
                        name_edit = basename(files_orig), #basename(gsub('_comix','',files_orig)),
                        is_comix  = grepl('comix',files_orig))
  
  
  db_new <- data.frame(name=files_new,
                        name_edit = basename(gsub('_comix.*.rds','_comix.rds',gsub('NA','',files_new))))
  
  db_new <- merge(db_new,db_orig,all.x = TRUE,by="name_edit")
  db_new$is_comix[is.na(db_new$is_comix)] <- FALSE
  db_new
  
  db_new$is_update  <- !is.na(db_new$name_orig)
  db_orig$is_update <- db_orig$name_edit %in% db_new$name_edit
  
  db_new[!db_new$is_update,]
  db_new[db_new$is_update,]
  db_orig[!db_orig$is_update,]
  
  db_new$dim_part <- NA
  db_new$dim_cnt  <- NA
  db_new$len_ref      <- NA
  db_new$part_id <- NA
  db_new$part_age <- NA
  db_new$part_ageNA <- NA
  db_new$part_ageNA <- NA
  db_new$cnt_part_id <- NA
  db_new$cnt_age_exact <- NA
  db_new$cnt_age_exactNA <- NA
  db_new$bool_wave <- FALSE
  db_new$bool_panel <- FALSE
  db_new$bool_panel_wave <- FALSE
  
  i_file <- 1
  for(i_file in which(db_new$is_update)){
    
    survey_new  <- readRDS(db_new$name[i_file])
    survey_orig <- readRDS(db_new$name_orig[i_file])
  
    db_new$dim_part[i_file] <- all(dim(survey_new[[1]]) == dim(survey_orig[[1]]))
    db_new$dim_cnt[i_file] <- all(dim(survey_new[[2]]) == dim(survey_orig[[2]]))
    db_new$len_ref[i_file] <- length(survey_new[[3]]) == length(survey_orig[[3]]) && 
                                        paste(unlist(survey_new[[3]]),collapse=' ') == paste(unlist(survey_orig[[3]]),collapse=' ')
    
    # fix for 'UK'
    survey_orig$participants$country <- gsub('UK','United Kingdom',survey_orig$participants$country)
    
    age_breaks <- c(0,18,40)  
    suppressMessages(suppressWarnings(cnt_mat_orig <- contact_matrix(survey_orig,age.limits = age_breaks,symmetric = TRUE)))
    suppressMessages(suppressWarnings(cnt_mat_new  <- contact_matrix(survey_new,age.limits = age_breaks,symmetric = TRUE)))
    
    if(any(cnt_mat_orig$matrix != cnt_mat_new$matrix)){
      cnt_mat_orig$matrix - cnt_mat_new$matrix
      print('CONTACT MATRIX IS DIFFERENT')
    }
    if(any(cnt_mat_orig$participants != cnt_mat_new$participants)){
      cnt_mat_orig$participants != cnt_mat_new$participants
      print('PARTICIPANT DATA IS DIFFERENT')
    }
    
    if(length(survey_new$participants$part_id) == length(survey_orig$participants$part_id)){
      db_new$part_id[i_file]    <- sum((survey_new$participants$part_id != survey_orig$participants$part_id))
      db_new$part_age[i_file]   <- sum((survey_new$participants$part_age != survey_orig$participants$part_age))
      db_new$part_ageNA[i_file] <- sum(is.na(survey_new$participants$part_age) != is.na(survey_orig$participants$part_age),na.rm=T)
    }
    
    if(length(survey_new$contacts$part_id) == length(survey_orig$contacts$part_id)){
      db_new$cnt_part_id[i_file]    <- sum((survey_new$contacts$part_id != survey_orig$contacts$part_id))
      db_new$cnt_age_exact[i_file]   <- sum((survey_new$contacts$cnt_age_exact != survey_orig$contacts$cnt_age_exact))
      db_new$cnt_age_exactNA[i_file] <- sum(is.na(survey_new$contacts$cnt_age_exact) != is.na(survey_orig$contacts$cnt_age_exact),na.rm=T)
    }
    
    db_new$bool_wave[i_file] <- 'wave' %in% names(survey_new$participants)
    db_new$bool_panel[i_file] <- 'panel' %in% names(survey_new$participants)
    db_new$bool_panel_wave[i_file] <- 'wave_wrt_panel' %in% names(survey_new$participants)
  }
  
  db_new[db_new$is_comix,-1]
  db_new[!db_new$is_comix & db_new$is_update,-1]
  db_new[db_new$is_comix & db_new$is_update,-1]
  db_new[!db_new$is_comix & !db_new$is_update,-1]
  db_new[db_new$is_update,-1]
  db_new[db_new$bool_wave,-1]
  
}
