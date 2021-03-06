# make trip table, calcluate pairwise distance, find nearest neighbors,
# assign group!
assign_trips <- function(ticket_data=filtered_ftl, 
                         training_list=train, classify_list=classify, k=1){
  
  # subset to training and test data
  cat("subset to training and test data\n")
  sub_data <- subset(ticket_data, trip_id %in% 
                       c(training_list$trip_id, classify_list))
  
  # make trip table
  cat("make trip table\n")
  melt_ftl <- select(sub_data, trip_id, spid, landed_wt)
  melt_ftl <- melt(melt_ftl, id.vars = c("trip_id", "spid"), 
                   measure.vars = "landed_wt")
  
  cast_ftl <- dcast(melt_ftl, trip_id ~ spid, fun.aggregate = sum)
  rownames(cast_ftl) <- cast_ftl$trip_id
  cast_ftl$trip_id <- NULL
  
  # find indexes that are training data and test data
  cat("find indexes that are training and test data\n")
  design.set <- which(rownames(cast_ftl) %in% training_list$trip_id) 
  test.set <- setdiff(1:nrow(cast_ftl), design.set)
  
  # find metiers for test set
  cat("find metiers for test set\n")
  ref_metier <- data.frame(trip_id = rownames(cast_ftl))
  ref_metier <- merge(ref_metier, training_list[,c("metier","trip_id")], 
                      all.x = TRUE)  
  y = ref_metier$metier
  
  # calculate distance from all points
  cat("calculate distance from all points\n")
  d <- as.matrix(vegdist(cast_ftl))
  
  # find nearest neighbor
  cat("find nearest neighbor\n")
  NN <- apply(d[test.set, design.set], 1, order)
  # predict group membership
  cat("predict group membership\n")
  pred <- apply(NN[1:k, , drop=FALSE], 2, function(nn){
    tab <- table(y[design.set][nn])
    names(which.max(tab))
  })
  
  predicted_group <- data.frame(trip_id = rownames(cast_ftl)[test.set], 
                                predicted_metier = pred)
  
  return(predicted_group)
}
