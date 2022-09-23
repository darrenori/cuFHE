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
#include <cstring>
#include <include/cufhe_gpu.cuh>
#include<bits/stdc++.h>

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


// function to convert decimal to binary
std::string decToBinary(int n)
{
    std::string r;
    while(n!=0) {r=(n%2==0 ?"0":"1")+r; n/=2;}
    return r;
}

// function to convert binary to decimal
std::string binToDecimal(string s)
{
    unsigned long long value = std::stoull(s, 0, 2);
    std::string str = std::to_string(value);
    return str;
}


string add(string a, string b){
   string result = "";
   int temp = 0;
   int size_a = a.size() - 1;
   int size_b = b.size() - 1;
   while (size_a >= 0 || size_b >= 0 || temp == 1){
      temp += ((size_a >= 0)? a[size_a] - '0': 0);
      temp += ((size_b >= 0)? b[size_b] - '0': 0);
      result = char(temp % 2 + '0') + result;
      temp /= 2;
      size_a--; size_b--;
   }
   return result;
}

// function to convert to Two's Complement
std::string toTwoComplement(string s) {
  
  int size = s.length();
  
  char binary[size + 1], one[size + 1], two[size + 1];
  int i, carry = 1, fail = 0;

  strcpy(binary, s.c_str());

  for (i = 0; i < size; i++) {
    if (binary[i] == '1') {
      one[i] = '0';
    } else if (binary[i] == '0') {
      one[i] = '1';
    }
  }
  one[size] = '\0';

  return add(one,"1");
}


// function to add missing zeros
std::string addZeros(string b, int bits){
   for ( int i = b.length(); i < bits; i++ ){
       b = "0" + b;
   };
   return b;
};


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

	void split_file(int numBits){
            int count = 0;
	    std::ifstream file("cipher/overall");

	    //last one will be for publickey
	    std::string filenames[numBits * 2 + 1];
            for (int i = 0; i < numBits * 2; i ++){
                string filename = "cipher/ct" + std::to_string(i);
		remove(filename.c_str());
		filenames[i] = filename;
	    };

	    filenames[numBits * 2]="finalkeys/publickey1.txt";
	    remove("finalkeys/publickey1.txt");


	    if (file.is_open()) {
    	 	std::string line;
    		while (std::getline(file, line)) {

		      if(count==(501*(numBits*2))){
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
  uint32_t kNumLevels = 4;
  int numBits = 256;
  int port1 = 4380;
  int port2 = 4381;

  SetSeed(); // set random seed


  Ptxt* pt = new Ptxt[numBits];
  Ptxt* pt1 = new Ptxt[numBits];
  Ptxt* ptRes = new Ptxt[numBits];
  Ctxt* ct = new Ctxt[numBits];
  Ctxt* ct1 = new Ctxt[numBits];
  Ctxt* ctRes = new Ctxt[numBits];
  Ctxt *minusEnd = new Ctxt[numBits];

  Synchronize();
  bool correct;
  correct = true;

  PubKey pub_key;
  PriKey pri_key;
  KeyGen(pub_key,pri_key);

  cout<< "------ Initilizating Data on GPU(s) ------" <<endl;
  Initialize(pub_key); // essential for GPU computing

/*
  for (int i = 0; i<numBits; i++){
	  pt[i].message_ = rand() % Ptxt::kPtxtSpace;
	  pt1[i].message_ = rand() % Ptxt::kPtxtSpace;
  }
*/



  // Getting the User Inputs ========================
   unsigned long long input1, input2, operator_code, bits;
   string sign; 
   bool x_neg = false;
   bool y_neg = false;
  
   // Get inputs
   cout << "How many bits do you want: ";
   cin >> bits;
   cout << "What is your first number: ";
   cin >> input1;
   cout << "What is your second number: ";
   cin >> input2;
   cout << "What is your operator: ";
   cin >> sign;

   //cout << "Your equation is: " << input1 << sign << input2 << "\n";

   // Check Negative 
   if (input1 < 0){
       x_neg = true;
   };
   if (input2 < 0){
       y_neg = true;
   };
   
   // Check Addition
   if (sign == "+"){
       if (!x_neg && !y_neg){
	   operator_code = 0;
       } else if (!x_neg && y_neg){
	   operator_code = 1;
       } else if (x_neg && !y_neg){
	   operator_code = 2;
       } else {
	   operator_code = 3;
       };
   };

   // Check Subtraction
   if (sign == "-"){
       if (!x_neg && !y_neg){
	   operator_code = 1;
       } else if (!x_neg && y_neg){
	   operator_code = 0;
       } else if (x_neg && !y_neg){
	   operator_code = 3;
       } else {
	   operator_code = 2;
       };
   };

   // Check Division
   if (sign == "*"){
       if (!x_neg && !y_neg){
	   operator_code = 4;
       } else if (!x_neg && y_neg){
	   operator_code = 5;
       } else if (x_neg && !y_neg){
	   operator_code = 5;
       } else {
	   operator_code = 4;
       };
   };

   
   // Conver Decimal to Binary
   string x, y;

   x = decToBinary(input1);
   y = decToBinary(input2);

   // Add the missing zeros
   x = addZeros(x ,bits);
   y = addZeros(y, bits);

   for ( int i = 0; i < numBits; i++){
       pt[i] = x[i];
       pt1[i] = y[i];
   }
   cout << "\nThe operator code is: " << operator_code << "\n";
   // Write Operator Code 
   ofstream myfile;
   myfile.open ("operator.txt");
   myfile << operator_code;
   myfile.close();

  // ================================================================


  for (int i = 0; i < numBits; i ++) {
        Encrypt(ct[i], pt[i], pri_key);
        Encrypt(ct1[i], pt1[i], pri_key);
  }

/*
  for (int i = 0; i < numBits; i ++) {
	  ReadCtxtFromFile(ct[i],"cipher/ct"+std::to_string(i));
  }

  int countCT=0;
  for (int i = 32; i < numBits + numBits; i ++) {
	  ReadCtxtFromFile(ct1[countCT],"cipher/ct"+std::to_string(i));
	  countCT++;
  }

*/

  //cout<< "Number of tests:\t" << numBits <<endl;
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
  
  Ctxt* zero = new Ctxt[numBits];
  Ctxt* temp = new Ctxt[numBits];
  And(zero[numBits - 1],ct[0],ct1[0],st[0 % kNumSMs]);
  Xor(zero[numBits - 1],zero[0],zero[0],st[0 % kNumSMs]);
  Synchronize();

  Ctxt* one = new Ctxt[1];
  Not(one[0], zero[numBits - 1]);

  for ( int i = 0; i < numBits - 1 ; i++ ){
    Copy(zero[i], one[0]);
  };

  if (operator_code == 0 ){
      addNumbers(ctRes, ct, ct1, numBits);
  } else if ( operator_code == 1){
      subNumbers(ctRes, ct, ct1, numBits);
  } else if ( operator_code == 2){
      subNumbers(ctRes, ct1, ct, numBits);
  } else if ( operator_code == 3){ 
      addNumbers(ctRes, ct, ct1, numBits);

      for ( int i = 0; i < numBits; i++ ){
	    Not(temp[i], ctRes[i]);
      };
      Synchronize();

      addNumbers(ctRes, zero, temp, numBits);
      
      Not(ctRes[0], ctRes[0]);

  } else if ( operator_code == 4){
      mulNumbers(ctRes, ct, ct1, (numBits/2), numBits);
  } else if ( operator_code == 5){
      mulNumbers(ctRes, ct, ct1, (numBits/2), numBits);
     
      for ( int i = 0; i < numBits; i++ ){
             Not(temp[i], ctRes[i]);
      };    
      Synchronize();

      addNumbers(ctRes, zero, temp, numBits);
 
      Not(ctRes[0], ctRes[0]);
  };



  // Here, pass streams to gates for parallel gates.
  // addNumbers(ctRes, ct,ct1,32);
  // mulNumbers(ctRes, ct,ct1,16,32);
  // subNumbers(ctRes, ct, ct1, 32);

  Synchronize();


  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&et, start, stop);
  cout<< et / kNumLevels << " ms for addition" <<endl;
  cudaEventDestroy(start);
  cudaEventDestroy(stop);
/*
    cout << "\nINPUT ONE:\n";
    for (int i=0; i < numBits; i++) {
            cout << pt[i].message_;
    }


    cout << "\nINPUT TWO:\n";
    for (int i=0; i < numBits; i++) {
            cout << pt1[i].message_;
    }
*/
    //subNumbers(ctRes, ct, ct1, 32);

  
    for (int i=0; i < numBits; i++) {
        Decrypt(ptRes[i], ctRes[i], pri_key);
    }
    
    std::string result;

    cout << "\nRESULT:\n";
    for (int i=0; i < numBits; i++) {
            //cout << ptRes[i].message_;
	    result = result + std::to_string(ptRes[i].message_);
    }
    cout << "\n The result is : " << result;
    if(result[0] == '1'){
	result = toTwoComplement(result);
	result = "-" + binToDecimal(result);
    } else {
        result = binToDecimal(result);
    };

    cout << "\n The result is: " << result;

   


  for (int i = 0; i < kNumSMs; i ++)
    st[i].Destroy();
  
  delete [] st;

  cout<< "\n------ Cleaning Data on GPU(s) ------" <<endl;
  CleanUp(); // essential to clean and deallocate data
  delete [] ct;
  delete [] pt;
  return 0;
}
