// Client side C/C++ program to demonstrate Socket
// programming
#include <stdlib.h>
#include <arpa/inet.h>
#include <string.h>
#include <cmath>
#include <fstream>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#include <netinet/in.h>

#include <ios>

  
#include <include/cufhe_gpu.cuh>
using namespace cufhe;

#include <iostream>
using namespace std;




class Server_socket{
    fstream file;

    int PORT;

    int general_socket_descriptor;
    int new_socket_descriptor;

    struct sockaddr_in address;
    int address_length;

    public:
        Server_socket(){
            create_socket();
            PORT = 8050;

            address.sin_family = AF_INET;
            address.sin_addr.s_addr = INADDR_ANY;
            address.sin_port = htons( PORT );
            address_length = sizeof(address);

            bind_socket();
            set_listen_set();
            accept_connection();

            file.open("cipher/overall", ios::in | ios::binary);
            if(file.is_open()){
                cout<<"[LOG] : File is ready to Transmit.\n";
            }
            else{
                cout<<"[ERROR] : File loading failed, Exititng.\n";
                exit(EXIT_FAILURE);
            }
        }


	void create_socket(){
            if ((general_socket_descriptor = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
                perror("[ERROR] : Socket failed");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Socket Created Successfully.\n";
        }

        void bind_socket(){
            if (bind(general_socket_descriptor, (struct sockaddr *)&address, sizeof(address))<0) {
                perror("[ERROR] : Bind failed");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Bind Successful.\n";
        }

        void set_listen_set(){
            if (listen(general_socket_descriptor, 3) < 0) {
                perror("[ERROR] : Listen");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Socket in Listen State (Max Connection Queue: 3)\n";
        }

        void accept_connection(){
            if ((new_socket_descriptor = accept(general_socket_descriptor, (struct sockaddr *)&address, (socklen_t*)&address_length))<0) {
                perror("[ERROR] : Accept");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Connected to Client.\n";
        }

        void transmit_file(){
            std::string contents((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
            cout<<"[LOG] : Transmission Data Size "<<contents.length()<<" Bytes.\n";

            cout<<"[LOG] : Sending...\n";

            int bytes_sent = send(new_socket_descriptor , contents.c_str() , contents.length() , 0 );
            cout<<"[LOG] : Transmitted Data Size "<<bytes_sent<<" Bytes.\n";

            cout<<"[LOG] : File Transfer Complete.\n";
        }
};


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





    //-----------------------SENDING DATA OVER----------------------------

    //DUMP CTXT FILES TO SEND
    for (int i = 0; i < numBits; i ++) {
	    string filename = "cipher/ct" + std::to_string(i);
	    WriteCtxtToFile(ct[i],filename);
	    filename = "cipher1/ct" + std::to_string(i);
	    WriteCtxtToFile(ct1[i],filename);
    }

    remove("cipher/overall");
    for (int i = 0; i < numBits; i ++) {
	    std::ifstream if_a("cipher/ct"+std::to_string(i),std::ios_base::app);
	    std::ofstream of_c("cipher/overall",std::ios_base::app);
	    of_c << if_a.rdbuf();
    }

    for (int i = 0; i < numBits; i ++) {
	    std::ifstream if_a("cipher1/ct"+std::to_string(i),std::ios_base::app);
	    std::ofstream of_c("cipher/overall",std::ios_base::app);
	    of_c << if_a.rdbuf();
    }


    Server_socket S;
    S.transmit_file();

    return 0;


    //-------------------READING BACK DATA FROM SERVER----------------------//
    //@RUSSEL HERE
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
