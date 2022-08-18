#include <iostream>
#include <string>
#include <cstring>
#include<bits/stdc++.h>
using namespace std;

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

// function to check if a number is negative
std::string check(int n){
    string check = "false";
    if(0 > n){
      check = "true";
    }
    return check;
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

int main()
{
    // Decimal to Binary
    int n = 2147483647;
    cout << decToBinary(n) << "\n";

    // Binary to Decimal
    const std::string s = "0010111100011100011";
    cout << binToDecimal(s) << "\n";
    cout << "\n \n";    
    // Convert Binary to its Two Complement
    std::string str = "0111";
    cout << "\n" << toTwoComplement(str);
    
    cout << "\n \n";

    return 0;
}
