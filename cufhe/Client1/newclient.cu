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
                        cout<<"[LOG] : File Created.\n";
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
                //perror("[ERROR] : connection attempt failed.\n");
		sleep(10);
            	create_connection();
                //exit(EXIT_FAILURE);
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

	    void receive_file(){

            remove("finalkeys/privatekey1.txt");

            fstream file2;

            file2.open("finalkeys/privatekey1.txt", ios::out | ios::trunc | ios::binary);
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

std::string addZeros(string b, int bits){
    for ( int i = b.length(); i < bits; i++ ){
	 b = "0" + b;
    }
    return b;
};

int main(int argc, char const* argv[])
{

    // Generating CT

    cudaSetDevice(0);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    uint32_t kNumSMs = prop.multiProcessorCount;
    int numBits = 32;

    SetSeed();

    // Get Private Key from Key Generation
    Client_socket K;
    K.start_everything(4384, "server");
    K.receive_file();
    K.close_socket();

    PriKey pri_key; // private key

    struct timeval start, end;
    double get_time;


    ReadPriKeyFromFile(pri_key,"finalkeys/privatekey1.txt");


    Stream* st = new Stream[kNumSMs];
    for (int i = 0; i < kNumSMs; i ++)
      st[i].Create();

   // Getting the User Inputs ========================
   int input1, operator_code;
   string sign;

   // Get inputs
   cout << "How many bits do you want: ";
   cin >> numBits;
   
   cout << "What is your first number: ";
   cin >> input1;

   
    Ptxt* pt = new Ptxt[numBits];
    Ptxt* pt1 = new Ptxt[numBits];
    Ptxt* ptRes = new Ptxt[numBits];
    Ctxt* ct = new Ctxt[numBits];
    Ctxt* ct1 = new Ctxt[numBits];
    Ctxt* ctRes = new Ctxt[numBits];
   if ( input1 < 0 ){
	   operator_code = 2;
   } else {
	   operator_code = 1;
   }

   // Conver Decimal to Binary
   string x;

   x = decToBinary(input1);

   // Add the missing zeros
   x = addZeros(x ,numBits);

   for ( int i = 0; i < numBits; i++){
       pt[i] = x[i];
   }

   cout << "\nThe operator code is: " << operator_code << "\n";
    
   for (int i = 0; i < numBits; i ++) {
   	Encrypt(ct[i], pt[i], pri_key);
    }

    Synchronize();

    //-----------------------SENDING DATA OVER----------------------------

    //DUMP CTXT FILES TO SEND
    for (int i = 0; i < numBits; i ++) {
	    string filename = "cipher/ct" + std::to_string(i);
	    WriteCtxtToFile(ct[i],filename);
    }

    remove("cipher/overall");

    // Write Operator Code
    ofstream myfile;
    myfile.open ("cipher/overall");
    myfile << operator_code << "\n";
    myfile.close();

    
    for (int i = 0; i < numBits; i ++) {
	    std::ifstream if_a("cipher/ct"+std::to_string(i),std::ios_base::app);
	    std::ofstream of_c("cipher/overall",std::ios_base::app);
	    of_c << if_a.rdbuf();
    }
    
    gettimeofday(&start, NULL);
    
    // SEND INPUT AND OPERATOR CODE TO SERVER
    Client_socket C;
    C.start_everything(4386, "client");
    C.transmit_file();
    C.close_socket();

    gettimeofday(&end, NULL);
    get_time = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) * 1.0E-6;
    printf("Time taken to send: %lf[sec]\n", get_time);

    gettimeofday(&start, NULL);

    for (int i = 0; i < kNumSMs; i ++)
      st[i].Destroy();

    delete [] st;

    cout<< "\n------ Cleaning Data on GPU(s) ------" <<endl;
    CleanUp(); // essential to clean and deallocate data
    delete [] ct;
    delete [] pt;
    return 0;
}

