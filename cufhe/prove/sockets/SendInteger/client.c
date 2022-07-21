#include <stdio.h>
#include <stdlib.h> 
#include <string.h> 
#include <sys/socket.h> 
#include <unistd.h>
#include <arpa/inet.h>
#include <errno.h>

// first argument to this program is IP address
// Second argument is Port

void send_receive_integer_over_socket(int sockfd) { 
	uint32_t int_to_send = 879612345, int_to_receive; //integer_to_send is something like command

	write(sockfd, &int_to_send, sizeof(int_to_send)); 

} 

int main(int argc, char **argv) { 
	int sockfd, port; 
	struct sockaddr_in servaddr, cli; 

	sockfd = socket(AF_INET, SOCK_STREAM, 0); 
	if (sockfd == -1) { 
		printf("socket creation failed...\n"); 
		exit(errno); 
	}	
	printf("Socket successfully created..\n"); 
//	bzero(&amp;amp;servaddr, sizeof(servaddr)); 

	servaddr.sin_family = AF_INET; 
	// Change this IP Address
	servaddr.sin_addr.s_addr = inet_addr("127.0.0.1"); 
	port = 4380;
	servaddr.sin_port = htons(port); 

	if (connect(sockfd, (struct sockaddr*)&servaddr, sizeof(servaddr)) != 0) { 
		printf("connection with the server failed...\n"); 
		exit(errno);
	} 
	printf("connected to the server..\n"); 

	send_receive_integer_over_socket(sockfd); 

	close(sockfd);
	return 0;
} 
