/**
 * Copyright 2018 Wei Dai <wdai3141@gmail.com>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

// Include these two files for GPU computing.
#include <include/cufhe_gpu.cuh>
using namespace cufhe;

#include <iostream>
using namespace std;

void NandCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = 1 - in0.message_ * in1.message_;
}

void OrCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = (in0.message_ + in1.message_) > 0;
}

void AndCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = in0.message_ * in1.message_;
}

void XorCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = (in0.message_ + in1.message_) & 0x1;
}

void NotCheck(Ptxt& out, const Ptxt& in) {
	out.message_ = (~in.message_) & 0x1;
}

void CopyCheck(Ptxt& out, const Ptxt& in){
	out.message_ = in.message_;
}

void addBits(Ctxt *r, Ctxt &a, Ctxt &b, Ctxt *carry) {
	Ctxt *t1 = new Ctxt[1];
    Ctxt *t2 = new Ctxt[1];
	Xor(t1[0], a, carry[0]);
    Xor(t2[0], b, carry[0]);
	Synchronize();
	Xor(r[0], a, t2[0]);
	And(t1[0], t1[0], t2[0]);
	Synchronize();
	Xor(r[1], carry[0], t1[0]);
	Synchronize();
	delete [] t1;
	delete [] t2;
}

void addNumbers(Ctxt *ctRes, Ctxt *ctA, Ctxt *ctB, int nBits) {
	
	Ctxt *carry = new Ctxt[1];
    Ctxt *bitResult = new Ctxt[2];

	Xor(ctRes[0], ctA[0], ctB[0]);
	And(carry[0], ctA[0], ctB[0]);
	Synchronize();
	for(int i = 1; i < nBits; i++) {
		addBits(bitResult, ctA[i], ctB[i], carry);
		Copy(ctRes[i], bitResult[0]);
		Copy(carry[0], bitResult[1]);
		Synchronize();
	}
	delete [] carry;
	delete [] bitResult;
}


int main() {
  cudaSetDevice(0);
  cudaDeviceProp prop;
  cudaGetDeviceProperties(&prop, 0);
  uint32_t kNumSMs = prop.multiProcessorCount;
  uint32_t kNumTests = kNumSMs * 32;// * 8;
  uint32_t kNumLevels = 4;
  uint32_t val1 = 1;
  uint32_t val2 = 2;
  int numBits = 32;

  SetSeed(); // set random seed

  PriKey pri_key; // private key
  PubKey pub_key; // public key

  ReadPriKeyFromFile(pri_key,"finalkeys/privatekey1.txt");
  ReadPubKeyFromFile(pub_key,"finalkeys/publickey1.txt");

  Ptxt* pt = new Ptxt[numBits * 2];
  Ptxt* pt1 = new Ptxt[numBits * 2];
  Ptxt* ptRes = new Ptxt[numBits * 2];
  Ctxt* ct = new Ctxt[numBits * 2];
  Ctxt* ct1 = new Ctxt[numBits * 2];
  Ctxt* ctRes = new Ctxt[numBits * 2];
  Synchronize();
  bool correct;

  cout<< "------ Key Generation ------" <<endl;
  KeyGen(pub_key, pri_key);

  cout<< "------ Initilizating Data on GPU(s) ------" <<endl;
  Initialize(pub_key); // essential for GPU computing


  cout<< "Number of tests:\t" << numBits <<endl;
  // Create CUDA streams for parallel gates.
  Stream* st = new Stream[kNumSMs];
  for (int i = 0; i < kNumSMs; i ++)
    st[i].Create();


  correct = true;
  for (int i = 0; i < numBits; i ++) {
    //pt[i] = rand() % Ptxt::kPtxtSpace;
    pt[i] = 0;
    pt[2]=1;
    Encrypt(ct[i], pt[i], pri_key);
  }

  for (int i = 0; i < numBits; i ++) {
    //pt1[i] = rand() % Ptxt::kPtxtSpace;
    pt1[i] = 0;
    pt1[2]=1;
    Encrypt(ct1[i], pt1[i], pri_key);
  }

 // std::string abc="abc.txt";
 // WriteCtxtToFile(ct[0],abc);

  Synchronize();

  float et;
  cudaEvent_t start, stop;
  cudaEventCreate(&start);
  cudaEventCreate(&stop);
  cudaEventRecord(start, 0);


  // Here, pass streams to gates for parallel gates.
  cout<< "------ Test NAND Gate ------" <<endl;
  for (int i = 0; i < numBits; i ++) {
    Nand(ctRes[i], ct[i], ct1[i], st[i % kNumSMs]);
  }



  Synchronize();
  

//  addNumbers(ctRes, ct, ct1, numBits);


  cudaEventRecord(stop, 0);
  cudaEventSynchronize(stop);
  cudaEventElapsedTime(&et, start, stop);
  cout<< et / numBits / kNumLevels << " ms / gate" <<endl;
  cudaEventDestroy(start);
  cudaEventDestroy(stop);
 /* for (int i =0; i < numBits; i ++){
	Decrypt(pt1[i], ctRes[i], pri_key);
	cout << pt1[i].message_;
  }*/

  int cnt_failures = 0;
  for (int i = 0; i < numBits; i ++) {
    NandCheck(ptRes[i], pt[i], pt1[i]);
    Decrypt(pt1[i], ctRes[i], pri_key);
    if (pt1[i].message_ != ptRes[i].message_) {
      std::cout << "FAILED" << pt1[i].message_ << "||" <<ptRes[i].message_ << "\n";
      correct = false;
      cnt_failures += 1;
      //std::cout<< "Fail at iteration: " << i <<std::endl;
    }
  }


 
  if (correct)
    cout<< "PASS" <<endl;
  else
    cout<< "FAIL:\t" << cnt_failures << "/" << numBits <<endl;
  for (int i = 0; i < kNumSMs; i ++)
    st[i].Destroy();
  
  delete [] st;

  cout<< "------ Cleaning Data on GPU(s) ------" <<endl;
  CleanUp(); // essential to clean and deallocate data
  delete [] ct;
  delete [] pt;
  return 0;
}
