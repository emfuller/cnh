#!/bin/sh

# move_movies_remove_jpgs.sh
# 
#
# Created by Ari Strandburg-Peshkin on 7/2/13.
# Copyright 2013 __MyCompanyName__. All rights reserved.


cd /Users/arianasp/Desktop/Baboons/movies/color_by_state/go_to_stop_low_thresh_0.1_high_thresh_0.4/

for f in `ls`;
do(
cd "$f"
mv "$f.mp4" "/Users/arianasp/Desktop/Baboons/movies/color_by_state/go_to_stop_low_thresh_0.1_high_thresh_0.4/$f.mp4"

cd ..
)
done