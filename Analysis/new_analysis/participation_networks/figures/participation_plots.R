library(dplyr)
library(tidyr)
library(igraph)
library(maps)
library(ggthemes)
library(scales)
library(ggplot2)

setwd("/Users/efuller/Desktop/CNH/")
tickets <- readRDS("processedData/catch/1_cleaningData/tickets.RDS")

# if filter = TRUE
# drop metiers with < 3 vessels, 
# drop metiers that make up < 25% of vessel's average revenue on average
# drop metiers that don't contribute to top 99% of revenue

participation_network <- function(tickets, pcid_choose=NA, year=NA, filter){
  if(!is.na(pcid_choose)){
    tickets = dplyr::filter(tickets, pcgroup %in% pcid_choose)
  }
  if(!is.na(year)){
    tickets = dplyr::filter(tickets, year %in% year)
  }
  
  n_boats <- tickets %>% filter(drvid!='NONE') %>%
  group_by(year, metier.2010) %>%
  summarize(n_boats = length(unique(drvid))) %>%
  group_by(metier.2010) %>%
  summarize(max_boats = max(n_boats))


  boats <- tickets %>% filter(drvid != 'NONE') %>%
    mutate(tdate = as.Date(tdate, format = "%d-%b-%y"), 
           doy = as.numeric(format(tdate, '%j')), 
           crab_year = ifelse(doy<305, year-1, year)) %>%
    group_by(drvid, metier.2010, year) %>%
    summarize(revenue = sum(adj_revenue)) %>%
    spread(metier.2010, revenue, fill = NA)
  boats <- as.data.frame(boats)
  rownames(boats) <- paste(boats$drvid, boats$year, sep="_")
  boats$drvid <- NULL
  boats$year <- NULL
  # remove the one boat that didn't sell catch (i.e. rev = 0)
  if(any(rowSums(boats,na.rm=T)==0)){boats <- boats[-which(rowSums(boats, na.rm=T)==0),]}
  percent_boats <- boats/rowSums(boats, na.rm = T)
  
  # find fisheries where at median contribution is 10%
  percent_contribution = apply(percent_boats, MARGIN = 2, FUN = function(x) median(x, na.rm=T))
  
  # process data: drop 'NONE' drvid, drop metiers if fewer than 3 boats participate
  # in any year, and have to be on average 25% of boats annual revenue
  
  if(filter){
    nb = 3
    percent = .25
  }else{
    nb = 0
    percent = 0
  }
  
  fishery_df = as.data.frame(percent_contribution)
  fishery_df$metier.2010 = rownames(fishery_df)
  rownames(fishery_df) <- NULL
  fish_df <- left_join(fishery_df, n_boats, by = 'metier.2010')
  # build adjacency matrix, where elements are frac rev fishery i * frac rev fishery j * total dollars (sum)
  fisheries <- fish_df$metier.2010[which(fish_df$max_boats> nb & 
                                              fish_df$percent_contribution>percent)]
  A <- matrix(ncol = length(fisheries), nrow = length(fisheries), data = 0)
  colnames(A) <- fisheries
  rownames(A) <- fisheries
  for(k in 1:nrow(boats)){
    
    for(i in 1:nrow(A)){
      frac_rev_i = percent_boats[k,fisheries[i]]
      if(is.na(frac_rev_i)){next} # if don't fish this, then can skip all other combos
      
      for(j in i:ncol(A)){
        frac_rev_j = percent_boats[k,fisheries[j]]
        if(is.na(frac_rev_j)){next}
        
        total_rev = boats[k, fisheries[i]] + boats[k, fisheries[j]]
        A[i,j] = A[i,j] + frac_rev_i * frac_rev_j * total_rev
      }
    }
    #if(k %% 1000 == 0){cat(paste(' iteration', k))}
  }
  
  # do same for crab_year
  
  g <- graph_from_adjacency_matrix(adjmatrix = A, mode = 'undirected', weighted = TRUE, diag= FALSE)
  V(g)$size <- colSums(boats[,fisheries],na.rm=T)
  V(g)$percent_size = apply(percent_boats[,fisheries], MARGIN = 2, FUN = function(x) median(x, na.rm=T))
  V(g)$importance = V(g)$size*V(g)$percent_size
  
  # if filter = TRUE, keep V which make up to 99% of revenue
  if(filter){
    # calculate % cumulative revenue fisheries are responsible for
    size_df <- cbind(V(g), V(g)$size)
    size_df <- size_df[order(size_df[,2], decreasing = T),]
    size_df <- cbind(size_df, cumsum(size_df[,2])/sum(size_df[,2]))
    
    big_g <- induced_subgraph(g, V(g)[V(g)[rownames(size_df)[which(size_df[,3]<.99)]]])
  }else{
    big_g <- g
  }
  return(big_g)
}

# plot coastwide ----
big_g <- participation_network(tickets, filter = TRUE)
l <-layout.fruchterman.reingold(big_g) 
l <- cbind(l, 1:21)
rownames(l) <- V(big_g)$name

# add common names
V(big_g)$common_name = c('sablefish\nlongline', 
                         'black rockfish\nlongline', 
                         'swordfish\nlongline',
                         'rockfish\npole',
                         'sea urchin\ndiving',
                         'chinook\ngill net',
                         'market squid\npurse seine',
                         'chum salmon\ngill net',
                         'sockeye\ngill net',
                         'white seabass\ngill net',
                         'sea cucumber\ndip net',
                         'dungeness\ncrab pot', 
                         'spiny lobster\npot',
                         'sablefish\npot', 'hagfish\npot', 'chinook\ntroll',
                         'albacore\ntuna troll', 'groundfish\ntrawl', 'CA halibut\ntrawl', 
                         'whiting\nmidwater\ntrawl',
                         'pink shrimp\ntrawl')

# adjust layout manually for national
ix <- function(metier){
  return(which(rownames(l)==toupper(metier)))
}
l[ix('pot_1'), 1:2] <- c(0, 0) # pot_1
l[ix('twl_1'), 1:2] <- c(.4, .65) # twl_1
l[ix('twl_7'), 1:2] <- c(0.2, 1) # twl_7 # whiting
l[ix('tws_1'), 1:2] <- c(-.3, .7) # tws_1 # pink shrimp
l[ix('twl_2'), 1:2] <- c(.65, .5) # twl_2 # ca halibut trawl
l[ix('tls_1'), 1:2] <- c(-0.25, -.5) # tls_1 # chinook troll
l[ix('tls_2'), 1:2] <- c(-.5, .15) # tls_2 # albacore troll
l[ix('msc_1'), 1:2] <- c(0, -.8) # msc_1 # urchin diving
l[ix('pot_4'), 1:2] <- c(.5, -1) # pot_4
l[ix('pot_2'), 1:2] <- c(-.2, -1.3) #pot_2 # spiny lobster
l[ix('net_2'), 1:2] <- c(-1.6, .1) # net_2 # market squid seine
l[ix('hkl_1'), 1:2] <- c(.65, -.2) # hkl_1 # sablefish longline
l[ix('hkl_2'), 1:2] <- c(1, .25) # hkl_2 # black rockfish
l[ix('pot_6'), 1:2] <- c(-.85, -.35) # pot_6 # hagfish
l[ix('hkl_4'), 1:2] <- c(.3, -.5) # hkl_4  # multisp rockfish pole
l[ix('hkl_23'), 1:2] <- c(-1.15, -.5) # hkl_23 # swordfish 
l[ix('net_8'), 1:2] <- c(-1, -1.15) # net_8 # white seabass
l[ix('net_1'), 1:2] <- c(-1, .6) # net_1 # chinook gill net
l[ix('net_4'), 1:2] <- c(-1.25, 1) # net_4 # chum salmon gill net
l[ix('net_7'), 1:2] <- c(-1.2, .4) # net_7 # sockey gill net
l[ix('net_9'), 1:2] <- c(.65, -.65) # net_9 # sea cucumber

png('/Users/efuller/Desktop/CNH/Analysis/old_analysis/participation_plots/policy_forum/coastwide.png', width = 1680, height = 947, unit = 'px', res=300)
#par(bg='#073642', mai=rep(0,4)) # dark blue
par(bg='#268bd2', mai=rep(0,4)) # light blue

plot(big_g, vertex.size = V(big_g)$size/40000000, vertex.label.cex= .75, 
     vertex.frame.color=NA, layout = l, vertex.label = "", 
     edge.width = sqrt(E(big_g)$weight)/900, edge.color = 'white',
     vertex.color = '#cb4b16', edge.curved = F, axes = F,
     vertex.label.family = 'sans', vertex.label.color = '#cb4b16')
dev.off()

# find list of ports ----

pcid <-all_ports <- read.csv('processedData/spatial/ports/all_ports.csv',
                 stringsAsFactors = FALSE) %>%
  rename(pcid = Pcid) %>%
  filter(pcid %in% unique(tickets$pcid[-which(tickets$drvid=="NONE")])) %>%
  left_join(unique(tickets[c("pcgroup","pcid")]), by = 'pcid') %>%
  group_by(pcgroup) %>%
  summarize(lat = mean(lat, na.rm = T), lon = mean(lon, na.rm = T)) %>%
  filter(!is.nan(lat))


# #what does this drop?
# missing_pcid <- tickets %>% filter(drvid != 'NONE') %>%
#   filter(!(pcgroup %in% pcid$pcgroup)) %>%
#   group_by(pcgroup, metier.2010) %>%
#   summarize(n_trips = length(unique(trip_id)),
#             revenue = sum(adj_revenue))
# 
# ggplot(missing_pcid, aes(x = metier.2010, y = n_trips)) +
#   geom_bar(stat = 'identity') + facet_wrap(~pcgroup, scales = 'free')

# mostly others, but drops salmon river and columbia river landings. Salmon river 
# is very small (5 trips of black rockfish), but columbia river is dominated by NET_1,
# and is >30,000 trips (over 8 year period)


# build networks for top ports ----
port_list <- list()
for(i in 1:nrow(pcid)){
  port_list[[i]] <- participation_network(tickets, pcid=pcid$pcgroup[i], 
                                          filter = T)
}

# build dictionary of state versus federal ----
# if LE, then federal
# if OA & management complex dominated by ground, 'both': nearshore has both federal and state
# if unknown, then

management_level = data.frame(
  metier.2010 = unique(unlist(lapply(port_list, function(x)V(x)$name))),
  stringsAsFactors = FALSE)

# get fleet composition
reg_level <- function(metier){
  # count number of trips by fleet type
  # LE: limited entry
  # OA: open access
  # XX: unknown (assumed open access)
  
  count_trips <- tickets %>%
    filter(metier.2010 == toupper(metier)) %>%
    group_by(fleet) %>%
    summarize(n_trips = length(unique(trip_id)))
    
    # robust to either or both not existing
    XX = count_trips$n_trips[count_trips$fleet == "XX"]
    if(length(XX) == 0){XX = 0}
    OA = count_trips$n_trips[count_trips$fleet=="OA"]
    if(length(OA)==0){OA = 0}
    LE = count_trips$n_trips[count_trips$fleet=="LE"]
    if(length(LE)==0){LE = 0}
    management = ifelse(XX > OA & XX > LE, 'unknown',
                 ifelse(OA > LE, 'OA',
                 ifelse(OA == LE, 'b', 
                 ifelse(OA < LE, 'LE', NA))))
    return(management)
}
management_level$fleet = unlist(apply(management_level, 1, reg_level))

# get management group of metier
spid <- read.csv('processedData/catch/spid.csv',stringsAsFactors = FALSE)
spid$X <- NULL

mgmt_grp <- function(metier){
  sp_comp <- tickets %>% filter(metier.2010 == toupper(metier)) %>%
    group_by(modified) %>%
    summarize(revenue = sum(adj_revenue, na.rm = T),
              nlbs = sum(pounds),
              ntrips = length(unique(trip_id))) %>%
    left_join(spid[c("SPID","complex","mgmt_grp")], c('modified' = 'SPID')) 
  return(sp_comp$mgmt_grp[which.max(sp_comp$revenue)])
}
management_level$mgmt_grp = apply(management_level, 1, function(x) mgmt_grp(x[1]))

# if management is LE, then jursidiction = 'federal'
management_level$jurisdiction <- NA
management_level$jurisdiction[which(management_level$fleet=="LE")] <- 'federal'

# if management is OA and mgmt_grp == GROUND, 'both'
# these are open access groundfish. 
# https://www.nwfsc.noaa.gov/research/divisions/fram/observation/data_products/nearshore_gear.cfm
management_level$jurisdiction[which(management_level$fleet=="OA" & 
                                      management_level$mgmt_grp == "GRND")] <- 'both'

# pacific bonito & sandabs: managed at both levels, depends where caught. 
# sandabs in oregon are state, but everywhere else is federal: 
# http://www.seafoodchoices.com/archived%20smartchoices/species_sanddab.php
# bonito is both state and federal: http://www.realgoodfish.com/fish-species
management_level$jurisdiction[which(management_level$fleet=="OA" & 
                                      management_level$mgmt_grp == "CPEL")] <- 'both'

# if management is OA and mgmt_grp == SHRIMP, 'state'
management_level$jurisdiction[which(management_level$fleet=="OA" & 
                                      management_level$mgmt_grp == "SRMP")] <- 'state'

# if management is unknown and mgmt_grp == CRAB, 'state'
management_level$jurisdiction[which(management_level$mgmt_grp == 'CRAB' &
                                      management_level$fleet == 'unknown')] <- 'state'

# if management is unknown and mgmt_grp == 'SAMN', 'federal'
management_level$jurisdiction[which(management_level$mgmt_grp == 'SAMN' &
                                      management_level$fleet == 'unknown')] <- 'federal'

# if management is unknown and mgmt_grp == 'CPEL', 'federal'
management_level$jurisdiction[which(management_level$mgmt_grp == 'CPEL' &
                                      management_level$fleet == 'unknown')] <- 'federal'
# if fleet is unknown and mgmt_grp == 'SRMP', 'state'
management_level$jurisdiction[which(management_level$mgmt_grp == 'SRMP' &
                                      management_level$fleet == 'unknown')] <- 'state'

# if highly migratory, federal
management_level$jurisdiction[which(management_level$mgmt_grp == 'HMSP' &
                                      management_level$fleet == 'unknown')] <- 'federal'

# if highly shellfish, state
management_level$jurisdiction[which(management_level$mgmt_grp == 'SHLL' &
                                      management_level$fleet == 'unknown')] <- 'state'


# if MSC in metier name, mgmt_grp == OTHR, then 'state' (except MSC 23 - CA halibut)
# rest is shellfish, msc inverts
management_level$jurisdiction[which(management_level$mgmt_grp == 'OTHR' &
                                      management_level$fleet == 'unknown' &
                                      grepl('MSC',management_level$metier.2010))] <- 'state'
management_level$jurisdiction[which(management_level$metier.2010=="MSC_23")] <- 'both'

# if pot and unknown fleet, then state
management_level$jurisdiction[which(grepl('POT',management_level$metier.2010) & 
         is.na(management_level$jurisdiction) & management_level$mgmt_grp == 'OTHR')] <- 'state'

# HKL_12 is pacific halibut: federal
management_level$jurisdiction[which(management_level$metier.2010=="HKL_12")] <- 'federal'
# HKL_3 is california halibut: both
management_level$jurisdiction[which(management_level$metier.2010=="HKL_3")] <- 'both'
# HKL_25 is mostly squid: so state
management_level$jurisdiction[which(management_level$metier.2010=="HKL_25")] <- 'state'

# HKL_10 is mostly sandab: so both
# http://www.seafoodchoices.com/archived%20smartchoices/species_sanddab.php
management_level$jurisdiction[which(management_level$metier.2010=="HKL_10")] <- 'both'

# HKL_13 is mostly sheephead: so state
# https://www.wildlife.ca.gov/Conservation/Marine/NFMP
management_level$jurisdiction[which(management_level$metier.2010=="HKL_13")] <- 'state'

# HKL_18 is mostly yellowtail: so federal
# crashed so under federal examination: 
# http://www.pcouncil.org/groundfish/stock-assessments/by-species/yellowtail-rockfish/
management_level$jurisdiction[which(management_level$metier.2010 %in% c("HKL_18","TLS_9"))] <- 'federal'

# HKL_22 barracuda: mostly rec fish, so state
management_level$jurisdiction[which(management_level$metier.2010=="HKL_22")] <- 'federal'

# HKL_7 white seabass: both state but maybe confusing because
# there's a fisheries managemnet plan in place for it that came from outside just the state
#https://caseagrant.ucsd.edu/sites/default/files/wsfmp.pdf
management_level$jurisdiction[which(management_level$metier.2010 %in% c("HKL_7","TLS_6", "NET_8", "TWS_11"))] <- 'state'

# HKL_9: surfperch
# think it's state
# https://www.wildlife.ca.gov/Conservation/Marine/NCCFRMP/Commercial-Surfperch
management_level$jurisdiction[which(management_level$metier.2010=="HKL_9")] <- 'state'

# HKL_17: smelt
# think it's state
# https://www.google.com/search?client=safari&rls=en&q=smelt+commercial+fishery&ie=UTF-8&oe=UTF-8#
# most returns are about state-level fisheries
management_level$jurisdiction[which(management_level$metier.2010 %in% c("HKL_17","NET_10"))] <- 'state'

# HKL_29: unsp octopus
# think it's state due to msc invert
management_level$jurisdiction[which(management_level$metier.2010 %in% c("HKL_29","POT_13"))] <- 'state'

# if fleet = unknown, jurisdiction = NA and mgmt_grp = GRND: both
management_level$jurisdiction[which(management_level$mgmt_grp == 'GRND' &
                                      management_level$fleet == 'unknown' &
                                     is.na(management_level$jurisdiction))] <-  'both'

# if fleet = OA and mgmt_grp = 'SRMP' <- state
management_level$jurisdiction[which(management_level$mgmt_grp == 'SRMP' &
                                      management_level$fleet == 'OA' &
                                      is.na(management_level$jurisdiction))] <-  'state'

# NET_6: california halibut, both
management_level$jurisdiction[management_level$metier.2010 %in% c("NET_6","TWL_2", 
                                                                  "TWS_3", "TLS_5")] <- 'both'

# sea-cucumber: state
management_level$jurisdiction[management_level$metier.2010 %in% c("TWS_4", "NET_9", "TWL_4")] <- 'state'

# other skate with shrimp: both
management_level$jurisdiction[management_level$metier.2010 %in% c("TWS_9")] <- 'both'

# alternative urchins: state
management_level$jurisdiction[management_level$metier.2010 %in% c("NET_15","NET_17")] <- 'state'

# NET_18: eulachon: has gone through management change, so both
management_level$jurisdiction[management_level$metier.2010=="NET_18"] <- 'both'


# NET_20: pacific baraccuda: guessing state
management_level$jurisdiction[management_level$metier.2010=="NET_20"] <- 'state'

# POT_6: hagfish
management_level$jurisdiction[management_level$metier.2010=="POT_6"] <- 'state'

# NET_11: shad, guessing state
management_level$jurisdiction[management_level$metier.2010=="NET_11"] <- 'state'

# if federal then color = dodgerblue, else indianred
management_level$paint <- ifelse(management_level$jurisdiction=='federal','dodgerblue',
                          ifelse(management_level$jurisdiction=='state', 'indianred',
                           ifelse(management_level$jurisdiction=='both', '#6c71c4',
                           NA)))
len_zero = which(lapply(port_list, function(x) length(V(x)))==0)
# check for zero ports
if(length(len_zero)>0){
  port_plots = port_plots[-len_zero]
  port_list = port_list[-which(lapply(port_list, function(x) length(V(x)))==0)]
}

# plot ports ----
for(i in 1:length(port_list)){
  V(port_list[[i]])$paint <- (data.frame(metier.2010 = V(port_list[[i]])$name, 
                                         stringsAsFactors = FALSE) %>% 
                                left_join(management_level[,c("metier.2010", "paint")]))$paint
  
  fn = paste0('Analysis/old_analysis/participation_plots/policy_forum/pcgroup_networks/',pcid$pcgroup[i],'.png')
  png(file=fn, width = 5, height = 5, unit = 'in', res = 300)
  par(bg='transparent',mai=rep(0,4))
  # make relative node size and edge weight for visual clarity
  plot(port_list[[i]],
      # vertex.size = abs(log(V(port_list[[i]])$size/400)), 
      vertex.size = 20,
      edge.width = sqrt(E(port_list[[i]])$weight)/80,
       edge.color = 'grey30',
       vertex.frame.color=NA, layout = layout.auto, 
        vertex.label ="", 
       vertex.color = V(port_list[[i]])$paint, axes = F) 
  dev.off()
}

# calculating beta eff----
# equation 13 from gao et al
# beta eff = average edge weight + symmetry*heterogeneity
# symmetry = 1 for undirected network
# h = variance in edge weight/average edge weight

beta_eff = function(g){
  if(is.null(E(g)$weight)){
    beta_eff = NA
    }else{
    beta_eff = mean(graph.strength(g)) + 
      var(E(g)$weight)/mean(graph.strength(g))
  }
  return(beta_eff)
}

resilience = data.frame(pcgroup = pcid$pcgroup,
           beta_eff = unlist(lapply(port_list, beta_eff)))

resilience$scaled = resilience$beta_eff/max(resilience$beta_eff,na.rm=T)

# plot with spectral for resilience ----

resilience <- left_join(resilience, pcid, by = 'pcgroup')
states <- map_data("state")
ggplot(resilience, aes(x=lon, y = lat, col = beta_eff, label = pcgroup))  + geom_point() + geom_text() + coord_map()

# take bottom 5, medium 5 and top 5

fn = 'Analysis/old_analysis/participation_plots/policy_forum/figures/pcgroup_networks/coastwide.png'
png(file=fn, width = 5, height = 10, unit = 'in', res = 300)
ggplot() + 
  geom_polygon(data = states, aes(x = long, y = lat, group = group), 
               color='#eee8d5', size = .1, fill="#657b83") + 
  geom_point(data = resilience, 
             aes(x = lon, y = lat, color = beta_eff),
             size=3.5, alpha = 1) +
  # geom_text(data = resilience,
  #           aes(x = lon, y = lat, label = pcgroup, color = beta_eff),
  #           size = 3, nudge_x=-.5) +
  coord_map(xlim =range(resilience$lon,na.rm=T) + c(-5,2),
            ylim = range(resilience$lat, na.rm=T) + c(-.5,.5)) + 
  theme_map() + scale_colour_gradient2(low='#f46d43', high ='#66bd63', 
                                       midpoint = 6e06, mid = '#ffffbf') + 
  theme(panel.background = element_rect(fill = '#073642', colour = '#073642'),
        legend.background = element_rect(fill = "#073642", color = "#073642"),
        legend.text = element_text(color = '#eee8d5'), 
        legend.title=element_text(color='#eee8d5'))
dev.off()

