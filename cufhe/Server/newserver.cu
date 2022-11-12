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
#include<algorithm>
#include<iterator>


#include <include/cufhe_gpu.cuh>
using namespace cufhe;

#include <iostream>
using namespace std;


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

	Xor(ctRes[nBits-1], ctA[nBits-1], ctB[nBits-1]);
	And(carry[0], ctA[nBits-1], ctB[nBits-1]);
	Synchronize();
	for(int i = nBits-2; i > 0; i--) {
		addBits(bitResult, ctA[i], ctB[i], carry);
		Copy(ctRes[i], bitResult[0]);
		Copy(carry[0], bitResult[1]);
		Synchronize();
	}
	Copy(ctRes[0], carry[0]);
	Synchronize();
	delete [] carry;
	delete [] bitResult;
}



void twoComplements(Ctxt *ctRes, Ctxt *ctA, Ctxt *ctB, Ctxt *minusEnd, int nBits){
             
	    Ctxt *twoRes = new Ctxt[nBits];
	
	    // Inverse B
            for(int i = 0; i < nBits; i++){
                Not(ctB[i], ctB[i]);
            }
 
            Synchronize();
 
            // Add One to B
            addNumbers(twoRes, minusEnd, ctB, nBits);
 
            // Add result to A
            addNumbers(ctRes, ctA, twoRes, nBits);

       	    Not(ctRes[0], ctRes[0]);

	    delete [] twoRes;

};

void subNumbers(Ctxt *ctRes, Ctxt *ctA, Ctxt *ctB, int nBits) {
	Ctxt *minusEnd = new Ctxt[nBits];
	
	for(int i = 0; i < nBits; i ++){
	    Copy(minusEnd[i], ctA[0]);
	};

	Not(minusEnd[nBits-1], minusEnd[nBits-1]);

        twoComplements(ctRes, ctA, ctB, minusEnd, nBits);

	delete [] minusEnd;
};

void mulNumbers(Ctxt *ctRes, Ctxt *ctA, Ctxt *ctB, int iBits, int oBits){
	cudaDeviceProp prop;
	cudaGetDeviceProperties(&prop, 0);
	uint32_t kNumSMs = prop.multiProcessorCount;
	Stream* st = new Stream[kNumSMs];
	for (int i = 0; i < kNumSMs; i ++) {
		st[i].Create();
	}

	Ctxt* tempSum = new Ctxt[oBits];
	Ctxt* tempSum2 = new Ctxt[oBits];
	Ctxt* andRes = new Ctxt[iBits];
	Ctxt* empty = new Ctxt[oBits];

	//MAKE IT ZERO
	Ctxt* zero = new Ctxt[1];
	And(zero[0],ctA[0],ctB[0],st[0 % kNumSMs]);
	Xor(zero[0],zero[0],zero[0],st[0 % kNumSMs]);
	Synchronize();

	for(int i=0; i<oBits; i++){
		Copy(tempSum[i],zero[0]);
		Copy(tempSum2[i],zero[0]);
	};

	int co=0;
	int counter=0;
	Synchronize();

	for(int i = iBits-1; i > -1; i--) {
		co=0;
		co=counter;

		Ctxt* andResLeft = new Ctxt[oBits];
		//initalize nresleft to be 'nothing'
		for(int i=0; i<oBits; i++){
			Copy(andResLeft[i],zero[0]);
		}
		Synchronize();

		for(int j = 0; j < iBits; j++) {
			And(andRes[j], ctA[oBits-1-j], ctB[oBits-1-counter], st[j % kNumSMs]);
		}
		Synchronize();

		for(int j = 0; j < iBits; j++) {
			//cout << oBits-1-co;
			Copy(andResLeft[oBits-1-co], andRes[j]);
			co++;
		}
		Synchronize();


                if(counter==0) {
			addNumbers(tempSum, andResLeft, tempSum2, oBits);
		} else {
			addNumbers(tempSum, andResLeft, tempSum, oBits);
		}

		delete [] andResLeft;
		counter++;
		Synchronize();
	}

	for(int i=0; i < oBits; i ++) {
                Copy(ctRes[i], tempSum[i]);
        }
	Synchronize();
	for (int i = 0; i < kNumSMs; i ++)
		st[i].Destroy();
	delete [] st;
	delete [] tempSum;
	delete [] andRes;
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

	void start_everything(int number, int option, string role){
            create_socket();

            PORT = number;

            cout << " The port is: " << PORT << "\n";
	    
	    address.sin_family = AF_INET;
            address.sin_port = htons( PORT );
            address_length = sizeof(address);

	    if ( role == "server" ){

            	address.sin_addr.s_addr = INADDR_ANY;
		bind_socket();
            	set_listen_set();
            	accept_connection();
	    
            } else {

                const char* array[2] ={"192.168.0.5","192.168.0.2"};

                if(inet_pton(AF_INET, array[option], &address.sin_addr)<=0) {
                      cout<<"[ERROR] : Invalid address\n";
                }

                create_connection();
	    }
        }

        void create_socket(){
            if ((general_socket_descriptor = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
                perror("[ERROR] : Socket failed");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Socket Created Successfully.\n";
	    const int enable = 1;
            if (setsockopt(general_socket_descriptor, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int)) < 0)
                   perror("setsockopt(SO_REUSEADDR) failed");
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

        void create_connection(){
            if (connect(general_socket_descriptor, (struct sockaddr *)&address, sizeof(address)) < 0) {
                sleep(10);
                create_connection();
            } else {
                cout<<"[LOG] : Connection Successfull.\n";
            }
        }

        void accept_connection(){
            if ((general_socket_descriptor = accept(general_socket_descriptor, (struct sockaddr *)&address, (socklen_t*)&address_length))<0) {
                perror("[ERROR] : Accept");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Connected to Client.\n";
        }

        void transmit_file(string filename){
            cout << "\nI am transmitting : " << filename << "\n";
            file.open(filename, ios::in | ios::binary);
            if(file.is_open()){
                cout<<"[LOG] : File Created.\n";
            }
            else{
                cout<<"[ERROR] : File creation failed, Exititng.\n";
                exit(EXIT_FAILURE);
            }

            std::string contents((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
            cout<<"[LOG] : Transmission Data Size "<<contents.length()<<" Bytes.\n";

            cout<<"[LOG] : Sending...\n";

            int bytes_sent = send(general_socket_descriptor , contents.c_str() , contents.length() , 0 );
            cout<<"[LOG] : Transmitted Data Size "<<bytes_sent<<" Bytes.\n";

            cout<<"[LOG] : File Transfer Complete.\n";
	    cout<<"===============================\n";
        }

	void close_socket(){
            close(general_socket_descriptor);
	}

	void split_file(int clientID,int numBits){
            int count = 0;
	    std::ifstream file("cipher/overall");

	    std::string filenames[numBits*2];

	    if(clientID==0) {
            	for (int i = 0; i < numBits; i ++){
                	string filename = "cipher/ct" + std::to_string(i);
			remove(filename.c_str());
			filenames[i] = filename;
	    	};
	    } else {
            	for (int i = numBits; i < numBits*2; i ++){
                	string filename = "cipher/ct" + std::to_string(i);
			remove(filename.c_str());
			filenames[i] = filename;
	    	};
	    }

	    if (file.is_open()) {
    	 	std::string line;
    		while (std::getline(file, line)) {
                      if( line.length() == 1){
		           ofstream File;
			   File.open("operator.txt", fstream::app);
			   File << line.c_str() << endl;
			   cout << "\n Reading from file is: " << line.c_str() << "\n"; 
			   File.close();
		      } else {
			   int fileChoice = floor(count/501);
			   if(clientID != 0) {
		           	fileChoice = numBits+floor(count/501);
				
		           }
	              	   ofstream Myfile;
		      	   Myfile.open(filenames[fileChoice], fstream::app);
		      	   Myfile << line.c_str() << endl;
		      	   count += 1;
		      }

	        };
	     };
        };

	void receive_file(string filename){

            file2.open(filename, ios::out | ios::trunc | ios::binary);
            if(file2.is_open()){
                cout<<"[LOG] : Return File Creted.\n";
            }
            else{
                cout<<"[ERROR] : File creation failed, Exititng.\n";
                exit(EXIT_FAILURE);
            }

	    char buffer[2200024] = {};
	    bzero(buffer, sizeof(buffer));
	    printf("Starting to download file contents");
	    while(1){
                    printf("Beginning file contents");
	            int valread = read(general_socket_descriptor , buffer, 2200024);
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

int countLines(string filename) {
	ifstream aFile (filename);
        std::size_t lines_count =0;
        std::string line;
        while (std::getline(aFile, line))
                ++lines_count;
        return lines_count;

}

int main() {
  cudaSetDevice(0);
  cudaDeviceProp prop;
  cudaGetDeviceProperties(&prop, 0);
  uint32_t kNumSMs = prop.multiProcessorCount;
  uint32_t kNumLevels = 4;
  int numBits = 32;

  remove("operator.txt");
  remove("cipher/overall");
  remove("finalkeys/publickey1.txt");


  //RECEIVE OPERATOR FORM VERIF
  Server_socket O;
  O.start_everything(4380,0,"server");
  O.receive_file("operator.txt");

  //SEND OPERATOR OVER
  Server_socket T;
  T.start_everything(4381,0,"client");
  T.transmit_file("operator.txt");

  //RECEIVE KEY FROM KEYGEN
  Server_socket K;
  K.start_everything(4383,0,"server");
  K.receive_file("finalkeys/publickey1.txt");

  //RECEIVE DATA FROM CLIENT1
  Server_socket S;
  S.start_everything(4386,0,"server");
  S.receive_file("cipher/overall");


  int numLines;
  numLines=countLines("cipher/overall");
  numBits = numLines-1;
  numBits = numBits / 501;

  cout << "Nummber of bits in cipher/overall is" << numBits;


  S.split_file(0,numBits);


  //RECEIVE DATA FROM CLIENT2
  Server_socket S10;
  S10.start_everything(4387,1,"server");
  S10.receive_file("cipher/overall");
  S10.split_file(10,numBits);



  Ptxt* pt = new Ptxt[numBits];
  Ptxt* pt1 = new Ptxt[numBits];
  Ptxt* ptRes = new Ptxt[numBits*2];
  Ctxt* ct = new Ctxt[numBits];
  Ctxt* ct1 = new Ctxt[numBits];
  Ctxt* ctRes = new Ctxt[numBits*2];
  Synchronize();


  PubKey pub_key;
  ReadPubKeyFromFile(pub_key,"finalkeys/publickey1.txt");

  cout<< "------ Initilizating Data on GPU(s) ------" <<endl;
  Initialize(pub_key); // essential for GPU computing

  for (int i = 0; i < numBits; i ++) {
	  ReadCtxtFromFile(ct[i],"cipher/ct"+std::to_string(i));
  }

  int countCT=0;
  for (int i = numBits; i < numBits + numBits; i ++) {
	  ReadCtxtFromFile(ct1[countCT],"cipher/ct"+std::to_string(i));
	  countCT++;
  }


  cout<< "Number of bits:\t" << numBits <<endl;
  // Create CUDA streams for parallel gates.
  Stream* st = new Stream[kNumSMs];
  for (int i = 0; i < kNumSMs; i ++)
    st[i].Create();

  Synchronize();


  Ctxt* zero = new Ctxt[numBits];
  Ctxt* temp = new Ctxt[numBits];
  And(zero[numBits-1],ct[0],ct1[0],st[0 % kNumSMs]);
  Xor(zero[numBits-1],zero[0],zero[0],st[0 % kNumSMs]);
  Synchronize();

  Ctxt* one = new Ctxt[1];
  Not(one[0], zero[numBits-1]);

  for ( int i = 0; i < numBits-1; i++ ){
    Copy(zero[i], one[0]);
  };

  std::string p,q,t;
  string operators[3];
  int counter = 0;

  // Read Operator.txt
  ifstream MyReadFile("operator.txt");
  std::string myText;
  while (getline (MyReadFile, myText)) {
     operators[counter] = myText;
     counter += 1;
  }

  p = operators[1];
  q = operators[2];
  t = operators[0];
  cout << "\n The operator is " << t;
  cout << "\n Client 1 is " << p;
  cout << "\n Client 2 is " << q;
  MyReadFile.close(); 

  float et;
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  cudaEventRecord(start, 0);
  //Copy(ctRes[0], one[0]);
  //for (int i=0; i < numBits; i++) 
  	//And(ctRes[i],ct[i],ct1[i],st[i % kNumSMs]);
  
  if ( (p=="1" && q=="1" && t=="1") || (p=="1" && q=="2" && t=="2") ){
      cout << "\n Adding x+y \n";
      addNumbers(ctRes, ct, ct1, numBits);
  }  else if ( (p=="1" && q=="1" && t=="2") || (p=="1" && q=="2" && t=="1") ){
      subNumbers(ctRes, ct, ct1, numBits);
      cout << "\n Subtracting x-y \n";
  }  else if ( (p=="2" && q=="1" && t=="1") || (p=="2" && q=="2" && t=="2") ){
      cout << "\n Subtracting y-x \n";
      subNumbers(ctRes, ct1, ct, numBits);
  }  else if ( (p=="2" && q=="2" && t=="1") || (p=="2" && q=="1"&& t=="2") ){
      cout << "\n Adding -x-y \n";
      addNumbers(ctRes, ct, ct1, numBits);

      for ( int i = 0; i < numBits; i++ ){
            Not(temp[i], ctRes[i]);
      };
      Synchronize();

      addNumbers(ctRes, zero, temp, numBits);
      Not(ctRes[0], ctRes[0]);
  }  else if ( (p=="1" && q=="1" && t=="3") || (p=="2" && q=="2" && t=="3") ){
      cout << "\n x*y \n";
      mulNumbers(ctRes, ct, ct1, (numBits/2), numBits);
  }  else if ( (p=="2" && q=="1" && t=="3") || (p=="1"&& q=="2" && t=="3") ){
      cout << "\n -(x*y) \n";
      mulNumbers(ctRes, ct, ct1, (numBits/2), numBits);

      for ( int i = 0; i < numBits; i++ ){
             Not(temp[i], ctRes[i]);
      };
      Synchronize();

      for ( int i = 0; i < numBits; i ++) {
              Copy(ctRes[i], temp[i]);
      }

      addNumbers(ctRes, zero, temp, numBits);
      Not(ctRes[0], ctRes[0]);
  };
  

  Synchronize();
  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&et, start, stop);
  cout<< et / kNumLevels << " ms to calculate" <<endl;
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
  S1.start_everything(4388,1,"client");
  S1.transmit_file("cipherRes/overall");

  for (int i = 0; i < kNumSMs; i ++)
    st[i].Destroy();
  
  delete [] st;

  cout<< "------ Cleaning Data on GPU(s) ------" <<endl;
  CleanUp(); // essential to clean and deallocate data
  delete [] ct;
  delete [] pt;
  return 0;
}
