
#include <iostream>
using namespace std;

#include <string>

int main(){
  int num1 = 10;
  int num2 = 110;
  int diff = 0;

  std::string a = std::to_string(num1);
  std::string b = std::to_string(num2);

  int max = a.size();
  
  if ( b.size() > a.size() ){
    diff = b.size() - a.size();  
    max = b.size();
  } else if ( a.size() > b.size() ){
    diff = a.size() - b.size();
  } 
  
  std::string extras(diff, '0');
  b = extras + b;
 
  //std::cout << b << "\n";

  std::string sum;
  int s;
  int c = 0;

  int last_elem1 = a.size() -1;
  int last_elem2 = b.size() -1;
  
  
  //Check for C
  c = a[last_elem1] & b[last_elem2];
    
  //Check for sum
  s = a[last_elem1] ^ b[last_elem2];
  sum = std::to_string(s) + sum;

  if(max == 1){
    if(c == 49){
      sum = "1" + sum;
    }
    std::cout << sum << "\n";
    return 0;
  }
 
  for(int i = (max - 2); i > -1; i--){

    int carry1;
    int sum1;
    int carry2;
    int s;
    int carry;

    sum1 = c ^ a[i];
    carry1 = c & a[i];

    s = sum1 ^ b[i];
    carry2 = sum1 & b[i];

    carry = carry1 || carry2;
	  
    sum = std::to_string(s) + sum;
  } 

  sum = std::to_string(c) + sum;

  std::cout << sum << "\n";
  return 0;





}
