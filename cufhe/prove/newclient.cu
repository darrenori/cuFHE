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

    SetSeed();


    PriKey pri_key; // private key
    bool correct = true;

    ReadPriKeyFromFile(pri_key,"finalkeys/privatekey1.txt");


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
      Encrypt(ct[i], pt[i], pri_key);
    }

    for (int i = 0; i < numBits; i ++) {
      //pt1[i] = rand() % Ptxt::kPtxtSpace;
      pt1[i] = 0;
      Encrypt(ct1[i], pt1[i], pri_key);
    }

    Synchronize();















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
    



















    //-------------------READING BACK DATA FROM SERVER----------------------//
    for (int i = 0; i < numBits; i ++) {
            string filename = "cipherresult/ct" + std::to_string(i);
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
