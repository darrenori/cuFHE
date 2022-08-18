#include <iostream>
#include <utility>
#include <string>

using namespace std;

std::pair<int, int> half_adder(int in0,int in1){
	return {in0 && in1, in0 ^ in1};
}

std::pair<int, int> full_adder(int carry_in, int in0, int in1){
	std::pair<int,int> c1s1= half_adder(carry_in,in0);
	std::pair<int, int> c2s= half_adder(c1s1.second,in1);
	int carry = c1s1.first || c2s.first;
	return {carry, c2s.second};
}


int main(){
  std::string a = "11110110100001111011101101011000";
  std::string b = "10110000011010100010110010000011";

  int max = a.size();
  std::string diff;
  
  if ( b.size() > a.size() ){
    max = b.size();
    std::string diff(b.size()-a.size(), '0');	    
    a = diff +a;
  } else if ( a.size() > b.size() ){
    std::string diff(a.size()-b.size(), '0');	    
    b = diff +b;
  } 

  int carry = 0;
  std::string result;
  string carrystring;

  for(int i = max-1; i > -1; i--){
	std::pair<int, int> cs = full_adder(carry,(int)a[i]-48,(int)b[i]-48);
	carry = cs.first;
	result.insert(0,to_string(cs.second));
  }
  
  result.insert(0,to_string(carry));
  std::cout << "YOUR RESULT IS:" << result << "\n";
  return 0;
}

