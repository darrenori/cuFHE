
#include <include/cufhe.h>
#include <include/cufhe_cpu.h>
using namespace cufhe;
#include <iostream>
using namespace std;

void NandCheck(Ptxt& out, const Ptxt& in0, const Ptxt& in1) {
  out.message_ = 1 - in0.message_ * in1.message_;
}

int main() {
  uint32_t kNumTests = 1024;
  SetSeed();
  bool correct;
  PriKey pri_key_old;
  PubKey pub_key_old;
  Ptxt* pt = new Ptxt[2];
  Ctxt* ct = new Ctxt[2];
  pri_key_old.New<AllocatorCPU>();
  pub_key_old.New<AllocatorCPU>();
  ct[0].New<AllocatorCPU>();
  ct[1].New<AllocatorCPU>();

  cout<< "------ Key Generation ------" <<endl;
  KeyGen(pub_key_old, pri_key_old);

  PriKey pri_key;
  PubKey pub_key;
  pri_key.New<AllocatorCPU>();
  pub_key.New<AllocatorCPU>();
  WritePriKeyToFile(pri_key, "pri_key.txt");
  WritePubKeyToFile(pub_key, "pub_key.txt");
  ReadPriKeyFromFile(pri_key, "pri_key.txt");
  ReadPubKeyFromFile(pub_key, "pub_key.txt");

  cout<< "------ Test Encryption/Decryption ------" <<endl;
  cout<< "Number of tests:\t" << kNumTests <<endl;
  correct = true;
  for (int i = 0; i < kNumTests; i ++) {
    pt[0].message_ = rand() % Ptxt::kPtxtSpace;
    Encrypt(ct[0], pt[0], pri_key);
    Decrypt(pt[1], ct[0], pri_key);
    if (pt[1].message_ != pt[0].message_) {
      correct = false;
      break;
    }
  }
  if (correct)
    cout<< "PASS" <<endl;
  else
    cout<< "FAIL" <<endl;

  cout<< "------ Test NAND Gate ------" <<endl;
  kNumTests = 4;
  cout<< "Number of tests:\t" << kNumTests <<endl;
  correct = true;
  for (int i = 0; i < kNumTests; i ++) {
    pt[0].message_ = rand() % Ptxt::kPtxtSpace;
    pt[1].message_ = rand() % Ptxt::kPtxtSpace;
    Encrypt(ct[0], pt[0], pri_key);
    Encrypt(ct[1], pt[1], pri_key);
    Nand(ct[0], ct[0], ct[1], pub_key);
    NandCheck(pt[1], pt[0], pt[1]);
    Decrypt(pt[0], ct[0], pri_key);
    if (pt[1].message_ != pt[0].message_) {
      correct = false;
      break;
    }
  }
  if (correct)
    cout<< "PASS" <<endl;
  else
    cout<< "FAIL" <<endl;

  cout<< "------ Cleaning Data on GPU(s) ------" <<endl;
  pri_key.Delete();
  pub_key.Delete();
  pri_key_old.Delete();
  pub_key_old.Delete();
  ct[0].Delete();
  ct[1].Delete();
  return 0;
}
