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
            create_socket();
            PORT = 8050;

            address.sin_family = AF_INET;
            address.sin_port = htons( PORT );
            address_length = sizeof(address);
            if(inet_pton(AF_INET, "69.69.69.2", &address.sin_addr)<=0) { 
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
//            cout<<"[LOG] : Data received "<<valread<<" bytes\n";
            cout<<"[LOG] : Saving data to file.\n";
            cout<<"[LOG] : File Saved.\n";
	    file.close();
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
};

int main(){
    Client_socket C;
    C.receive_file();
    C.split_file();

    return 0;
};