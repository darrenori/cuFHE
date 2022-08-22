#include <stdlib.h>
#include <arpa/inet.h>
#include <string.h>
#include <cmath>
#include <fstream>
#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <string>
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

	void start_everything(int number, int option, string role){
            create_socket();
            PORT = number;
	    //int new_socket_descriptor;

            address.sin_family = AF_INET;
            address.sin_port = htons( PORT );
            address_length = sizeof(address);

	    cout << "The port is " << PORT << "\n";

	    if ( role == "server" ){

                address.sin_addr.s_addr = INADDR_ANY;
                bind_socket();
                set_listen_set();
                accept_connection();

            } else {

	        const char* array[4] ={"69.69.69.2","69.69.69.1","69.69.69.3","69.69.69.4"};

            	if(inet_pton(AF_INET, array[option], &address.sin_addr)<=0) { 
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
	    file2.open("keys", ios::in | ios::binary);
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
            remove("operator.txt");

            fstream file2;

            file2.open("operator.txt", ios::out | ios::trunc | ios::binary);
            if(file2.is_open()){
                cout<<"[LOG] : Return File Creted.\n";
            }
            else{
                cout<<"[ERROR] : File creation failed, Exititng.\n";
                exit(EXIT_FAILURE);
            }

            char buffer[2200024] = {};
            bzero(buffer, sizeof(buffer));
            //int count = 0;
            printf("Starting to download file contents\n");
            while(1){
                    printf("Beginning file contents\n");
                    int valread = read(general_socket_descriptor , buffer, 2200024);
                    printf("%s", buffer);
                    file2<<buffer;
		    break;
            };
            cout<<"[LOG] : Saving data to file.\n";
            cout<<"[LOG] : File Saved.\n";
            file2.close();

          };


};




int main(int argc, char const* argv[]){
    cudaSetDevice(0);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    //uint32_t kNumSMs = prop.multiProcessorCount;

    SetSeed();
    PriKey pri_key; // private key
    PubKey pub_key;

    //Generate Temporary Keys
    KeyGen(pub_key, pri_key);

    //Write Keys to file
    WritePubKeyToFile(pub_key,"finalkeys/publickey1.txt");
    WritePriKeyToFile(pri_key,"finalkeys/privatekey1.txt");
    Initialize(pub_key);

    //Wait for operator to be sent to KeyGen
    Client_socket C0;
    C0.start_everything(4381,0,"server");
    C0.receive_file();

    //Send Private key to verif
    remove("keys");
    std::ifstream if_a("finalkeys/privatekey1.txt",std::ios_base::app);
    std::ofstream of_c("keys",std::ios_base::app);
    of_c << if_a.rdbuf();

    cout << ("\n----Sending to verif----\n");
    Client_socket C;
    C.start_everything(4382,0, "client");
    C.transmit_file();

    //Send Public key to server
    remove("keys");
    std::ifstream if_a1("finalkeys/publickey1.txt",std::ios_base::app);
    std::ofstream of_c1("keys",std::ios_base::app);
    of_c1 << if_a1.rdbuf();
    cout << ("\n----Sending to server----\n");
    Client_socket C1;
    C1.start_everything(4383,1, "client");
    C1.transmit_file();

    //Send private key to c1
    remove("keys");
    std::ifstream if_a2("finalkeys/privatekey1.txt",std::ios_base::app);
    std::ofstream of_c2("keys",std::ios_base::app);
    of_c2 << if_a2.rdbuf();
    cout << ("\n----Sending to c1----\n");
    Client_socket C2;
    C2.start_everything(4384,2, "client");
    C2.transmit_file();




    //Send private key to c2
    remove("keys");
    std::ifstream if_a3("finalkeys/privatekey1.txt",std::ios_base::app);
    std::ofstream of_c3("keys",std::ios_base::app);
    of_c3 << if_a3.rdbuf();
    cout << ("\n----Sending to c2----\n");
    Client_socket C3;
    C3.start_everything(4385,3, "client");
    C3.transmit_file();
  
}
//developer note: Did not loop for readability
