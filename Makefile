#---------------------------------------------------------------------
# Makefile for VanitySearch
#
# Author : Jean-Luc PONS

SRC = Base58.cpp IntGroup.cpp main.cpp Random.cpp \
      Timer.cpp Int.cpp IntMod.cpp Point.cpp SECP256K1.cpp \
      Vanity.cpp GPU/GPUGenerate.cpp hash/ripemd160.cpp \
      hash/sha256.cpp hash/sha512.cpp hash/ripemd160_sse.cpp \
      hash/sha256_sse.cpp Bech32.cpp Wildcard.cpp

OBJDIR = obj

ifdef gpu

OBJET = $(addprefix $(OBJDIR)/, \
        Base58.o IntGroup.o main.o Random.o Timer.o Int.o \
        IntMod.o Point.o SECP256K1.o Vanity.o GPU/GPUGenerate.o \
        hash/ripemd160.o hash/sha256.o hash/sha512.o \
        hash/ripemd160_sse.o hash/sha256_sse.o \
        GPU/GPUEngine.o Bech32.o Wildcard.o)

else

OBJET = $(addprefix $(OBJDIR)/, \
        Base58.o IntGroup.o main.o Random.o Timer.o Int.o \
        IntMod.o Point.o SECP256K1.o Vanity.o GPU/GPUGenerate.o \
        hash/ripemd160.o hash/sha256.o hash/sha512.o \
        hash/ripemd160_sse.o hash/sha256_sse.o Bech32.o Wildcard.o)

endif

CXX        = g++

# Detectar versão do CUDA, usar as mais recentes se disponíveis
CUDA_PATH   ?= /usr/local/cuda
ifneq ($(wildcard /usr/local/cuda-12.8),)
CUDA       = /usr/local/cuda-12.8
else ifneq ($(wildcard /usr/local/cuda-12.6),)
CUDA       = /usr/local/cuda-12.6
else ifneq ($(wildcard /usr/local/cuda-12.0),)
CUDA       = /usr/local/cuda-12.0
else ifneq ($(wildcard /usr/local/cuda-11.8),)
CUDA       = /usr/local/cuda-11.8
else ifneq ($(wildcard /usr/local/cuda-11.0),)
CUDA       = /usr/local/cuda-11.0
else
CUDA       = /usr/local/cuda
endif

# Verificar compilador compatível com o CUDA
CUDA_GCC_VER = $(shell $(CUDA)/bin/nvcc -V | grep release | sed 's/.*release //' | sed 's/,.*//')
GCC_VER_MAJOR = $(shell g++ -dumpversion | cut -d'.' -f1)

# Para CUDA 11.4+ e posteriores, GCC até 11 é suportado
CUDA_VERSION_MAJOR = $(shell ls -la $(CUDA) 2>/dev/null | grep -oP "cuda-\K[0-9]+" | head -1)
CUDA_VERSION_MINOR = $(shell ls -la $(CUDA) 2>/dev/null | grep -oP "cuda-[0-9]+\.\K[0-9]+" | head -1)

# Usar GCC original se CUDA for 11.4+ (suporta GCC 11)
# ou se GCC for <= 10
ifeq ($(shell test $(CUDA_VERSION_MAJOR) -ge 11 -a $(CUDA_VERSION_MINOR) -ge 4 && echo true),true)
CXXCUDA     = g++
else
ifeq ($(shell test $(GCC_VER_MAJOR) -le 10 && echo true),true)
CXXCUDA     = g++
else
# Para CUDA <11.4 com GCC >10, tente usar GCC-10 se disponível
ifneq ($(shell which g++-10 2>/dev/null),)
CXXCUDA     = g++-10
else
# Como último recurso, use GCC atual com flags para compatibilidade
CXXCUDA     = g++
NVCC_COMPAT_FLAGS = --allow-unsupported-compiler
endif
endif
endif

NVCC       = $(CUDA)/bin/nvcc
# nvcc requires joint notation w/o dot, i.e. "5.2" -> "52"
ccap       = $(shell echo $(CCAP) | tr -d '.')

ifdef gpu
ifdef debug
CXXFLAGS   = -DWITHGPU -m64  -mssse3 -Wno-write-strings -g -I. -I$(CUDA)/include
else
CXXFLAGS   =  -DWITHGPU -m64 -mssse3 -Wno-write-strings -O2 -I. -I$(CUDA)/include
endif
LFLAGS     = -lpthread -L$(CUDA)/lib64 -lcudart
else
ifdef debug
CXXFLAGS   = -m64 -mssse3 -Wno-write-strings -g -I. -I$(CUDA)/include
else
CXXFLAGS   =  -m64 -mssse3 -Wno-write-strings -O2 -I. -I$(CUDA)/include
endif
LFLAGS     = -lpthread
endif


#--------------------------------------------------------------------

ifdef gpu
ifdef debug
$(OBJDIR)/GPU/GPUEngine.o: GPU/GPUEngine.cu
	$(NVCC) -G -maxrregcount=0 --ptxas-options=-v $(NVCC_COMPAT_FLAGS) --compile --compiler-options -fPIC -ccbin $(CXXCUDA) -m64 -g -I$(CUDA)/include -gencode=arch=compute_$(ccap),code=sm_$(ccap) -o $(OBJDIR)/GPU/GPUEngine.o -c GPU/GPUEngine.cu
else
$(OBJDIR)/GPU/GPUEngine.o: GPU/GPUEngine.cu
	$(NVCC) -maxrregcount=0 --ptxas-options=-v $(NVCC_COMPAT_FLAGS) --compile --compiler-options -fPIC -ccbin $(CXXCUDA) -m64 -O2 -I$(CUDA)/include -gencode=arch=compute_$(ccap),code=sm_$(ccap) -o $(OBJDIR)/GPU/GPUEngine.o -c GPU/GPUEngine.cu
endif
endif

$(OBJDIR)/%.o : %.cpp
	$(CXX) $(CXXFLAGS) -o $@ -c $<

# Definir all como alvo padrão no topo
.PHONY: all clean

all: VanitySearch

VanitySearch: $(OBJET)
	@echo "Making VanitySearch..."
	$(CXX) $(OBJET) $(LFLAGS) -o VanitySearch
	@echo "VanitySearch compiled successfully."
	@if [ -f VanitySearch ]; then chmod +x VanitySearch; fi

$(OBJET): | $(OBJDIR) $(OBJDIR)/GPU $(OBJDIR)/hash

$(OBJDIR):
	mkdir -p $(OBJDIR)

$(OBJDIR)/GPU: $(OBJDIR)
	cd $(OBJDIR) &&	mkdir -p GPU

$(OBJDIR)/hash: $(OBJDIR)
	cd $(OBJDIR) &&	mkdir -p hash

clean:
	@echo Cleaning...
	@rm -f obj/*.o
	@rm -f obj/GPU/*.o
	@rm -f obj/hash/*.o

