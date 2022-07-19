#!/bin/bash

#read -p "Enter a directory: " dire
dire="prove";
cd /root/cuFHE/cufhe/
make

nvcc -c $dire/test_api_gpu.cu

nvcc -std=c++11 -O3 -w  -I./ -M -o $dire/test_api_gpu.d $dire/test_api_gpu.cu
nvcc -std=c++11 -O3 -w  -I./ -c -o $dire/test_api_gpu.o $dire/test_api_gpu.cu
nvcc -std=c++11 -O3 -w  -o $dire/test_api_gpu $dire/test_api_gpu.o -Lbin -lcufhe_gpu

#clear
#./prove/test_api_gpu
