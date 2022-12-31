#!/bin/bash
#note that you should change this accordingly for bashrc and below
cd /root/cuFHE/cufhe/
make

dire="prove"
nvcc -c $dire/newclient.cu
nvcc -std=c++11 -O3 -w  -I./ -M -o $dire/test_api_gpu.d $dire/newclient.cu
nvcc -std=c++11 -O3 -w  -I./ -c -o $dire/newclient.o $dire/newclient.cu
nvcc -std=c++11 -O3 -w  -o $dire/newclient $dire/newclient.o -Lbin -lcufhe_gpu

dire="Client1"
nvcc -c $dire/client1.cu
nvcc -std=c++11 -O3 -w  -I./ -M -o $dire/test_api_gpu.d $dire/client1.cu
nvcc -std=c++11 -O3 -w  -I./ -c -o $dire/client1.o $dire/client1.cu
nvcc -std=c++11 -O3 -w  -o $dire/client1 $dire/client1.o -Lbin -lcufhe_gpu

dire="Client2"
nvcc -c $dire/client2.cu
nvcc -std=c++11 -O3 -w  -I./ -M -o $dire/test_api_gpu.d $dire/client2.cu
nvcc -std=c++11 -O3 -w  -I./ -c -o $dire/client2.o $dire/client2.cu
nvcc -std=c++11 -O3 -w  -o $dire/client2 $dire/client2.o -Lbin -lcufhe_gpu

dire="Client2"
nvcc -c $dire/client2.cu
nvcc -std=c++11 -O3 -w  -I./ -M -o $dire/test_api_gpu.d $dire/client2.cu
nvcc -std=c++11 -O3 -w  -I./ -c -o $dire/client2.o $dire/client2.cu
nvcc -std=c++11 -O3 -w  -o $dire/client2 $dire/client2.o -Lbin -lcufhe_gpu

dire="Keygen"
nvcc -c $dire/keygen.cu
nvcc -std=c++11 -O3 -w  -I./ -M -o $dire/test_api_gpu.d $dire/keygen.cu
nvcc -std=c++11 -O3 -w  -I./ -c -o $dire/keygen.o $dire/keygen.cu
nvcc -std=c++11 -O3 -w  -o $dire/keygen $dire/keygen.o -Lbin -lcufhe_gpu

dire="Verif"
nvcc -c $dire/verif.cu
nvcc -std=c++11 -O3 -w  -I./ -M -o $dire/test_api_gpu.d $dire/verif.cu
nvcc -std=c++11 -O3 -w  -I./ -c -o $dire/verif.o $dire/verif.cu
nvcc -std=c++11 -O3 -w  -o $dire/verif $dire/verif.o -Lbin -lcufhe_gpu

dire="Server"
nvcc -c $dire/newserver.cu
nvcc -std=c++11 -O3 -w  -I./ -M -o $dire/test_api_gpu.d $dire/newserver.cu
nvcc -std=c++11 -O3 -w  -I./ -c -o $dire/newserver.o $dire/newserver.cu
nvcc -std=c++11 -O3 -w  -o $dire/newserver $dire/newserver.o -Lbin -lcufhe_gpu