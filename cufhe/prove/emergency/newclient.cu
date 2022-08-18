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

};


void NandCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = 1 - in0.message_ * in1.message_;
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

int main(int argc, char const* argv[])
{
    int port1 = 4380;
    int port2 = 4381;
    int sock = 0, valread, client_fd;
    struct sockaddr_in serv_addr;

    // Generating CT

    cudaSetDevice(0);
    cudaDeviceProp prop;
    cudaGetDeviceProperties(&prop, 0);
    uint32_t kNumSMs = prop.multiProcessorCount;
    //uint32_t kNumLevels = 4;
    int numBits = 32;

    SetSeed();


    PriKey pri_key; // private key
    PubKey pub_key;
    bool correct = true;

    struct timeval start, end;
    double get_time;
    gettimeofday(&start, NULL);

    KeyGen(pub_key, pri_key);

    gettimeofday(&end, NULL);
    get_time = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) * 1.0E-6;
    printf("Computation Time: %lf[sec]\n", get_time);


    WritePubKeyToFile(pub_key,"finalkeys/publickey1.txt");
    Initialize(pub_key);

    Ptxt* pt = new Ptxt[numBits];
    Ptxt* pt1 = new Ptxt[numBits];
    Ptxt* ptRes = new Ptxt[numBits];
    Ctxt* ct = new Ctxt[numBits];
    Ctxt* ct1 = new Ctxt[numBits];
    Ctxt* ctRes = new Ctxt[numBits];



    Stream* st = new Stream[kNumSMs];
    for (int i = 0; i < kNumSMs; i ++)
      st[i].Create();

    / Getting the User Inputs ========================
   int input1, input2, operator_code, bits;
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

   for ( int i = 0; i < 32; i++){
       pt[i] = x[i];
       pt1[i] = y[i];
   }

   cout << "\nThe operator code is: " << operator_code << "\n";
   // Write Operator Code
   ofstream myfile;
   myfile.open ("operator.txt");
   myfile << operator_code << "\n";
   myfile.close();
/*

    for (int i = 0; i < numBits; i ++) {
	    pt[i] = rand() % Ptxt::kPtxtSpace;
	    pt1[i] = rand() % Ptxt::kPtxtSpace;
    }
*/


    //FOR DEBUGGING
/*
    cout << "INPUT ONE\n";
    for (int i = 0; i < numBits; i ++) {
	    cout << pt[i].message_;
    }

    cout<< "\nINPUT TWO\n";
    for (int i = 0; i < numBits; i ++) {
	    cout << pt1[i].message_;
    }

*/
    for (int i = 0; i < numBits; i ++) {
   	Encrypt(ct[i], pt[i], pri_key);
      	Encrypt(ct1[i], pt1[i], pri_key);
    }


    Synchronize();





    //-----------------------SENDING DATA OVER----------------------------

    //DUMP CTXT FILES TO SEND
    for (int i = 0; i < numBits; i ++) {
	    string filename = "cipher/ct" + std::to_string(i);
	    WriteCtxtToFile(ct[i],filename);
	    filename = "cipher1/ct" + std::to_string(i);
	    WriteCtxtToFile(ct1[i],filename);
    }

    remove("cipher/overall");

    for (int i = 0; i < numBits; i ++) {
	    std::ifstream if_a("cipher/ct"+std::to_string(i),std::ios_base::app);
	    std::ofstream of_c("cipher/overall",std::ios_base::app);
	    of_c << if_a.rdbuf();
    }

    for (int i = 0; i < numBits; i ++) {
	    std::ifstream if_a("cipher1/ct"+std::to_string(i),std::ios_base::app);
	    std::ofstream of_c("cipher/overall",std::ios_base::app);
	    of_c << if_a.rdbuf();
    }

    //transmit public keys
    std::ifstream if_a("finalkeys/publickey1.txt",std::ios_base::app);
    std::ofstream of_c("cipher/overall",std::ios_base::app);
    of_c << if_a.rdbuf();

    
    gettimeofday(&start, NULL);

    Client_socket C;
    C.start_everything(port1);
    C.transmit_file();
    C.close_socket();

    gettimeofday(&end, NULL);
    get_time = (end.tv_sec - start.tv_sec) + (end.tv_usec - start.tv_usec) * 1.0E-6;
    printf("First send: %lf[sec]\n", get_time);



    gettimeofday(&start, NULL);

   Client_socket C1;
   C1.start_everything(port2);
   C1.receive_file();
   C1.split_file();



    //-------------------READING BACK DATA FROM SERVER----------------------//
    for (int i = 0; i < numBits; i ++) {
            string filename = "cipherRes/ct" + std::to_string(i);
            ReadCtxtFromFile(ctRes[i],filename);
    }


    cout << "\nINPUT ONE:\n";
    for (int i=0; i < numBits; i++) {
	    cout << pt[i].message_;
    }


    cout << "\nINPUT TWO:\n";
    for (int i=0; i < numBits; i++) {
	    cout << pt1[i].message_;
    }


/*

    for (int i=0; i < numBits; i++) {
	Decrypt(pt1[i], ctRes[i], pri_key);
    }



    cout << "\nRESULT:\n";
    for (int i=0; i < numBits; i++) {
	    cout << pt1[i].message_;
    }
 */

    //READ COMPUTED DATA FROM SERVER HERE!
    int cnt_failures = 0;
    for (int i = 0; i < numBits; i ++) {
      Decrypt(ptRes[i], ctRes[i], pri_key);
      /*if (pt1[i].message_ != ptRes[i].message_) {
        std::cout << "FAILED" << pt1[i].message_ << "||" <<ptRes[i].message_ << "\n";
        correct = false;
        cnt_failures += 1;
        //std::cout<< "Fail at iteration: " << i <<std::endl;
      }*/
    }

    

    //for debugging ONLY
/*
    cout << "PLAINTEXT RESULT\n";
    for(int i=0; i< numBits; i++){
	    cout << ptRes[i].message_;
    }



*/

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

    cout<< "------ Cleaning Data on GPU(s) ------" <<endl;
    CleanUp(); // essential to clean and deallocate data
    delete [] ct;
    delete [] pt;
    return 0;


}
