/**
 * Copyright 2018 Wei Dai <wdai3141@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

// Include these two files for GPU computing.
#include<iostream>
#include<fstream>
#include<stdio.h>
#include <unistd.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <strings.h>
#include <string>
#include <cmath>



#include <include/cufhe_gpu.cuh>
using namespace cufhe;

#include <iostream>
using namespace std;

void NandCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = 1 - in0.message_ * in1.message_;
}

void OrCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = (in0.message_ + in1.message_) > 0;
}

void AndCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = in0.message_ * in1.message_;
}

void XorCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = (in0.message_ + in1.message_) & 0x1;
}

void NotCheck(Ptxt& out, const Ptxt& in) {
	out.message_ = (~in.message_) & 0x1;
}

void CopyCheck(Ptxt& out, const Ptxt& in){
	out.message_ = in.message_;
}


void addBits(Ctxt *r, Ctxt &a, Ctxt &b, Ctxt *carry) {
        Ctxt *t1 = new Ctxt[1];
    Ctxt *t2 = new Ctxt[1];
        Xor(t1[0], a, carry[0]);
    Xor(t2[0], b, carry[0]);
        Synchronize();
        Xor(r[0], a, t2[0]);
        And(t1[0], t1[0], t2[0]);
        Synchronize();
        Xor(r[1], carry[0], t1[0]);
        Synchronize();
        delete [] t1;
        delete [] t2;
}

void addNumbers(Ctxt *ctRes, Ctxt *ctA, Ctxt *ctB, int nBits) {


        Ctxt *carry = new Ctxt[1];
    Ctxt *bitResult = new Ctxt[2];

        Xor(ctRes[31], ctA[31], ctB[31]);
        And(carry[0], ctA[31], ctB[31]);
        Synchronize();
        for(int i = 30; i > 0; i--) {
                addBits(bitResult, ctA[i], ctB[i], carry);
                Copy(ctRes[i], bitResult[0]);
                Copy(carry[0], bitResult[1]);
                Synchronize();
        }
        Copy(ctRes[0], carry[0]);
        //Copy(ctRes[nBits-1],carry[0]);

        Synchronize();
        delete [] carry;
        delete [] bitResult;
}




class Server_socket{

    fstream file;
    fstream file2;

    int PORT;
    int check;

    int general_socket_descriptor;
    int new_socket_descriptor;
    struct sockaddr_in address;
    int address_length;

    public:
        Server_socket(){

	};

	void start_everything(int number){
            create_socket();

            PORT = number;

            cout << " The port is: " << PORT << "\n";
	    address.sin_family = AF_INET;
            address.sin_addr.s_addr = INADDR_ANY;
            address.sin_port = htons( PORT );
            address_length = sizeof(address);

            bind_socket();
            set_listen_set();
            accept_connection();

            file.open("cipherRes/overall", ios::in | ios::binary);
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
            if (bind(general_socket_descriptor, (struct sockaddr *)&address, sizeof(address))!=0) {

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
	    cout<<"===============================\n";
        }

	void close_socket(){
            close(new_socket_descriptor);
	}

	void split_file(){
            int count = 0;
	    std::ifstream file("cipher/overall");

	    //last one will be for publickey
	    std::string filenames[65];
            for (int i = 0; i < 64; i ++){
                string filename = "cipher/ct" + std::to_string(i);
		remove(filename.c_str());
		filenames[i] = filename;
	    };

	    filenames[64]="finalkeys/publickey1.txt";
	    remove("finalkeys/publickey1.txt");


	    if (file.is_open()) {
    	 	std::string line;
    		while (std::getline(file, line)) {

		      if(count==(501*64)){
	    	      	ofstream pubkey;
                      	pubkey.open("finalkeys/publickey1.txt",fstream::app);
	              	pubkey << line.c_str() << endl;

		      } else {
		      	int fileChoice = floor(count/501);
	              	ofstream Myfile;
		      	Myfile.open(filenames[fileChoice], fstream::app);
		      	Myfile << line.c_str() << endl;
		      	count += 1;

		      }

	        };
	     };
        };

	void receive_file(){

            file2.open("cipher/overall", ios::out | ios::trunc | ios::binary);
            if(file2.is_open()){
                cout<<"[LOG] : Return File Creted.\n";
            }
            else{
                cout<<"[ERROR] : File creation failed, Exititng.\n";
                exit(EXIT_FAILURE);
            }

	    char buffer[2200024] = {};
	    bzero(buffer, sizeof(buffer));
	    int count = 0;
	    printf("Starting to download file contents");
	    while(1){
                    printf("Beginning file contents");
	            int valread = read(new_socket_descriptor , buffer, 2200024);
		    printf("%d",valread);
		    if(valread == 0)
			    break;
		    printf("%s", buffer);
		    file2<<buffer;
		    bzero(buffer, sizeof(buffer));
	    };
            cout<<"[LOG] : Saving data to file.\n";
            cout<<"[LOG] : File Saved.\n";
	    file2.close();

	    };


};

int main() {
  cudaSetDevice(0);
  cudaDeviceProp prop;
  cudaGetDeviceProperties(&prop, 0);
  uint32_t kNumSMs = prop.multiProcessorCount;
 // uint32_t kNumTests = kNumSMs * 32;// * 8;
  uint32_t kNumLevels = 4;
 // uint32_t val1 = 1;
 // uint32_t val2 = 2;
  int numBits = 32;
  int port1 = 4380;
  int port2 = 4381;

  //SetSeed(); // set random seed


  remove("cipher/overall");

  Ptxt* pt = new Ptxt[numBits];
  Ptxt* pt1 = new Ptxt[numBits];
  Ptxt* ptRes = new Ptxt[numBits];
  Ctxt* ct = new Ctxt[numBits];
  Ctxt* ct1 = new Ctxt[numBits];
  Ctxt* ctRes = new Ctxt[numBits];
  Synchronize();
  bool correct;
  correct = true;

  //RECEIVE DATA FROM CLIENT!
  Server_socket S;
  S.start_everything(port1);
  S.receive_file();
  S.split_file();



  PubKey pub_key;
  ReadPubKeyFromFile(pub_key,"finalkeys/publickey1.txt");

  cout<< "------ Initilizating Data on GPU(s) ------" <<endl;
  Initialize(pub_key); // essential for GPU computing





  for (int i = 0; i < numBits; i ++) {
	  ReadCtxtFromFile(ct[i],"cipher/ct"+std::to_string(i));
  }

  int countCT=0;
  for (int i = 32; i < numBits + numBits; i ++) {
	  ReadCtxtFromFile(ct1[countCT],"cipher/ct"+std::to_string(i));
	  countCT++;
  }


  cout<< "Number of tests:\t" << numBits <<endl;
  // Create CUDA streams for parallel gates.
  Stream* st = new Stream[kNumSMs];
  for (int i = 0; i < kNumSMs; i ++)
    st[i].Create();


  Synchronize();





  float et;
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  cudaEventRecord(start, 0);


  // Here, pass streams to gates for parallel gates.
  addNumbers(ctRes, ct,ct1,32);
  /*
  cout<< "------ Test NAND Gate ------" <<endl;
  for (int i = 0; i < numBits; i ++) {
    Nand(ctRes[i], ct[i], ct1[i], st[i % kNumSMs]);
  }
*/
  Synchronize();
  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&et, start, stop);
  cout<< et / kNumLevels << " ms for addition" <<endl;
  cudaEventDestroy(start);
  cudaEventDestroy(stop);


  string fname;
  remove("cipherRes/overall");
  for (int i = 0; i < numBits; i ++) {
	  fname = "cipherRes/ct"+std::to_string(i);
	  remove(fname.c_str());
	  WriteCtxtToFile(ctRes[i],fname);
  }
  
  //only 32 files for cipheres
  for (int i = 0; i < numBits; i ++) {
            std::ifstream if_a("cipherRes/ct"+std::to_string(i),std::ios_base::app);
            std::ofstream of_c("cipherRes/overall",std::ios_base::app);
            of_c << if_a.rdbuf();
  }

  Server_socket S1;
  S1.start_everything(port2);
  S1.transmit_file();

  for (int i = 0; i < kNumSMs; i ++)
    st[i].Destroy();
  
  delete [] st;

  cout<< "------ Cleaning Data on GPU(s) ------" <<endl;
  CleanUp(); // essential to clean and deallocate data
  delete [] ct;
  delete [] pt;
  return 0;
}
