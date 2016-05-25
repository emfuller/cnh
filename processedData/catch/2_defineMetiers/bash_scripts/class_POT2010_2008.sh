#!/bin/sh
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH -J POT_2010_2008
#SBATCH -t 10:00:00
#SBATCH --mail-user=efuller@princeton.edu
#SBATCH --mail-type=begin
#SBATCH --mail-type=end
#SBATCH --mem=80000

cd /tigress/efuller/raw_infoMap

Rscript 4_knn_classify.R 2010 "POT" 2008 "modified"
