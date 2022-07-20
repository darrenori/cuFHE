// Client side C/C++ program to demonstrate Socket
// programming
#include <arpa/inet.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define PORT 4380
  
#include <include/cufhe_gpu.cuh>
using namespace cufhe;

#include <iostream>
using namespace std;


int main(int argc, char const* argv[])
{
    int sock = 0, valread, client_fd;
    struct sockaddr_in serv_addr;

    // Generating CT

    cudaSetDevice(0);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    uint32_t kNumSMs = prop.multiProcessorCount;
 //   uint32_t kNumTests = kNumSMs * 32;// * 8;
    uint32_t kNumLevels = 4;
    int numBits = 32;

    SetSeed();


    PriKey pri_key; // private key
    PubKey pub_key; // public key
    bool correct = true;

    ReadPriKeyFromFile(pri_key,"finalkeys/privatekey1.txt");
    ReadPubKeyFromFile(pub_key,"finalkeys/publickey1.txt");


    Ptxt* pt = new Ptxt[numBits * 2];
    Ptxt* pt1 = new Ptxt[numBits * 2];
    Ptxt* ptRes = new Ptxt[numBits * 2];
    Ctxt* ct = new Ctxt[numBits * 2];
    Ctxt* ct1 = new Ctxt[numBits * 2];
    Ctxt* ctRes = new Ctxt[numBits * 2];



    Stream* st = new Stream[kNumSMs];
    for (int i = 0; i < kNumSMs; i ++)
      st[i].Create();


    for (int i = 0; i < numBits; i ++) {
      //pt[i] = rand() % Ptxt::kPtxtSpace;
      pt[i] = 0;
      pt[2]=1;
      Encrypt(ct[i], pt[i], pri_key);
    }

    for (int i = 0; i < numBits; i ++) {
      //pt1[i] = rand() % Ptxt::kPtxtSpace;
      pt1[i] = 0;
      pt1[2]=1;
      Encrypt(ct1[i], pt1[i], pri_key);
    }

    Synchronize();

    //DUMP CTXT FILES TO SEND
    for (int i = 0; i < numBits; i ++) {
	    string filename = "cipher/ct" + std::to_string(i);
	    WriteCtxtToFile(ct[i],filename);
    }

    for (int i = 0; i < numBits; i ++) {
	    string filename = "cipher1/ct1" + std::to_string(i);
	    WriteCtxtToFile(ct1[i],filename);
    }



    // End of Generation of CT
    char buffer[1024] = { 0 };
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        printf("\n Socket creation error \n");
        return -1;
    }
  
    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT);
  
    // Convert IPv4 and IPv6 addresses from text to binary
    // form
    if (inet_pton(AF_INET, "69.69.69.1", &serv_addr.sin_addr)
        <= 0) {
        printf(
            "\nInvalid address/ Address not supported \n");
        return -1;
    }
  
    if ((client_fd
         = connect(sock, (struct sockaddr*)&serv_addr,
                   sizeof(serv_addr)))
        < 0) {
        printf("\nConnection Failed \n");
        return -1;
    }


    std::string s = std::to_string(23);
    char const *pchar = s.c_str(); 

    send(sock, pchar, strlen(pchar), 0);
    printf("Sending to server...\n");
    valread = read(sock, buffer, 1024);
    printf("%s\n", buffer);
  
    // closing the connected socket
    close(client_fd);
    return 0;
    
}
