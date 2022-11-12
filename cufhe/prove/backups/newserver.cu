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



void twoComplements(Ctxt *ctRes, Ctxt *ctA, Ctxt *ctB, Ctxt *minusEnd, int nBits){
             
	    Ctxt *twoRes = new Ctxt[nBits];
	
	    // Inverse B
            for(int i = 0; i < 32; i++){
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

void testing(Ctxt *ctRes, Ctxt *test){
	for ( int i = 0; i < 32; i++){
		Copy(ctRes[i], test[i]);
	};
};

void subNumbers(Ctxt *ctRes, Ctxt *ctA, Ctxt *ctB, int nBits) {

        // This equation will have ctB to ALWAYS be negative and ctA ALWAYS postive
	
	Ctxt *minusEnd = new Ctxt[nBits];
	
	for(int i = 0; i < 32; i ++){
	    Copy(minusEnd[i], ctA[0]);
	};

	Not(minusEnd[31], minusEnd[31]);

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

//	for(int i=0; i<oBits; i++){
//		Copy(empty[i],zero[0]);
//	}

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


		for(int j = 0; j < iBits; j++) {
			And(andRes[j], ctA[oBits-1-j], ctB[oBits-1-counter], st[j % kNumSMs]);
		}
		Synchronize();

		//cout << "\nCO\n";
		for(int j = 0; j < iBits; j++) {
			//cout << oBits-1-co;
			Copy(andResLeft[oBits-1-co], andRes[j]);
			co++;
		}

		Synchronize();

		

                if(counter==0) {

			addNumbers(tempSum, andResLeft, tempSum2, oBits);
			Synchronize();
		} else {
			addNumbers(tempSum, andResLeft, tempSum, oBits);
			Synchronize();
		}


		delete [] andResLeft;
		counter++;

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
                      if( line.length() == 1){
		           ofstream File;
			   File.open("operator.txt", fstream::app);
			   File << line.c_str() << endl;
			   cout << "\n Reading from file is: " << line.c_str() << "\n";
		      } else {
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
                    // printf("Beginning file contents");
	            int valread = read(new_socket_descriptor , buffer, 2200024);
		    // printf("%d",valread);
		    if(valread == 0)
			    break;
                    // printf("%s", buffer);
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

  remove("operator.txt");
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

  Ctxt* zero = new Ctxt[32];
  Ctxt* temp = new Ctxt[32];
  And(zero[31],ct[0],ct1[0],st[0 % kNumSMs]);
  Xor(zero[31],zero[0],zero[0],st[0 % kNumSMs]);
  Synchronize();

  Ctxt* one = new Ctxt[1];
  Not(one[0], zero[31]);

  for ( int i = 0; i < 31; i++ ){
    Copy(zero[i], one[0]);
  };

  std::string operator_code;
  ifstream MyReadFile("operator.txt");
  std::string myText;
  while (getline (MyReadFile, myText)) {
     operator_code = myText;
  }
  MyReadFile.close(); 
  
  cout << "\n The operator code is: " << operator_code << "\n";

  if (operator_code == "0" ){
      addNumbers(ctRes, ct, ct1, 32);
  } else if ( operator_code == "1"){

      subNumbers(ctRes, ct, ct1, 32);
  } else if ( operator_code == "2"){
      subNumbers(ctRes, ct1, ct, 32);
  } else if ( operator_code == "3"){
      addNumbers(ctRes, ct, ct1, 32);
      for ( int i = 0; i < 32; i++ ){
	    Not(temp[i], ctRes[i]);
      };
      Synchronize();

      addNumbers(ctRes, zero, temp, 32);

      Not(ctRes[0], ctRes[0]);

  } else if ( operator_code == "4"){
      mulNumbers(ctRes, ct, ct1, (32/2), 32);
  } else if ( operator_code == "5"){
      
      mulNumbers(ctRes, ct, ct1, (32/2), 32);

      for ( int i = 0; i < 32; i++ ){
             Not(temp[i], ctRes[i]);
      };

      Synchronize();

      for ( int i = 0; i < 32; i ++) {
	      Copy(ctRes[i], temp[i]);
      }

      addNumbers(ctRes, zero, temp, 32);

      Not(ctRes[0], ctRes[0]);
/*
      for ( int i = 0; i < 32; i ++ ){
	      Copy(ctRes[i], zero[i]); 
      }
*/
  };
  
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