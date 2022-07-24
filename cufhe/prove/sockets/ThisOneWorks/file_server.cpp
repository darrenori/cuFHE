#include<iostream>
#include<fstream>
#include<stdio.h>
#include <unistd.h>
#include <sys/socket.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <string>
#include <strings.h>
#include <iostream>
#include <cmath>
using namespace std;


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
            create_socket();

	    if (check == 0){
                PORT = 4380;
	    } else {
	        PORT = 4381;
	    };

	    address.sin_family = AF_INET; 
            address.sin_addr.s_addr = INADDR_ANY; 
            address.sin_port = htons( PORT );
            address_length = sizeof(address);

            bind_socket();
            set_listen_set();
            accept_connection();
           
            check = 1;

            file.open("overall", ios::in | ios::binary);
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
	    std::ifstream file("return.txt");
	    
	    std::string filenames[64];
            for (int i = 0; i < 64; i ++){
                string filename = "Ptxt" + std::to_string(i);
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

	void receive_file(){

            file2.open("return.txt", ios::out | ios::trunc | ios::binary);
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

int main(){
    Server_socket S;
    S.transmit_file();
    S.close_socket();

    Server_socket C;
    C.receive_file();
    C.split_file();
    return 0;
}
