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
#include <stdio.h>
#include <stdlib.h>

static const char *prefix[] = { "","Kilo","Mega","Giga","Tera","Peta","Hexa" };

#ifdef WIN32
LARGE_INTEGER Timer::perfTickStart;
double Timer::perfTicksPerSec;
LARGE_INTEGER Timer::qwTicksPerSec;
#include <wincrypt.h>
#else
struct timespec Timer::startTime;
double Timer::startTick;
#include <fcntl.h>
#endif

void Timer::Init() {
#ifdef WIN32
  QueryPerformanceFrequency(&qwTicksPerSec);
  QueryPerformanceCounter(&perfTickStart);
  perfTicksPerSec = (double)qwTicksPerSec.QuadPart;
#else
  clock_gettime(CLOCK_MONOTONIC, &startTime);
  startTick = 0;
#endif
}

double Timer::get_tick() {
#ifdef WIN32
  LARGE_INTEGER t, dt;
  QueryPerformanceCounter(&t);
  dt.QuadPart = t.QuadPart - perfTickStart.QuadPart;
  return (double)(dt.QuadPart) / perfTicksPerSec;
#else
  struct timespec currentTime;
  clock_gettime(CLOCK_MONOTONIC, &currentTime);
  return (double)(currentTime.tv_sec - startTime.tv_sec) + 
         (double)(currentTime.tv_nsec - startTime.tv_nsec) / 1e9;
#endif
}

std::string Timer::getSeed(int size) {
  std::string ret;
  char tmp[3];
  unsigned char *buff = (unsigned char *)malloc(size);

#ifdef WIN32
  HCRYPTPROV   hCryptProv = NULL;
  LPCSTR UserName = "KeyContainer";

  if (!CryptAcquireContext(
    &hCryptProv,               // handle to the CSP
    UserName,                  // container name
    NULL,                      // use the default provider
    PROV_RSA_FULL,             // provider type
    0))                        // flag values
  {
    //-------------------------------------------------------------------
    // An error occurred in acquiring the context. This could mean
    // that the key container requested does not exist. In this case,
    // the function can be called again to attempt to create a new key
    // container. Error codes are defined in Winerror.h.
    if (GetLastError() == NTE_BAD_KEYSET) {
      if (!CryptAcquireContext(
        &hCryptProv,
        UserName,
        NULL,
        PROV_RSA_FULL,
        CRYPT_NEWKEYSET)) {
        printf("CryptAcquireContext(): Could not create a new key container.\n");
        exit(1);
      }
    } else {
      printf("CryptAcquireContext(): A cryptographic service handle could not be acquired.\n");
      exit(1);
    }
  }

  if (!CryptGenRandom(hCryptProv,size,buff)) {
    printf("CryptGenRandom(): Error during random sequence acquisition.\n");
    exit(1);
  }

  CryptReleaseContext(hCryptProv, 0);
#else
  int f = open("/dev/urandom", O_RDONLY);
  if (f < 0) {
    printf("Failed to open /dev/urandom\n");
    exit(1);
  }
  
  if (read(f, buff, size) != size) {
    printf("Failed to read from /dev/urandom\n");
    exit(1);
  }
  
  close(f);
#endif

  for (int i = 0; i < size; i++) {
    sprintf(tmp,"%02X",buff[i]);
    ret.append(tmp);
  }

  free(buff);
  return ret;
}

uint32_t Timer::getSeed32() {
  return ::strtoul(getSeed(4).c_str(),NULL,16);
}

std::string Timer::getResult(char *unit, int nbTry, double t0, double t1) {

  char tmp[256];
  int pIdx = 0;
  double nbCallPerSec = (double)nbTry / (t1 - t0);
  while (nbCallPerSec > 1000.0 && pIdx < 5) {
    pIdx++;
    nbCallPerSec = nbCallPerSec / 1000.0;
  }
  sprintf(tmp, "%.3f %s%s/sec", nbCallPerSec, prefix[pIdx], unit);
  return std::string(tmp);

}

void Timer::printResult(char *unit, int nbTry, double t0, double t1) {

  printf("%s\n", getResult(unit, nbTry, t0, t1).c_str());

}

int Timer::getCoreNumber() {
#ifdef WIN32
  SYSTEM_INFO sysinfo;
  GetSystemInfo(&sysinfo);
  return sysinfo.dwNumberOfProcessors;
#else
  int numCPU = sysconf(_SC_NPROCESSORS_ONLN);
  return numCPU;
#endif
}

void Timer::SleepMillis(uint32_t millis) {
#ifdef WIN32
  Sleep(millis);
#else
  usleep(millis * 1000);
#endif
}
