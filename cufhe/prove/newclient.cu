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



class Client_socket{
    fstream file;

    int PORT;
    
    int general_socket_descriptor;

    struct sockaddr_in address;
    int address_length;

    public:
        Client_socket(){
	
	};

	void start_everything(int number){
            create_socket();
            PORT = number;

	    cout << "The port is " << PORT << "\n";

            address.sin_family = AF_INET;
            address.sin_port = htons( PORT );
            address_length = sizeof(address);
            if(inet_pton(AF_INET, "69.69.69.1", &address.sin_addr)<=0) { 
                cout<<"[ERROR] : Invalid address\n";
            }

            create_connection();
            
            file.open("cipher/overall", ios::out | ios::trunc | ios::binary);
            if(file.is_open()){
                cout<<"[LOG] : File Creted.\n";
            }
            else{
                cout<<"[ERROR] : File creation failed, Exititng.\n";
                exit(EXIT_FAILURE);
            }
        };

        void create_socket(){
            if ((general_socket_descriptor = socket(AF_INET, SOCK_STREAM, 0)) < 0) { 
                perror("[ERROR] : Socket failed.\n");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Socket Created Successfully.\n";
        }

        void create_connection(){
            if (connect(general_socket_descriptor, (struct sockaddr *)&address, sizeof(address)) < 0) { 
                perror("[ERROR] : connection attempt failed.\n");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Connection Successfull.\n";
        }

        void close_socket(){
	    close(general_socket_descriptor);
	};

        void receive_file(){
            char buffer[2200024] = {};
	    bzero(buffer, sizeof(buffer));
	    int count = 0;
	    while(1){

	            int valread = read(general_socket_descriptor , buffer, 2200024);
		    if(valread == 0)
			    break;
		    file<<buffer;
		    bzero(buffer, sizeof(buffer));
	    };
            cout<<"[LOG] : Saving data to file.\n";
            cout<<"[LOG] : File Saved.\n";
	    file.close();
	    close(general_socket_descriptor);
        }

	void split_file(){
            int count = 0;
	    std::ifstream file("rec.txt");
	    
	    std::string filenames[64];
            for (int i = 0; i < 64; i ++){
                string filename = "Ctxt" + std::to_string(i);
		filenames[i] = filename;
	    };

	    if (file.is_open()) {
    	 	std::string line;
    		while (std::getline(file, line)) {
		      int fileChoice = floor(count/501);
	              ofstream Myfile;
		      Myfile.open(filenames[fileChoice], fstream::app);
		      Myfile << line.c_str() << endl;
		      count += 1; 
	        };
	     };
        };
 
        void transmit_file(){

	    fstream file2;
            
            printf("============================\n");	    
	    file2.open("cipher/overall", ios::in | ios::binary);
            if(file2.is_open()){
                cout<<"[LOG] : Send File is ready to Transmit.\n";
            }
            else{
                cout<<"[ERROR] : File loading failed, Exititng.\n";
                exit(EXIT_FAILURE);
            }

            	    
            std::string contents((std::istreambuf_iterator<char>(file2)), std::istreambuf_iterator<char>());
            cout<<"[LOG] : Transmission Data Size "<<contents.length()<<" Bytes.\n";

            cout<<"[LOG] : Sending...\n";

            int bytes_sent = send(general_socket_descriptor , contents.c_str() , contents.length() , 0 );
            cout<<"[LOG] : Transmitted Data Size "<<bytes_sent<<" Bytes.\n";

            cout<<"[LOG] : File Transfer Complete.\n";	
	}

};


void NandCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = 1 - in0.message_ * in1.message_;
}

int main(int argc, char const* argv[])
{
    int port1 = 4380;
    int port2 = 4381;
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

    Client_socket C;
    C.start_everything(port1);
    C.transmit_file();
    C.close_socket();


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
