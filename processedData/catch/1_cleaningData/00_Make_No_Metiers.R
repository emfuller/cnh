# Make file
rm(list=ls())
library(plyr)
library(dplyr)
library(testthat)
setwd("/Users/jameal.samhouri/Documents/CNH_to_github/cnh/")
#setwd("/Users/jamealsamhouri/Documents/cnh/")

# subset to landing data from "full-income" vessels ----
source("processedData/catch/1_cleaningData/01_incomeFilter_No_Metiers.R")

# set 10,000 as threshold for median income
  # loads fish ticket data within function
  ftl3 <- incomeFilter()

# filter for species caught using nominal designations ----
  source("processedData/catch/1_cleaningData/02_filter_nominal.R")
  ftl_major <- filter_nominal(data = ftl3)
  saveRDS(ftl_major, "processedData/catch/1_cleaningData/filtered_ftl_No_Metier.RDS")
  
# check to see if Indian fisheries are included
  unique(ftl_major$participation_group_code) # they are included
    
  #tmp1 <- readRDS("processedData/catch/1_cleaningData/filtered_ftl_No_Metier.RDS")

# # check to see which removal types are included in existing .RDS (tribal catch.?) 04/10/17
#   tmp1 <- readRDS("processedData/spatial/vms/intermediate/filtered_ftl.RDS")
#   unique(tmp1$removal_type)
#   # yes only includes C and D types
  
  
# add metiers to trips ----
# do metier clustering with infoMap: /tigress/efuller/raw_infoMap 
# combine clustering results with filtered ticket data, requires directory 2_defineMetiers has infoMap results
  # source("processedData/catch/1_cleaningData/03_sewTrips.R")
  # sewTrips(base_year=2010) # base year is which clustering results to use. 
  # #sewTrips(base_year=2012)
  # #sewTrips(base_year=2006)
  # #sewTrips(base_year=2008)
  # 
  # # load these data, combine so have both metier classifications
  # d10 <- readRDS("processedData/catch/1_cleaningData/tickets_2010.RDS")
  # #d12 <- readRDS("processedData/catch/1_cleaningData/tickets_2012.RDS")
  # #d06 <- readRDS("processedData/catch/1_cleaningData/tickets_2006.RDS")
  # #d08 <- readRDS("processedData/catch/1_cleaningData/tickets_2008.RDS")
  # 
  # d10 <- d10 %>%
  #   select(trip_id, metier) %>%
  #   rename(metier.2010 = metier) %>%
  #   distinct() 
  # 
  # d06 <- d06 %>%
  #   select(trip_id, metier) %>%
  #   rename(metier.2006 = metier) %>%
  #   distinct()
  # 
  # d08 <- d08 %>%
  #   select(trip_id, metier) %>%
  #   rename(metier.2008 = metier) %>%
  #   distinct()
  # 
  # 
  # tickets <- left_join(d12, d10, by = 'trip_id') %>%
  #   rename(metier.2012 = metier) %>%
  #   left_join(d06, by = 'trip_id') %>%
  #   left_join(d08, by = 'trip_id')
  # 
  # saveRDS(tickets, "processedData/catch/1_cleaningData/tickets.RDS")

# compare classification schemes ----
 
# not doing below for now, may delete. 
# # add fishing participation profile to trips ----
# # also on della, see fisheries_participation_profiles for more info
#   rm(tickets)
#   tickets <- readRDS(
#     "catch/fisheries_participation_profiles/tickets_plus.RDS")
# # calculate annual revenue by vessel ----
#   source("processedData/catch/1_cleaningData/04_annualRev.R")
#   yrdf <- annualRev(data = tickets)
