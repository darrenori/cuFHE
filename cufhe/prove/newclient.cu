// Client side C/C++ program to demonstrate Socket
// programming
#include <arpa/inet.h>
<<<<<<< HEAD
#include <stdlib.h>
#include <arpa/inet.h>
=======
#include <string.h>
#include <cmath>
#include <fstream>
#include <stdlib.h>
#include <unistd.h>
>>>>>>> bc36fd060f54999ccb8fe41a0bed7a8b29624f46
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
<<<<<<< HEAD
#define SIZE 1024
=======
#define SIZE 500000
>>>>>>> bc36fd060f54999ccb8fe41a0bed7a8b29624f46

  
#include <include/cufhe_gpu.cuh>
using namespace cufhe;

#include <iostream>
using namespace std;
void send_file(FILE *fp, int sockfd){
  int n;
  char data[SIZE] = {0};

  while(fgets(data, SIZE, fp) != NULL) {
    if (send(sockfd, data, sizeof(data), 0) == -1) {
      perror("[-]Error in sending file.");
      exit(1);
    }
    bzero(data, SIZE);
  }
}



void send_file(FILE *fp, int sockfd){
  int n;
  char data[SIZE] = {0};

  while(fgets(data, SIZE, fp) != NULL) {
    if (send(sockfd, data, sizeof(data), 0) == -1) {
      perror("[-]Error in sending file.");
      exit(1);
    }
    bzero(data, SIZE);
  }
}


void NandCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = 1 - in0.message_ * in1.message_;
}

int main(int argc, char const* argv[])
{
    int sock = 0, valread, client_fd;
    struct sockaddr_in serv_addr;

    // Generating CT

    cudaSetDevice(0);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    uint32_t kNumSMs = prop.multiProcessorCount;
    //uint32_t kNumLevels = 4;
    int numBits = 32;

    //SetSeed();


    PriKey pri_key; // private key
    bool correct = true;

    ReadPriKeyFromFile(pri_key,"finalkeys/privatekey1.txt");


    Ptxt* pt = new Ptxt[numBits];
    Ptxt* pt1 = new Ptxt[numBits];
    Ptxt* ptRes = new Ptxt[numBits];
    Ctxt* ct = new Ctxt[numBits];
    Ctxt* ct1 = new Ctxt[numBits];
    Ctxt* ctRes = new Ctxt[numBits];



    Stream* st = new Stream[kNumSMs];
    for (int i = 0; i < kNumSMs; i ++)
      st[i].Create();


    for (int i = 0; i < numBits; i ++) {
 	pt[i] = 0;
      	pt1[i] = 0;
   	Encrypt(ct[i], pt[i], pri_key);
      	Encrypt(ct1[i], pt1[i], pri_key);
    }


    Synchronize();





/*
    //-----------------------SENDING DATA OVER----------------------------

    //DUMP CTXT FILES TO SEND
    for (int i = 0; i < numBits; i ++) {
	    string filename = "cipher/ct" + std::to_string(i);
	    WriteCtxtToFile(ct[i],filename);
    }

    for (int i = 0; i < numBits; i ++) {
	    string filename = "cipher1/ct" + std::to_string(i);
	    WriteCtxtToFile(ct1[i],filename);
    }


<<<<<<< HEAD

    // Change this IP
  char *ip = "69.69.69.1";
  // Change this host port
  int port = 4380;
  int e;

  int sockfd;
  struct sockaddr_in server_addr;
  FILE *fp;
  // Change this file name and file path if you need
  char *filename = "send.txt";

  sockfd = socket(AF_INET, SOCK_STREAM, 0);
  if(sockfd < 0) {
    perror("[-]Error in socket");
    exit(1);
  }
  printf("[+]Server socket created successfully.\n");
 
  server_addr.sin_family = AF_INET;
  server_addr.sin_port = port;
  server_addr.sin_addr.s_addr = inet_addr(ip);

  e = connect(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr));
  if(e == -1) {
    perror("[-]Error in socket");
    exit(1);
  }
        printf("[+]Connected to Server.\n");

  fp = fopen(filename, "r");
  if (fp == NULL) {
    perror("[-]Error in reading file.");
    exit(1);
  }

  send_file(fp, sockfd);
  printf("[+]File data sent successfully.\n");

=======
    remove("cipher/overall");
    for (int i=0; i< numBits; i++) {
	    std::ifstream if_a("cipher/ct"+std::to_string(i), std::ios_base::app);
	    std::ofstream of_a("cipher/overall", std::ios_base::app);
	    of_a << if_a.rdbuf();
    }
    for (int i=0; i< numBits; i++) {
	    std::ifstream if_a("cipher1/ct"+std::to_string(i), std::ios_base::app);
	    std::ofstream of_a("cipher/overall", std::ios_base::app);
	    of_a << if_a.rdbuf();
    }
*/

/*

    // Change this IP
  char *ip = "69.69.69.1";
  // Change this host port
  int port = 4380;
  int e;

  int sockfd;
  struct sockaddr_in server_addr;
  FILE *fp;
  // Change this file name and file path if you need
  char *filename = "cipher/overall";

  sockfd = socket(AF_INET, SOCK_STREAM, 0);
  if(sockfd < 0) {
    perror("[-]Error in socket");
    exit(1);
  }
  printf("[+]Server socket created successfully.\n");

  server_addr.sin_family = AF_INET;
  server_addr.sin_port = port;
  server_addr.sin_addr.s_addr = inet_addr(ip);

  e = connect(sockfd, (struct sockaddr*)&server_addr, sizeof(server_addr));
  if(e == -1) {
    perror("[-]Error in socket");
    exit(1);
  }
        printf("[+]Connected to Server.\n");

  fp = fopen(filename, "r");
  if (fp == NULL) {
    perror("[-]Error in reading file.");
    exit(1);
  }

  send_file(fp, sockfd);
  printf("[+]File data sent successfully.\n");

>>>>>>> bc36fd060f54999ccb8fe41a0bed7a8b29624f46
        printf("[+]Closing the connection.\n");
  close(sockfd);




  */


    //-------------------READING BACK DATA FROM SERVER----------------------//
    for (int i = 0; i < numBits; i ++) {
            string filename = "cipherRes/ct" + std::to_string(i);
            ReadCtxtFromFile(ctRes[i],filename);
    }


    //READ COMPUTED DATA FROM SERVER HERE!
    int cnt_failures = 0;
    for (int i = 0; i < numBits; i ++) {
      NandCheck(ptRes[i], pt[i], pt1[i]);
      Decrypt(pt1[i], ctRes[i], pri_key);
      if (pt1[i].message_ != ptRes[i].message_) {
        std::cout << "FAILED" << pt1[i].message_ << "||" <<ptRes[i].message_ << "\n";
        correct = false;
        cnt_failures += 1;
        //std::cout<< "Fail at iteration: " << i <<std::endl;
      }
    }


    if (correct)
      cout<< "PASS" <<endl;
    else
      cout<< "FAIL:\t" << cnt_failures << "/" << numBits <<endl;
    for (int i = 0; i < kNumSMs; i ++)
      st[i].Destroy();

    delete [] st;

    cout<< "------ Cleaning Data on GPU(s) ------" <<endl;
    CleanUp(); // essential to clean and deallocate data
    delete [] ct;
    delete [] pt;
    return 0;


}
