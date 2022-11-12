#include <stdlib.h>
#include <sys/time.h>
#include <time.h>
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
    int new_socket_descriptor;

    struct sockaddr_in address;
    int address_length;

    public:
        Client_socket(){
	
	};

        void start_everything(int number, string role){
            create_socket();
            PORT = number;

            cout << "The port is " << PORT << "\n";

            address.sin_family = AF_INET;
            address.sin_port = htons( PORT );
            address_length = sizeof(address);

            if ( role == "server" ){

                address.sin_addr.s_addr = INADDR_ANY;
                bind_socket();
                set_listen_set();
                accept_connection();

            } else {

                if(inet_pton(AF_INET, "192.168.0.1", &address.sin_addr)<=0) {
                        cout<<"[ERROR] : Invalid address\n";
                }

                create_connection();

                file.open("rec.txt", ios::out | ios::trunc | ios::binary);
                if(file.is_open()){
                        cout<<"[LOG] : File Creted.\n";
                }
                else{
                        cout<<"[ERROR] : File creation failed, Exititng.\n";
                        exit(EXIT_FAILURE);
                }
            }
        };

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
            if ((general_socket_descriptor = accept(general_socket_descriptor, (struct sockaddr *)&address, (socklen_t*)&address_length))<0) {
                perror("[ERROR] : Accept");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Connected to Client.\n";
        }

        void create_socket(){
            if ((general_socket_descriptor = socket(AF_INET, SOCK_STREAM, 0)) < 0) { 
                perror("[ERROR] : Socket failed.\n");
                exit(EXIT_FAILURE);
            }
            cout<<"[LOG] : Socket Created Successfully.\n";
            const int enable = 1;
            if (setsockopt(general_socket_descriptor, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(int)) < 0)
                   perror("setsockopt(SO_REUSEADDR) failed");

	}

        void create_connection(){
            if (connect(general_socket_descriptor, (struct sockaddr *)&address, sizeof(address)) < 0) { 
		sleep(10);
            	create_connection();
            } else {
            	cout<<"[LOG] : Connection Successfull.\n";
            }
        }

        void close_socket(){
	    close(general_socket_descriptor);
	};

 
        void transmit_file(){

	    fstream file2;
            
            printf("============================\n");	    
	    file2.open("operator.txt", ios::in | ios::binary);
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

        void receive_file(int recvKey){
	    
            fstream file2;

	    if(recvKey==1) {
		    
		remove("finalkeys/privatekey1.txt");
                file2.open("finalkeys/privatekey1.txt", ios::out | ios::trunc | ios::binary);
		    
	    } else {
		   
		remove("cipher/overall");
            	file2.open("cipher/overall", ios::out | ios::trunc | ios::binary);
	    }
	    
            if(file2.is_open()){
               	 cout<<"[LOG] : Return File Creted.\n";
            } else{
                cout<<"[ERROR] : File creation failed, Exititng.\n";
                exit(EXIT_FAILURE);
            }

            char buffer[2200024] = {};
            bzero(buffer, sizeof(buffer));
            //int count = 0;
            printf("Starting to download file contents");
            while(1){
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


	void split_file(){
            int count = 0;
            std::ifstream file("cipher/overall");

            std::string filenames[32];
            for (int i = 0; i < 32; i ++){
                string filename = "cipherRes/ct" + std::to_string(i);
                remove(filename.c_str());
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


};

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

//addition
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

  char binary[size + 1], one[size + 1];
  int i;

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

int main(int argc, char const* argv[])
{
    int port1 = 4380;
    struct sockaddr_in;

    // Generating CT

    cudaSetDevice(0);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    uint32_t kNumSMs = prop.multiProcessorCount;
    //uint32_t kNumLevels = 4;
    int numBits = 32;

    SetSeed();

    Ptxt* pt = new Ptxt[numBits];
    Ptxt* pt1 = new Ptxt[numBits];
    Ptxt* ptRes = new Ptxt[numBits];
    Ctxt* ct = new Ctxt[numBits];
    Ctxt* ct1 = new Ctxt[numBits];
    Ctxt* ctRes = new Ctxt[numBits];

    Stream* st = new Stream[kNumSMs];
    for (int i = 0; i < kNumSMs; i ++)
      st[i].Create();

   // Getting the User Inputs
   int operator_code;
   string sign;
   char input1;

   cout << "What is your operator: ";
   cin >> input1;


   if (input1 == '+'){
       operator_code = 1;
   } else if (input1 == '-') {
       operator_code = 2;
   } else {
       operator_code = 3;
   }

   cout << "\nThe operator code is: " << operator_code << "\n";
    
   Synchronize();

   //-----------------------SENDING DATA OVER----------------------------

   remove("operator.txt");

   // Write Operator Code
   ofstream myfile;
   myfile.open ("operator.txt");
   myfile << operator_code << "\n";
   myfile.close();
    

   //Send Operator Code to Server
   Client_socket C;
   C.start_everything(port1, "client");
   C.transmit_file();
   C.close_socket();


   //-------------------READING BACK DATA FROM SERVER----------------------//

   // Get Private Key from Key Generation
   Client_socket K;
   K.start_everything(4382, "server");
   K.receive_file(1);
   K.close_socket();
   PriKey pri_key;
   ReadPriKeyFromFile(pri_key,"finalkeys/privatekey1.txt");


   //Receive Encrypted Data from Server after is computes
   Client_socket S1;
   S1.start_everything(4388, "server");
   S1.receive_file(0);
   S1.split_file();
   S1.close_socket();

   for (int i = 0; i < numBits; i ++) {
           string filename = "cipherRes/ct" + std::to_string(i);
           ReadCtxtFromFile(ctRes[i],filename);
   }

   //Decrypt Data
   for (int i = 0; i < numBits; i ++) {
     Decrypt(ptRes[i], ctRes[i], pri_key);
   }

    
   std::string result;
   //Print out result
   cout << "\nRESULT:\n";
   for (int i=0; i < numBits; i++) {
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

   cout<< "\n------ Cleaning Data on GPU ------\n";
   CleanUp(); // essential to clean and deallocate data
   delete [] ct;
   delete [] pt;
   return 0;
}
