/*
 * This file is part of the VanitySearch distribution (https://github.com/JeanLucPons/VanitySearch).
 * Copyright (c) 2019 Jean Luc PONS.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

#include "Timer.h"
#include "Vanity.h"
#include "SECP256k1.h"
#include <fstream>
#include <string>
#include <string.h>
#include <stdexcept>
#include "hash/sha512.h"
#include "hash/sha256.h"

#define RELEASE "1.19"

using namespace std;

// ------------------------------------------------------------------------------------------

void printUsage() {

  printf("VanitySearch [-check] [-v] [-u] [-b] [-c] [-gpu] [-stop] [-i inputfile]\n");
  printf("             [-gpuId gpuId1[,gpuId2,...]] [-g gridSize1[,gridSize2,...]]\n");
  printf("             [-o outputfile] [-m maxFound] [-ps seed] [-s seed] [-t nbThread]\n");
  printf("             [-nosse] [-r rekey] [-sp startPub] [-kp]\n");
  printf("             [-range rangeStart,rangeEnd] [-keys keysPerCore] <pattern>\n\n");
  printf(" -v                    : Print version\n");
  printf(" -u                    : Search uncompressed addresses\n");
  printf(" -b                    : Search both uncompressed or compressed addresses\n");
  printf(" -c                    : Case unsensitive search\n");
  printf(" -gpu                  : Enable GPU calculation\n");
  printf(" -stop                 : Stop when all prefixes have been found\n");
  printf(" -i inputfile          : Get list of prefixes to search from specified file\n");
  printf(" -o outputfile         : Output results to the specified file\n");
  printf(" -gpuId gpuId1,gpuId2  : List of GPU(s) to use, default is 0\n");
  printf(" -g gridSize1,gridSize2: Specify GPU(s) kernel gridsize, default is 8*(MP number),128\n");
  printf(" -m maxFound           : Specify max number of prefixes found per kernel call\n");
  printf(" -ps seed              : Specify a personal seed for key generation\n");
  printf(" -s seed               : Specify a seed for key generation\n");
  printf(" -t nbThread           : Specify number of CPU thread, default is number of core\n");
  printf(" -nosse                : Disable SSE hash function\n");
  printf(" -l                    : List cuda enabled devices\n");
  printf(" -check                : Check CPU and GPU kernel vs CPU\n");
  printf(" -sp startPub          : Start with a specified public key for private key recovery\n");
  printf(" -kp                   : Generate key pair\n");
  printf(" -rp privKey           : Reconstruct a public key from a private key and compute hashes\n");
  printf(" -r rekey              : Rekey interval in MegaKey, default is disabled\n");
  printf(" -range start,end      : Range of keys to search (in hex)\n");
  printf(" -keys num             : Number of keys to process per GPU core\n");
  exit(0);

}

// ------------------------------------------------------------------------------------------

int getInt(string name,char *v) {

  int r;

  try {

    r = std::stoi(string(v));

  } catch(std::invalid_argument&) {

    printf("Invalid %s argument, number expected\n",name.c_str());
    exit(-1);

  }

  return r;

}

// ------------------------------------------------------------------------------------------

void getInts(string name,vector<int> &tokens, const string &text, char sep) {

  size_t start = 0, end = 0;
  tokens.clear();
  int item;

  try {

    while ((end = text.find(sep, start)) != string::npos) {
      item = std::stoi(text.substr(start, end - start));
      tokens.push_back(item);
      start = end + 1;
    }

    item = std::stoi(text.substr(start));
    tokens.push_back(item);

  } catch(std::invalid_argument &) {

    printf("Invalid %s argument, number expected\n",name.c_str());
    exit(-1);

  }

}

// ------------------------------------------------------------------------------------------

void parseFile(string fileName, vector<string> &lines) {

  // Get file size
  FILE *fp = fopen(fileName.c_str(), "rb");
  if (fp == NULL) {
    printf("Error: Cannot open %s %s\n", fileName.c_str(), strerror(errno));
    exit(-1);
  }
  fseek(fp, 0L, SEEK_END);
  size_t sz = ftell(fp);
  size_t nbAddr = sz / 33; /* Upper approximation */
  bool loaddingProgress = sz > 100000;
  fclose(fp);

  // Parse file
  int nbLine = 0;
  string line;
  ifstream inFile(fileName);
  lines.reserve(nbAddr);
  while (getline(inFile, line)) {

    // Remove ending \r\n
    int l = (int)line.length() - 1;
    while (l >= 0 && isspace(line.at(l))) {
      line.pop_back();
      l--;
    }

    if (line.length() > 0) {
      lines.push_back(line);
      nbLine++;
      if (loaddingProgress) {
        if ((nbLine % 50000) == 0)
          printf("[Loading input file %5.1f%%]\r", ((double)nbLine*100.0) / ((double)(nbAddr)*33.0 / 34.0));
      }
    }

  }

  if (loaddingProgress)
    printf("[Loading input file 100.0%%]\n");

}

// ------------------------------------------------------------------------------------------

void generateKeyPair(Secp256K1 *secp, string seed, int searchMode,bool paranoiacSeed) {

  if (seed.length() < 8) {
    printf("Error: Use a seed of at least 8 characters to generate a key pair\n");
    printf("Ex: VanitySearch -s \"A Strong Password\" -kp\n");
    exit(-1);
  }

  if(paranoiacSeed)
    seed = seed + Timer::getSeed(32);

  if (searchMode == SEARCH_BOTH) {
    printf("Error: Use compressed or uncompressed to generate a key pair\n");
    exit(-1);
  }

  bool compressed = (searchMode == SEARCH_COMPRESSED);

  string salt = "VanitySearch";
  unsigned char hseed[64];
  pbkdf2_hmac_sha512(hseed, 64, (const uint8_t *)seed.c_str(), seed.length(),
    (const uint8_t *)salt.c_str(), salt.length(),
    2048);

  Int privKey;
  privKey.SetInt32(0);
  sha256(hseed, 64, (unsigned char *)privKey.bits64);
  Point p = secp->ComputePublicKey(&privKey);
  printf("Priv : %s\n", secp->GetPrivAddress(compressed,privKey).c_str());
  printf("Pub  : %s\n", secp->GetPublicKeyHex(compressed,p).c_str());

}

// ------------------------------------------------------------------------------------------

void outputAdd(string outputFile, int addrType, string addr, string pAddr, string pAddrHex) {

  FILE *f = stdout;
  bool needToClose = false;

  if (outputFile.length() > 0) {
    f = fopen(outputFile.c_str(), "a");
    if (f == NULL) {
      printf("Cannot open %s for writing\n", outputFile.c_str());
      f = stdout;
    } else {
      needToClose = true;
    }
  }

  fprintf(f, "\nPub Addr: %s\n", addr.c_str());


  switch (addrType) {
  case P2PKH:
    fprintf(f, "Priv (WIF): p2pkh:%s\n", pAddr.c_str());
    break;
  case P2SH:
    fprintf(f, "Priv (WIF): p2wpkh-p2sh:%s\n", pAddr.c_str());
    break;
  case BECH32:
    fprintf(f, "Priv (WIF): p2wpkh:%s\n", pAddr.c_str());
    break;
  }
  fprintf(f, "Priv (HEX): 0x%s\n", pAddrHex.c_str());

  if (needToClose)
    fclose(f);

}

// ------------------------------------------------------------------------------------------
#define CHECK_ADDR()                                           \
  fullPriv.ModAddK1order(&e, &partialPrivKey);                 \
  p = secp->ComputePublicKey(&fullPriv);                       \
  cAddr = secp->GetAddress(addrType, compressed, p);           \
  if (cAddr == addr) {                                         \
    found = true;                                              \
    string pAddr = secp->GetPrivAddress(compressed, fullPriv); \
    string pAddrHex = fullPriv.GetBase16();                    \
    outputAdd(outputFile, addrType, addr, pAddr, pAddrHex);    \
  }

void reconstructAdd(Secp256K1 *secp, string fileName, string outputFile, string privAddr) {

  bool compressed;
  int addrType;
  Int lambda;
  Int lambda2;
  lambda.SetBase16("5363ad4cc05c30e0a5261c028812645a122e22ea20816678df02967c1b23bd72");
  lambda2.SetBase16("ac9c52b33fa3cf1f5ad9e3fd77ed9ba4a880b9fc8ec739c2e0cfc810b51283ce");

  Int privKey = secp->DecodePrivateKey((char *)privAddr.c_str(),&compressed);
  if(privKey.IsNegative())
    exit(-1);

  vector<string> lines;
  parseFile(fileName,lines);

  for (int i = 0; i < (int)lines.size(); i+=2) {

    string addr;
    string partialPrivAddr;

    if (lines[i].substr(0, 12) == "PubAddress: ") {

      addr = lines[i].substr(12);

      switch (addr.data()[0]) {
      case '1':
        addrType = P2PKH; break;
      case '3':
        addrType = P2SH; break;
      case 'b':
      case 'B':
        addrType = BECH32; break;
      default:
        printf("Invalid partialkey info file at line %d\n", i);
        printf("%s Address format not supported\n", addr.c_str());
        continue;
      }

    } else {
      printf("Invalid partialkey info file at line %d (\"PubAddress: \" expected)\n",i);
      exit(-1);
    }

    if (lines[i+1].substr(0, 13) == "PartialPriv: ") {
      partialPrivAddr = lines[i+1].substr(13);
    } else {
      printf("Invalid partialkey info file at line %d (\"PartialPriv: \" expected)\n", i);
      exit(-1);
    }

    bool partialMode;
    Int partialPrivKey = secp->DecodePrivateKey((char *)partialPrivAddr.c_str(), &partialMode);
    if (privKey.IsNegative()) {
      printf("Invalid partialkey info file at line %d\n", i);
      exit(-1);
    }

    if (partialMode != compressed) {

      printf("Warning, Invalid partialkey at line %d (Wrong compression mode, ignoring key)\n", i);
      continue;

    } else {

      // Reconstruct the address
      Int fullPriv;
      Point p;
      Int e;
      string cAddr;
      bool found = false;

      // No sym, no endo
      e.Set(&privKey);
      CHECK_ADDR();

      // No sym, endo 1
      e.Set(&privKey);
      e.ModMulK1order(&lambda);
      CHECK_ADDR();

      // No sym, endo 2
      e.Set(&privKey);
      e.ModMulK1order(&lambda2);
      CHECK_ADDR();

      // sym, no endo
      e.Set(&privKey);
      e.Neg();
      e.Add(&secp->order);
      CHECK_ADDR();

      // sym, endo 1
      e.Set(&privKey);
      e.ModMulK1order(&lambda);
      e.Neg();
      e.Add(&secp->order);
      CHECK_ADDR();

      // sym, endo 2
      e.Set(&privKey);
      e.ModMulK1order(&lambda2);
      e.Neg();
      e.Add(&secp->order);
      CHECK_ADDR();

      if (!found) {
        printf("Unable to reconstruct final key from partialkey line %d\n Addr: %s\n PartKey: %s\n",
          i, addr.c_str(),partialPrivAddr.c_str());
      }

    }

  }

}

// ------------------------------------------------------------------------------------------

int main(int argc, char* argv[]) {

  // Global Init
  Timer::Init();
  rseed(Timer::getSeed32());

  // Init SecpK1
  Secp256K1 *secp = new Secp256K1();
  secp->Init();

  // Browse arguments
  if (argc < 2) {
    printf("Error: No arguments (use -h for help)\n");
    exit(-1);
  }

  int a = 1;
  bool gpuEnable = false;
  bool stop = false;
  int searchMode = SEARCH_COMPRESSED;
  vector<int> gpuId = {0};
  vector<int> gridSize;
  string seed = "";
  vector<string> prefix;
  string outputFile = "";
  int nbCPUThread = Timer::getCoreNumber();
  bool tSpecified = false;
  bool sse = true;
  uint32_t maxFound = 65536;
  uint64_t rekey = 0;
  Point startPuKey;
  startPuKey.Clear();
  bool startPubKeyCompressed;
  bool caseSensitive = true;
  bool paranoiacSeed = false;
  Int *rangeStart = NULL;
  Int *rangeEnd = NULL;
  uint64_t keysPerCore = 0;

  while (a < argc) {

    if (strcmp(argv[a], "-gpu")==0) {
      gpuEnable = true;
      a++;
    } else if (strcmp(argv[a], "-gpuId")==0) {
      a++;
      getInts("gpuId",gpuId,string(argv[a]),',');
      a++;
    } else if (strcmp(argv[a], "-stop") == 0) {
      stop = true;
      a++;
    } else if (strcmp(argv[a], "-c") == 0) {
      caseSensitive = false;
      a++;
    } else if (strcmp(argv[a], "-v") == 0) {
      printf("%s\n",RELEASE);
      exit(0);
    } else if (strcmp(argv[a], "-range") == 0) {
      // Processa o parâmetro range - formato: -range start,end (em hex)
      a++;
      vector<string> rangeValues;
      string rangeStr = string(argv[a]);
      size_t pos = 0;
      string token;
      
      // Divide a string em start,end
      while ((pos = rangeStr.find(",")) != string::npos) {
        token = rangeStr.substr(0, pos);
        rangeValues.push_back(token);
        rangeStr.erase(0, pos + 1);
      }
      rangeValues.push_back(rangeStr); // Adiciona o último valor
      
      if (rangeValues.size() != 2) {
        printf("Invalid range format. Use: -range start,end (in hex)\n");
        exit(-1);
      }
      
      // Converte os valores para Int
      rangeStart = new Int();
      rangeEnd = new Int();
#ifdef WIN64
      char* startStr = _strdup(rangeValues[0].c_str());
      char* endStr = _strdup(rangeValues[1].c_str());
#else
      char* startStr = strdup(rangeValues[0].c_str());
      char* endStr = strdup(rangeValues[1].c_str());
#endif
      rangeStart->SetBase16(startStr);
      rangeEnd->SetBase16(endStr);
      free(startStr);
      free(endStr);
      
      // Verifica se o intervalo é válido
      if (rangeStart->IsGreaterOrEqual(rangeEnd)) {
        printf("Invalid range: start must be less than end\n");
        exit(-1);
      }
      
      a++;
    } else if (strcmp(argv[a], "-keys") == 0) {
      // Processa o parâmetro keys
      a++;
      keysPerCore = strtoull(argv[a], NULL, 10);
      if (keysPerCore == 0) {
        printf("Invalid keys value: must be greater than 0\n");
        exit(-1);
      }
      a++;
    } else if (strcmp(argv[a], "-check") == 0) {

      Int::Check();
      secp->Check();

#ifdef WITHGPU
      if (gridSize.size() == 0) {
        gridSize.push_back(-1);
        gridSize.push_back(128);
      }
      GPUEngine g(gridSize[0],gridSize[1],gpuId[0],maxFound,false);
      g.SetSearchMode(searchMode);
      g.Check(secp);
#else
  printf("GPU code not compiled, use -DWITHGPU when compiling.\n");
#endif
      exit(0);
    } else if (strcmp(argv[a], "-l") == 0) {

#ifdef WITHGPU
      GPUEngine::PrintCudaInfo();
#else
  printf("GPU code not compiled, use -DWITHGPU when compiling.\n");
#endif
      exit(0);

    } else if (strcmp(argv[a], "-kp") == 0) {
      generateKeyPair(secp,seed,searchMode,paranoiacSeed);
      exit(0);
    } else if (strcmp(argv[a], "-sp") == 0) {
      a++;
      string pub = string(argv[a]);
      startPuKey = secp->ParsePublicKeyHex(pub, startPubKeyCompressed);
      a++;
    } else if(strcmp(argv[a],"-ca") == 0) {
      a++;
      string pub = string(argv[a]);
      bool isComp;
      Point p = secp->ParsePublicKeyHex(pub,isComp);
      printf("Addr (P2PKH): %s\n",secp->GetAddress(P2PKH,isComp,p).c_str());
      printf("Addr (P2SH): %s\n",secp->GetAddress(P2SH,isComp,p).c_str());
      printf("Addr (BECH32): %s\n",secp->GetAddress(BECH32,isComp,p).c_str());
      exit(0);
    } else if (strcmp(argv[a], "-cp") == 0) {
      a++;
      string priv = string(argv[a]);
      Int k;
      bool isComp = true;
      if(priv[0]=='5' || priv[0] == 'K' || priv[0] == 'L') {
        k = secp->DecodePrivateKey((char *)priv.c_str(),&isComp);
      } else {
        k.SetBase16(argv[a]);
      }
      Point p = secp->ComputePublicKey(&k);
      printf("PrivAddr: p2pkh:%s\n",secp->GetPrivAddress(isComp,k).c_str());
      printf("PubKey: %s\n",secp->GetPublicKeyHex(isComp,p).c_str());
      printf("Addr (P2PKH): %s\n", secp->GetAddress(P2PKH,isComp,p).c_str());
      printf("Addr (P2SH): %s\n", secp->GetAddress(P2SH,isComp,p).c_str());
      printf("Addr (BECH32): %s\n", secp->GetAddress(BECH32,isComp,p).c_str());
      exit(0);
    } else if (strcmp(argv[a], "-rp") == 0) {
      a++;
      string priv = string(argv[a]);
      a++;
      string file = string(argv[a]);
      a++;
      reconstructAdd(secp,file,outputFile,priv);
      exit(0);
    } else if (strcmp(argv[a], "-u") == 0) {
      searchMode = SEARCH_UNCOMPRESSED;
      a++;
    } else if (strcmp(argv[a], "-b") == 0) {
      searchMode = SEARCH_BOTH;
      a++;
    } else if (strcmp(argv[a], "-nosse") == 0) {
      sse = false;
      a++;
    } else if (strcmp(argv[a], "-g") == 0) {
      a++;
      getInts("gridSize",gridSize,string(argv[a]),',');
      a++;
    } else if (strcmp(argv[a], "-s") == 0) {
      a++;
      seed = string(argv[a]);
      a++;
    } else if (strcmp(argv[a], "-ps") == 0) {
      a++;
      seed = string(argv[a]);
      paranoiacSeed = true;
      a++;
    } else if (strcmp(argv[a], "-o") == 0) {
      a++;
      outputFile = string(argv[a]);
      a++;
    } else if (strcmp(argv[a], "-i") == 0) {
      a++;
      parseFile(string(argv[a]),prefix);
      a++;
    } else if (strcmp(argv[a], "-t") == 0) {
      a++;
      nbCPUThread = getInt("nbCPUThread",argv[a]);
      a++;
      tSpecified = true;
    } else if (strcmp(argv[a], "-m") == 0) {
      a++;
      maxFound = getInt("maxFound", argv[a]);
      a++;
    } else if (strcmp(argv[a], "-r") == 0) {
      a++;
      rekey = (uint64_t)getInt("rekey", argv[a]);
      a++;
    } else if (strcmp(argv[a], "-h") == 0) {
      printUsage();
    } else if (a == argc - 1) {
      prefix.push_back(string(argv[a]));
      a++;
    } else {
      printf("Unexpected %s argument\n",argv[a]);
      exit(-1);
    }

  }

  printf("VanitySearch v" RELEASE "\n");

  if(gridSize.size()==0) {
    for (int i = 0; i < gpuId.size(); i++) {
      gridSize.push_back(-1);
      gridSize.push_back(128);
    }
  } else if(gridSize.size() != gpuId.size()*2) {
    printf("Invalid gridSize or gpuId argument, must have coherent size\n");
    exit(-1);
  }

  // Let one CPU core free per gpu is gpu is enabled
  // It will avoid to hang the system
  if( !tSpecified && nbCPUThread>1 && gpuEnable)
    nbCPUThread-=(int)gpuId.size();
  if(nbCPUThread<0)
    nbCPUThread = 0;

  // Se um range foi especificado mas o número de chaves por core não foi, defina um valor padrão
  if (rangeStart != NULL && rangeEnd != NULL && keysPerCore == 0) {
    keysPerCore = STEP_SIZE;
#ifdef WIN64
    printf("Keys per core not specified, using default: %llu\n", keysPerCore);
#else
    printf("Keys per core not specified, using default: %lu\n", (unsigned long)keysPerCore);
#endif
  }

  // If a starting public key is specified, force the search mode according to the key
  if (!startPuKey.isZero()) {
    searchMode = (startPubKeyCompressed)?SEARCH_COMPRESSED:SEARCH_UNCOMPRESSED;
  }

  VanitySearch *v = new VanitySearch(secp, prefix, seed, searchMode, gpuEnable, stop, outputFile, sse,
    maxFound, rekey, caseSensitive, startPuKey, paranoiacSeed, rangeStart, rangeEnd, keysPerCore);
  v->Search(nbCPUThread,gpuId,gridSize);

  // Limpar a memória alocada
  if (rangeStart) delete rangeStart;
  if (rangeEnd) delete rangeEnd;

  return 0;
}
