######In the following I conduct press perturbations of each respondent's food web: 
library(ggplot2)
library(Hmisc)
library(reshape)
library(fpc)
library(vegan)

setwd("~/Dropbox/Projects/In review/Expert Survey/Analysis/R Code")

source('theme_acs.R')
source('multiplot.R')
source('relative change.R')
source('compile expert surveys 070814.R')

all.dat_sp <- all.dat[c(1:14),c(1:14),] #subset out all data but just the species interactions 
ar <- array(dim = c(7,14,dim(all.dat_sp)[3])) #make empty array
dimnames(ar) <- list(c("control","increase_zooplankton","decrease_herring","decrease_pinnipeds","increase_herring","increasewhales","decreasezoopincreasewhale"),names(temp.new)[1:14],respondent.names)

#Hard Code Funciton ideas if time
##Add counter to record which matrix didn't equilibrate?
##add a matrix that records each respondants's max diffvec at stop 
##Add error if matrix has NAs
##hard code tolerance option  with default 10^-5
##Add squashing function: not everyone uses sigmoid

#step 1: determine steady state (SS) for each respondent
#step 2: multiply through differetn vectors for that SS to see outcome of fishing, pred culls, and PDO swings
#step 3: compare the output of the different 

setwd("~/Dropbox/Projects/In review/Expert Survey/Presentations/AMB_Aug2014/Scenario")

####################################################################################################
######## Rescale the matrix to range from -1 to 1 
####################################################################################################

#rescale the data 
all.dat_sp <- all.dat_sp/2 #rescale answers

#all.dat_sp <- all.dat_sp[,,-4] #remove Cathy Rigg 
#respondent.names <- respondent.names[-4]

####################################################################################################
######## Get a matrix of the control values 
####################################################################################################

em_c <- matrix(ncol=14,nrow=length(respondent.names)) #steady state relative abundance
colnames(em_c) <- names(temp.new)[1:14]
rownames(em_c) <- respondent.names

converge <-matrix(0,ncol = 3,nrow=length(respondent.names)) #check the convergence 
colnames(converge) <- c("respondentname","diffvec","nits")

ts_ar <- array(dim = c(1001,14,length(respondent.names))) #make empty array
dimnames(ts_ar) <- list(c(seq(1:1001)),names(temp.new)[1:14],respondent.names)


for(r in 1:dim(all.dat_sp)[3]){  
  
  adj.m = all.dat_sp[,,r] #pull out a single matrix 
  #diag(adj.m) = rep(-1,adj.m,length(diag(adj.m))) #insert density dependence
  diag(adj.m) = rep(0,adj.m,length(diag(adj.m))) #insert no density dependence
  
  max.it <- 1000 #set maximum iterations
  
  emat <- matrix(nrow=(max.it+1),ncol = ncol(adj.m)) #make an empty matrix with species as columns
  emat[1,] <- rep(1,ncol(adj.m)) #define the adjacency matrix (i.e. the perturbation): 1 is no perturb. need to think about strength 
  
  ts_ar[1,,] <- rep(1,ncol(adj.m))
  
  diffvec <- rep(99, ncol(adj.m)) #vctor for estimating differences as matrix converges
  tol <- rep(10^-5,ncol(adj.m)) #set the tolerance for when convergence is defined
  
  for(i in 1:max.it){
    tmpmat <- emat[i,] %*% adj.m #make a temporary matrix to multiply the adjacency vector with the individual respondent's matrix
    emat[i+1,] <- 1/(1+exp(-tmpmat)) #scale 0 to 1 with logit transform
    ts_ar[i+1,,r] <- 1/(1+exp(-tmpmat)) 
    
    if(i!=1){
      diffvec <- abs(emat[i,]-emat[i-1,]) #subtract current row from prev row
      if(max(diffvec) > (10^-5) & i<max.it){ #if statement to stop when the tolerance is met
        print(paste("i=",i))
        print(paste("max(diffvec)=", max(diffvec)))
      }
    }
    if(max(diffvec) <= (10^-5) | i==max.it){
      print(paste("Finished! max(diffvec)=", max(diffvec)))
      converge[r,1] <- respondent.names[r] #pull out the names of the people 
      converge[r,2] <- max(diffvec)
      converge[r,3] <- i
      break
      #i=max.it
    }
  }  
  
  df1 <- data.frame(emat) #make into data frame
  df1 <- subset(df1,df1[,1]!="NA") #subset NAs
  em_c[r,]<- as.numeric(df1[nrow(df1),]) ##Save Equilibrate Value (i.e. last of df)
  ar[1,,r]<- as.numeric(df1[nrow(df1),])
}

# cdf <- data.frame(converge)
# cdf$nits <-as.numeric(as.character(cdf$nits))
# subset(cdf,nits>999)[,1]
# dp <- which(cdf[,3]>999)
# 
# fu_ts <- ts_ar[-1,,dp]
# fu_ts <- melt(fu_ts)
# names(fu_ts) <- c("time","species","respondent","relative.abundance")
# fu_ts <- subset(fu_ts,relative.abundance!="NA")
# ggplot(fu_ts,aes(x=time,y=relative.abundance))+
#          geom_line(aes(colour=species))+
#          facet_wrap(~respondent,scales="free")+
#          theme_acs()


##Below we adapt the previous code to drop the people that don't converge re naming 'respondent.names'

#em_cc <- em_c[-c(dp),] #these are the equilibrium values that converge 
#respondent.names <- respondent.names[-dp]
#all.dat_sp <- all.dat_sp[,,-c(dp)] #cut out bc all converging now


#All Time Series 

ts <- melt(ts_ar[-1,,])
names(ts) <- c("time","species","respondent","relative.abundance")
ts <- subset(ts,relative.abundance!="NA")
gg_tsall = ggplot(ts,aes(x=time,y=relative.abundance))+
  geom_line(aes(colour=species))+
  facet_wrap(~respondent,scales="free")+
  theme_acs()

png(filename = "All Time Series.png",width = 1000, height = 1000)
gg_tsall
dev.off()

#example of each respondent
tshake <- subset(ts,respondent %in% c("Patrick O'Hara", "Dana Haggarty"))
tshake <- subset(tshake,species == "Pacific.Hake.Pacific.Cod.Sablefish")

gg_tshake = ggplot(tshake,aes(x=time,y=relative.abundance))+
  geom_line(aes(colour=species))+
  facet_wrap(~respondent)+
  theme_acs()

gg_tshake

subset(tshake,time==22)
dana.equilib <- subset(tshake,time==22)$relative.abundance[1]
patrick.equilib <- subset(tshake,time==22)$relative.abundance[2]

####################################################################################################
######## Get a matrix of the zooplankton increase: change in tmpmat coding, inserts value each iteration
####################################################################################################
em_z <- matrix(99,ncol=14,nrow=length(respondent.names))
colnames(em_z) <- names(temp.new)[1:14]
rownames(em_z) <- respondent.names

converge_z <- matrix(0,ncol = 3,nrow=length(respondent.names))
colnames(converge_z) <- c("respondentname","diffvec","nits")

ts_ar <- array(dim = c(1001,14,length(respondent.names))) #make empty array
dimnames(ts_ar) <- list(c(seq(1:1001)),names(temp.new)[1:14],respondent.names)

  
for(r in 1:dim(all.dat_sp)[3]){  
  
  adj.m = all.dat_sp[,,r] #pull out a single matrix 
  #diag(adj.m) = rep(-1,adj.m,length(diag(adj.m))) #insert density dependence
  diag(adj.m) = rep(0,adj.m,length(diag(adj.m))) #insert no density dependence
  
  max.it <- 1000 #set maximum iterations
  
  emat <- matrix(nrow=(max.it+1),ncol = ncol(adj.m)) #make an empty matrix with species as columns
  emat[1,] <- rep(1,ncol(adj.m)) #define the adjacency matrix (i.e. the perturbation): 1 is no perturb. need to think about strength 
  emat[1,2] <- 1 #add the zooplankton perturbation (change from 1 to -1)
  ts_ar[1,,] <- rep(1,ncol(adj.m))
  
  diffvec <- rep(99, ncol(adj.m)) #vctor for estimating differences as matrix converges
  tol <- rep(10^-5,ncol(adj.m)) #set the tolerance for when convergence is defined
  
  for(i in 1:max.it){
    tmpmat1 <- emat[i,]
    tmpmat1[2] <- 1 #increase zooplankton  
    tmpmat2 <- tmpmat1 %*% adj.m #make a temporary matrix to multiply the adjacency vector with the individual respondent's matrix
    emat[i+1,] <- 1/(1+exp(-tmpmat2)) #scale 0 to 1 with logit transform
    ts_ar[i+1,,r] <- 1/(1+exp(-tmpmat2)) 
    
    if(i!=1){
      diffvec <- abs(emat[i,]-emat[i-1,]) #subtract current row from prev row
      if(max(diffvec) > (10^-5) & i<max.it){ #if statement to stop when the tolerance is met
        print(paste("i=",i))
        print(paste("max(diffvec)=", max(diffvec)))
      }
    }
    if(max(diffvec) <= (10^-5) | i==max.it){
      print(paste("Finished! max(diffvec)=", max(diffvec)))
      converge_z[r,1] <- respondent.names[r] #pull out the names of the people 
      converge_z[r,2] <- max(diffvec)
      converge_z[r,3] <- i
      break
      #i=max.it
    }
  }  
  
  df1 <- data.frame(emat) #make into data frame
  df1 <- subset(df1,df1[,1]!="NA") #subset NAs
  em_z[r,]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 ##Save Equilibrate Value (i.e. last of df)
  ar[2,,r]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 
}


#example time series of last person in alphabet
names(df1) <- colnames(em_z)
df1$time <- seq(1:length(df1[,1]))
df_ts <- melt(df1,id.vars=c("time"))

df_ts <-subset(df_ts,time!=1)
em_zts <- ggplot(df_ts,aes(x=time,y=value,colour=variable))+
  geom_line()+
  geom_point(size=2)+
  theme_acs()+
  xlim(0,20)+
  xlab("Time")+ylab("Relative Abundance")+
  ggtitle("TS_ZooplanktonIncrease_EG.png")


png(filename = "TS_ZooplanktonDecrease_EG.png",width = 800, height = 500)
em_zts
dev.off()


#All Time Series 

#All Time Series 

ts <- melt(ts_ar[-1,,])
names(ts) <- c("time","species","respondent","relative.abundance")
ts <- subset(ts,relative.abundance!="NA")
gg_tsall = ggplot(ts,aes(x=time,y=relative.abundance))+
  geom_line(aes(colour=species))+
  facet_wrap(~respondent,scales="free")+
  theme_acs()

png(filename = "All Time Series.png",width = 1000, height = 1000)
gg_tsall
dev.off()

#HERRING REDUCTION
####################################################################################################
######## Get a matrix of the Herring  Response note change in tmpmat coding, inserts value each iteration
####################################################################################################

em_h <- matrix(ncol=14,nrow=length(respondent.names))
colnames(em_h) <- names(temp.new)[1:14]
rownames(em_h) <- respondent.names

converge_h <- matrix(0,ncol = 3,nrow=length(respondent.names))
colnames(converge_h) <- c("respondentname","diffvec","nits")

ts_ar <- array(dim = c(1001,14,length(respondent.names))) #make empty array
dimnames(ts_ar) <- list(c(seq(1:1001)),names(temp.new)[1:14],respondent.names)

for(r in 1:dim(all.dat_sp)[3]){  
  
  adj.m = all.dat_sp[,,r] #pull out a single matrix 
  #diag(adj.m) = rep(-1,adj.m,length(diag(adj.m))) #insert density dependence
  diag(adj.m) = rep(0,adj.m,length(diag(adj.m))) #insert no density dependence
  
  max.it <- 1000 #set maximum iterations
  
  emat <- matrix(nrow=(max.it+1),ncol = ncol(adj.m)) #make an empty matrix with species as columns
  emat[1,] <- rep(1,ncol(adj.m)) #define the adjacency matrix (i.e. the perturbation): 1 is no perturb. need to think about strength 
  emat[1,1] <- -1 #add the herring perturbation 
  ts_ar[1,,] <- rep(1,ncol(adj.m))
  
  diffvec <- rep(99, ncol(adj.m)) #vctor for estimating differences as matrix converges
  tol <- rep(10^-5,ncol(adj.m)) #set the tolerance for when convergence is defined
  
  for(i in 1:max.it){
    tmpmat1 <- emat[i,]
    tmpmat1[1] <- -1 #reduce herring 
    tmpmat2 <- tmpmat1 %*% adj.m #make a temporary matrix to multiply the adjacency vector with the individual respondent's matrix
    emat[i+1,] <- 1/(1+exp(-tmpmat2)) #scale 0 to 1 with logit transform
    ts_ar[i+1,,r] <- 1/(1+exp(-tmpmat2)) 
    
    if(i!=1){
      diffvec <- abs(emat[i,]-emat[i-1,]) #subtract current row from prev row
      if(max(diffvec) > (10^-5) & i<max.it){ #if statement to stop when the tolerance is met
        print(paste("i=",i))
        print(paste("max(diffvec)=", max(diffvec)))
      }
    }
    if(max(diffvec) <= (10^-5) | i==max.it){
      print(paste("Finished! max(diffvec)=", max(diffvec)))
      converge_h[r,1] <- respondent.names[r] #pull out the names of the people 
      converge_h[r,2] <- max(diffvec)
      converge_h[r,3] <- i
      break
      #i=max.it
    }
  }  
  
  df1 <- data.frame(emat) #make into data frame
  df1 <- subset(df1,df1[,1]!="NA") #subset NAs
  em_h[r,]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 ##Save Equilibrate Value (i.e. last of df)
  ar[3,,r]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 
}




###Check for and plot non converged time series
cdf <- data.frame(converge_h)
cdf$nits <-as.numeric(as.character(cdf$nits))
subset(cdf,nits>999)[,1]
dp <- which(cdf[,3]>999)
# 
# fu_ts <- ts_ar[-1,,dp]
# fu_ts <- melt(fu_ts)
# names(fu_ts) <- c("time","species","respondent","relative.abundance")
# fu_ts <- subset(fu_ts,relative.abundance!="NA")
# ggplot(fu_ts,aes(x=time,y=relative.abundance))+
#   geom_line(aes(colour=species))+
#   facet_wrap(~respondent)+
#   theme_acs()

#example time series of last person in alphabet
names(df1) <- colnames(em_c)
df1$time <- seq(1:length(df1[,1]))
df_ts <- melt(df1,id.vars=c("time"))

df_ts <-subset(df_ts,time!=1)
em_hts <- ggplot(df_ts,aes(x=time,y=value,colour=variable))+
  geom_line()+
  geom_point(size=2)+
  theme_acs()+
  xlim(0,20)+
  xlab("Time")+ylab("Relative Abundance")+
  ggtitle("TS_HerringDecrease_EG.png")

png(filename = "TS_HerringDecrease_EG.png",width = 800, height = 500)
em_hts
dev.off()

########################################################
########################################Fix Scenario Below Here
########################################################


####################################################################################################
######## Get a matrix of the Pinniped Cull Response
####################################################################################################

em_p <- matrix(ncol=14,nrow=length(respondent.names))
colnames(em_p) <- names(temp.new)[1:14]
rownames(em_p) <- respondent.names


converge_p <- matrix(0,ncol = 3,nrow=length(respondent.names))
colnames(converge_p) <- c("respondentname","diffvec","nits")

ts_ar <- array(dim = c(1001,14,length(respondent.names))) #make empty array
dimnames(ts_ar) <- list(c(seq(1:1001)),names(temp.new)[1:14],respondent.names)

for(r in 1:dim(all.dat_sp)[3]){  
  
  adj.m = all.dat_sp[,,r] #pull out a single matrix 
  #diag(adj.m) = rep(-1,adj.m,length(diag(adj.m))) #insert density dependence
  diag(adj.m) = rep(0,adj.m,length(diag(adj.m))) #insert no density dependence
  
  
  max.it <- 1000 #set maximum iterations
  
  emat <- matrix(nrow=(max.it+1),ncol = ncol(adj.m)) #make an empty matrix with species as columns
  emat[1,] <- rep(1,ncol(adj.m)) #define the adjacency matrix (i.e. the perturbation): 1 is no perturb. need to think about strength 
  emat[1,12] <- -1 #add the pinniped perturbation (change from 1 to -1)
  ts_ar[1,,] <- rep(1,ncol(adj.m))
  
  diffvec <- rep(99, ncol(adj.m)) #vctor for estimating differences as matrix converges
  tol <- rep(10^-5,ncol(adj.m)) #set the tolerance for when convergence is defined
  
  for(i in 1:max.it){
    tmpmat1 <- emat[i,]
    tmpmat1[12] <- -1 #reduce pinnipeds 
    tmpmat2 <- tmpmat1 %*% adj.m #make a temporary matrix to multiply the adjacency vector with the individual respondent's matrix
    emat[i+1,] <- 1/(1+exp(-tmpmat2)) #scale 0 to 1 with logit transform
    ts_ar[i+1,,r] <- 1/(1+exp(-tmpmat2)) 
    
    if(i!=1){
      diffvec <- abs(emat[i,]-emat[i-1,]) #subtract current row from prev row
      if(max(diffvec) > (10^-5) & i<max.it){ #if statement to stop when the tolerance is met
        print(paste("i=",i))
        print(paste("max(diffvec)=", max(diffvec)))
      }
    }
    if(max(diffvec) <= (10^-5) | i==max.it){
      print(paste("Finished! max(diffvec)=", max(diffvec)))
      converge_p[r,1] <- respondent.names[r] #pull out the names of the people 
      converge_p[r,2] <- max(diffvec)
      converge_p[r,3] <- i
      break
      #i=max.it
    }
  }  
  
  df1 <- data.frame(emat) #make into data frame
  df1 <- subset(df1,df1[,1]!="NA") #subset NAs
  em_p[r,]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 ##Save Equilibrate Value (i.e. last of df)
  ar[4,,r]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 
}

###Check for and plot non converged time series
cdf <- data.frame(converge_p)
cdf$nits <-as.numeric(as.character(cdf$nits))
subset(cdf,nits>999)[,1]
dp <- which(cdf[,3]>999)

# fu_ts <- ts_ar[,,dp]
# fu_ts <- melt(fu_ts)
# #names(fu_ts) <- c("time","species","respondent","relative.abundance") #only single person (Cam who isn't working) 
# names(fu_ts) <- c("time","species","relative.abundance")
# fu_ts <- subset(fu_ts,relative.abundance!="NA")
# ggplot(fu_ts,aes(x=time,y=relative.abundance))+
#   geom_line(aes(colour=species))+
# #  facet_wrap(~respondent)+
#   theme_acs()

#example time series of last person in alphabet
names(df1) <- colnames(em_c)
df1$time <- seq(1:length(df1[,1]))
df_ts <- melt(df1,id.vars=c("time"))

df_ts <-subset(df_ts,time!=1)
em_pts <- ggplot(df_ts,aes(x=time,y=value,colour=variable))+
  geom_line()+
  geom_point(size=2)+
  theme_acs()+
  xlim(0,20)+
  xlab("Time")+ylab("Relative Abundance")+
  ggtitle("TS_PinnipedDecrease_EG.png")

png(filename = "TS_PinnipedDecrease_EG.png",width = 800, height = 500)
em_pts
dev.off()

####################################################################################################
######## Get a matrix of the Herring Increase
####################################################################################################

converge_hplus <- matrix(0,ncol = 3,nrow=length(respondent.names))
colnames(converge_hplus) <- c("respondentname","diffvec","nits")


em_hplus <- matrix(ncol=14,nrow=length(respondent.names))
colnames(em_hplus) <- names(temp.new)[1:14]
rownames(em_hplus) <- respondent.names

ts_ar <- array(dim = c(1001,14,length(respondent.names))) #make empty array
dimnames(ts_ar) <- list(c(seq(1:1001)),names(temp.new)[1:14],respondent.names)

for(r in 1:dim(all.dat_sp)[3]){  
  
  adj.m = all.dat_sp[,,r] #pull out a single matrix 
  #diag(adj.m) = rep(-1,adj.m,length(diag(adj.m))) #insert density dependence
  diag(adj.m) = rep(0,adj.m,length(diag(adj.m))) #insert no density dependence
  
  max.it <- 1000 #set maximum iterations
  
  emat <- matrix(nrow=(max.it+1),ncol = ncol(adj.m)) #make an empty matrix with species as columns
  emat[1,] <- rep(1,ncol(adj.m)) #define the adjacency matrix (i.e. the perturbation): 1 is no perturb. need to think about strength 
  emat[1,1] <- 1 #add the herring perturbation to starting values
  ts_ar[1,,] <- rep(1,ncol(adj.m))
  
  diffvec <- rep(99, ncol(adj.m)) #vctor for estimating differences as matrix converges
  tol <- rep(10^-5,ncol(adj.m)) #set the tolerance for when convergence is defined
  
  for(i in 1:max.it){
    tmpmat1 <- emat[i,]
    tmpmat1[1] <- 1 
    tmpmat2 <- tmpmat1 %*% adj.m #make a temporary matrix to multiply the adjacency vector with the individual respondent's matrix
    emat[i+1,] <- 1/(1+exp(-tmpmat2)) #scale 0 to 1 with logit transform
    ts_ar[i+1,,r] <- 1/(1+exp(-tmpmat2)) 
    
    if(i!=1){
      diffvec <- abs(emat[i,]-emat[i-1,]) #subtract current row from prev row
      if(max(diffvec) > (10^-5) & i<max.it){ #if statement to stop when the tolerance is met
        print(paste("i=",i))
        print(paste("max(diffvec)=", max(diffvec)))
      }
    }
    if(max(diffvec) <= (10^-5) | i==max.it){
      print(paste("Finished! max(diffvec)=", max(diffvec)))
      converge_hplus[r,1] <- respondent.names[r] #pull out the names of the people 
      converge_hplus[r,2] <- max(diffvec)
      converge_hplus[r,3] <- i
      break
      #i=max.it
    }
  }  
  
  df1 <- data.frame(emat) #make into data frame
  df1 <- subset(df1,df1[,1]!="NA") #subset NAs
  em_hplus[r,]<-((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 ##Save Equilibrate Value (i.e. last of df)
  ar[5,,r]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 
}

#All Time Series 

ts <- melt(ts_ar[-1,,])
names(ts) <- c("time","species","respondent","relative.abundance")
ts <- subset(ts,relative.abundance!="NA")
gg_tsall = ggplot(ts,aes(x=time,y=relative.abundance))+
  geom_line(aes(colour=species))+
  facet_wrap(~respondent)+
  theme_acs()

png(filename = "All Time Series.png",width = 1000, height = 1000)
gg_tsall
dev.off()


#example of each respondent
tshake <- subset(ts,respondent %in% c("Patrick O'Hara", "Dana Haggarty"))
tshake <- subset(tshake,species == "Pacific.Hake.Pacific.Cod.Sablefish")

df <- data.frame(c(dana.equilib,patrick.equilib),
           c("dana","patrick"))

names(df) <- c("value","respondent")

gg_tshake = ggplot(tshake,aes(x=time,y=relative.abundance))+
  geom_line(aes(colour=respondent))+
  geom_hline(data = df,aes(yintercept = value,colour=respondent,),lty=2)+
  theme_acs()
  

gg_tshake

# ###Check for and plot non converged time series
# cdf <- data.frame(converge_hplus)
# cdf$nits <-as.numeric(as.character(cdf$nits))
# subset(cdf,nits>999)[,1]
# dp <- which(cdf[,3]>999)
# 
# fu_ts <- ts_ar[,,dp]
# fu_ts <- melt(fu_ts)
# #names(fu_ts) <- c("time","species","respondent","relative.abundance")
# names(fu_ts) <- c("time","species","relative.abundance")
# 
# fu_ts <- subset(fu_ts,relative.abundance!="NA")
# ggplot(fu_ts,aes(x=time,y=relative.abundance))+
#   geom_line(aes(colour=species))+
# #  facet_wrap(~respondent)+
#   theme_acs()

#example time series of last person in alphabet
names(df1) <- colnames(em_c)
df1$time <- seq(1:length(df1[,1]))
df_ts <- melt(df1,id.vars=c("time"))

df_ts <-subset(df_ts,time!=1)
em_hplusts <- ggplot(df_ts,aes(x=time,y=value,colour=variable))+
  geom_line()+
  geom_point(size=2)+
  theme_acs()+
  xlim(0,20)+
  xlab("Time")+ylab("Relative Abundance")+
  ggtitle("TS_HerringIncrease_EG.png")


png(filename = "TS_HerringIncrease_EG.png",width = 800, height = 500)
em_hplusts
dev.off()


####################################################################################################
######## Get a matrix of the Whale increase
####################################################################################################

em_w <- matrix(ncol=14,nrow=length(respondent.names))
colnames(em_w) <- names(temp.new)[1:14]
rownames(em_w) <- respondent.names

converge_w <- matrix(0,ncol = 3,nrow=length(respondent.names))
colnames(converge_w) <- c("respondentname","diffvec","nits")

ts_ar <- array(dim = c(1001,14,length(respondent.names))) #make empty array
dimnames(ts_ar) <- list(c(seq(1:1001)),names(temp.new)[1:14],respondent.names)

for(r in 1:dim(all.dat_sp)[3]){  
  
  adj.m = all.dat_sp[,,r] #pull out a single matrix 
  #diag(adj.m) = rep(-1,adj.m,length(diag(adj.m))) #insert density dependence
  diag(adj.m) = rep(0,adj.m,length(diag(adj.m))) #insert no density dependence
  max.it <- 1000 #set maximum iterations
  
  emat <- matrix(nrow=(max.it+1),ncol = ncol(adj.m)) #make an empty matrix with species as columns
  emat[1,] <- rep(1,ncol(adj.m)) #define the adjacency matrix (i.e. the perturbation): 1 is no perturb. need to think about strength 
  emat[1,2] <- 1 #zooplankton increase
  emat[1,13] <- 1 #humpback whale increase
  ts_ar[1,,] <- rep(1,ncol(adj.m))
  
  diffvec <- rep(99, ncol(adj.m)) #vctor for estimating differences as matrix converges
  tol <- rep(10^-5,ncol(adj.m)) #set the tolerance for when convergence is defined
  
  for(i in 1:max.it){
    tmpmat1 <- emat[i,]
    #tmpmat1[2] <- 1 #increase zoops 
    tmpmat1[13] <- 1 #increase humpbacks 
    tmpmat2 <- tmpmat1 %*% adj.m #make a temporary matrix to multiply the adjacency vector with the individual respondent's matrix
    emat[i+1,] <- 1/(1+exp(-tmpmat2)) #scale 0 to 1 with logit transform
    ts_ar[i+1,,r] <- 1/(1+exp(-tmpmat2)) 
    
    if(i!=1){
      diffvec <- abs(emat[i,]-emat[i-1,]) #subtract current row from prev row
      if(max(diffvec) > (10^-5) & i<max.it){ #if statement to stop when the tolerance is met
        print(paste("i=",i))
        print(paste("max(diffvec)=", max(diffvec)))
      }
    }
    if(max(diffvec) <= (10^-5) | i==max.it){
      print(paste("Finished! max(diffvec)=", max(diffvec)))
      converge_w[r,1] <- respondent.names[r] #pull out the names of the people 
      converge_w[r,2] <- max(diffvec)
      converge_w[r,3] <- i
      break
      #i=max.it
    }
  }  
  
  df1 <- data.frame(emat) #make into data frame
  df1 <- subset(df1,df1[,1]!="NA") #subset NAs
  em_w[r,]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 ##Save Equilibrate Value (i.e. last of df)
  ar[6,,r]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 
}

###Check for and plot non converged time series
# cdf <- data.frame(converge_w)
# cdf$nits <-as.numeric(as.character(cdf$nits))
# subset(cdf,nits>999)[,1]
# dp <- which(cdf[,3]>999)
# 
# fu_ts <- ts_ar[,,dp]
# fu_ts <- melt(fu_ts)
# names(fu_ts) <- c("time","species","respondent","relative.abundance")
# fu_ts <- subset(fu_ts,relative.abundance!="NA")
# ggplot(fu_ts,aes(x=time,y=relative.abundance))+
#   geom_line(aes(colour=species))+
#   facet_wrap(~respondent)+
#   theme_acs()


#example time series of last person in alphabet
names(df1) <- colnames(em_c)
df1$time <- seq(1:length(df1[,1]))
df_ts <- melt(df1,id.vars=c("time"))

df_ts <-subset(df_ts,time!=1)
em_wts <- ggplot(df_ts,aes(x=time,y=value,colour=variable))+
  geom_line()+
  geom_point(size=2)+
  theme_acs()+
  xlim(0,20)+
  xlab("Time")+ylab("Relative Abundance")+
  ggtitle("TS_Whale_Increase_EG.png")

png(filename = "TS_WhaleANDZoopIncrease_EG.png",width = 800, height = 500)
em_wts
dev.off()



####################################################################################################
######## Get a matrix of the Whale increase Zoops increase
####################################################################################################

em_w_zneg <- matrix(ncol=14,nrow=length(respondent.names))
colnames(em_w_zneg) <- names(temp.new)[1:14]
rownames(em_w_zneg) <- respondent.names

converge_w_zneg <- matrix(0,ncol = 3,nrow=length(respondent.names))
colnames(converge_w_zneg) <- c("respondentname","diffvec","nits")

ts_ar <- array(dim = c(1001,14,length(respondent.names))) #make empty array
dimnames(ts_ar) <- list(c(seq(1:1001)),names(temp.new)[1:14],respondent.names)

for(r in 1:dim(all.dat_sp)[3]){  
  
  adj.m = all.dat_sp[,,r] #pull out a single matrix 
  #diag(adj.m) = rep(-1,adj.m,length(diag(adj.m))) #insert density dependence
  diag(adj.m) = rep(0,adj.m,length(diag(adj.m))) #insert no density dependence
  
  max.it <- 1000 #set maximum iterations
  
  emat <- matrix(nrow=(max.it+1),ncol = ncol(adj.m)) #make an empty matrix with species as columns
  emat[1,] <- rep(1,ncol(adj.m)) #define the adjacency matrix (i.e. the perturbation): 1 is no perturb. need to think about strength 
  emat[1,2] <- -1 #zooplankton decrease
  emat[1,13] <- 1 #humpback whale increase
  ts_ar[1,,] <- rep(1,ncol(adj.m))
  
  diffvec <- rep(99, ncol(adj.m)) #vctor for estimating differences as matrix converges
  tol <- rep(10^-5,ncol(adj.m)) #set the tolerance for when convergence is defined
  
  for(i in 1:max.it){
    tmpmat1 <- emat[i,]
    tmpmat1[2] <- -1 #decrease zoops 
    tmpmat1[13] <- 1 #increase humpbacks 
    tmpmat2 <- tmpmat1 %*% adj.m #make a temporary matrix to multiply the adjacency vector with the individual respondent's matrix
    emat[i+1,] <- 1/(1+exp(-tmpmat2)) #scale 0 to 1 with logit transform
    ts_ar[i+1,,r] <- 1/(1+exp(-tmpmat2)) 
    
    if(i!=1){
      diffvec <- abs(emat[i,]-emat[i-1,]) #subtract current row from prev row
      if(max(diffvec) > (10^-5) & i<max.it){ #if statement to stop when the tolerance is met
        print(paste("i=",i))
        print(paste("max(diffvec)=", max(diffvec)))
      }
    }
    if(max(diffvec) <= (10^-5) | i==max.it){
      print(paste("Finished! max(diffvec)=", max(diffvec)))
      converge_w_zneg[r,1] <- respondent.names[r] #pull out the names of the people 
      converge_w_zneg[r,2] <- max(diffvec)
      converge_w_zneg[r,3] <- i
      
      break
      #i=max.it
    }
  }  
  
  df1 <- data.frame(emat) #make into data frame
  df1 <- subset(df1,df1[,1]!="NA") #subset NAs
  em_w_zneg[r,]<-((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100  ##Save Equilibrate Value (i.e. last of df)
  ar[7,,r]<- ((as.numeric(df1[nrow(df1),])-ar[1,,r])/ ar[1,,r])*100 
}

# ###Check for and plot non converged time series
# cdf <- data.frame(converge_w_zneg)
# cdf$nits <-as.numeric(as.character(cdf$nits))
# subset(cdf,nits>999)[,1]
# dp <- which(cdf[,3]>999)
# 
# fu_ts <- ts_ar[,,dp]
# fu_ts <- melt(fu_ts)
# names(fu_ts) <- c("time","species","respondent","relative.abundance")
# fu_ts <- subset(fu_ts,relative.abundance!="NA")
# ggplot(fu_ts,aes(x=time,y=relative.abundance))+
#   geom_line(aes(colour=species))+
#   facet_wrap(~respondent)+
#   theme_acs()

#example time series of last person in alphabet
names(df1) <- colnames(em_c)
df1$time <- seq(1:length(df1[,1]))
df_ts <- melt(df1,id.vars=c("time"))

df_ts <-subset(df_ts,time!=1)
em_w_znegts <- ggplot(df_ts,aes(x=time,y=value,colour=variable))+
  geom_line()+
  geom_point(size=2)+
  theme_acs()+
  xlim(0,20)+
  xlab("Time")+ylab("Relative Abundance")+
  ggtitle("TS_WhaleIncreaseANDZoopDecrease_EG.png")

png(filename = "TS_WhaleIncreaseANDZoopDecrease_EG.png",width = 800, height = 500)
em_w_znegts
dev.off()


#multiplot(em_zts,em_hts,em_pts,em_hplusts,em_wts,em_w_znegts,cols=3)


####################################################################################################
######## Save output
####################################################################################################

# ##have a peak at output for just herring response 
# em_c[4,1]
# em_z[4,1]
# em_h[4,1]
# em_p[4,1]
# em_hplus[4,1]
# em_w[4,1]
# em_w_zneg[4,1]
# 
# setwd("/Users/adrianstier/Dropbox/Projects/NOAA Postdoc/Ocean Tipping Points/Research Activities/Case study - Haida Gwaii/Expert Survey/Analysis/R Code")
# save("em_c","em_z","em_h","em_p","em_hplus","em_w","em_w_zneg",file="ScenarioOutput_8_31.RData")




