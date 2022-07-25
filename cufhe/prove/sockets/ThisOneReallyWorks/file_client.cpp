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
            if(inet_pton(AF_INET, "127.0.0.1", &address.sin_addr)<=0) { 
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
	    file2.open("send.txt", ios::in | ios::binary);
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

int main(){
  
    int port1 = 4380;
    int port2 = 4381;

    Client_socket C;
    C.start_everything(port1);
    C.receive_file();
    C.split_file();
    C.close_socket();
    
    Client_socket S;
    S.start_everything(port2);
    S.transmit_file();

    return 0;
};
