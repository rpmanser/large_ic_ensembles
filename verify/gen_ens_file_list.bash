#!/bin/bash

date_init=$1
date_fcst=$2

rm -f ens_file_list

for mem in `seq 1 42` ; do
	echo /lustre/scratch/rmanser/met/${date_init}/met_${date_fcst}_mem${mem}.nc >> ens_file_list
done
