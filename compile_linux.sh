#!/bin/bash

echo "Script de compilação para VanitySearch com CUDA 12.8 no Linux"
echo "============================================================="

# Apenas criar diretórios necessários
mkdir -p obj obj/GPU obj/hash GPU

# Verificar arquivos antes de compilar
if [ ! -f "main.cpp" ] || [ ! -f "Vanity.cpp" ] || [ ! -f "Vanity.h" ]; then
    echo "ERRO: Arquivos essenciais não encontrados!"
    exit 1
fi

# Verificar se CUDA está instalado
if command -v nvcc &> /dev/null; then
    echo "CUDA encontrado."
    CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -c2-)
    echo "Versão do CUDA detectada: $CUDA_VERSION"
    CUDA_PATH=$(dirname $(dirname $(which nvcc)))
    echo "CUDA path: $CUDA_PATH"
    GPU=1
else
    echo "CUDA não encontrado. Tentando compilar sem suporte a GPU."
    GPU=0
fi

# Verificar GPU engine
if [ $GPU -eq 1 ]; then
    # Verificar arquivos GPU
    if [ -f "GPU/GPUEngine_Linux.cu" ]; then
        echo "Usando GPU/GPUEngine_Linux.cu"
        cp GPU/GPUEngine_Linux.cu GPU/GPUEngine.cu
    elif [ -f "GPUEngine_Linux.cu" ]; then
        echo "Usando GPUEngine_Linux.cu do diretório raiz"
        cp GPUEngine_Linux.cu GPU/GPUEngine.cu
    elif [ ! -f "GPU/GPUEngine.cu" ]; then
        echo "ERRO: Nenhum arquivo GPUEngine.cu encontrado!"
        exit 1
    fi
    
    # Detectar compute capability
    if command -v nvidia-smi &> /dev/null; then
        CCAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -n 1 | tr -d '.')
        if [ -z "$CCAP" ]; then
            echo "Não foi possível detectar Compute Capability. Usando valor padrão (75)"
            CCAP=75
        else
            echo "Compute Capability detectada: $CCAP"
        fi
    else
        echo "nvidia-smi não encontrado. Usando Compute Capability padrão (75)"
        CCAP=75
    fi
fi

# Copiar ou criar Makefile
if [ -f "Makefile_Linux" ]; then
    cp Makefile_Linux Makefile
else
    echo "AVISO: Makefile_Linux não encontrado, criando Makefile básico..."
    cat > Makefile << EOF
# Makefile básico para VanitySearch
SRC = Base58.cpp IntGroup.cpp main.cpp Random.cpp Timer.cpp Int.cpp IntMod.cpp Point.cpp SECP256K1.cpp Vanity.cpp GPU/GPUGenerate.cpp hash/ripemd160.cpp hash/sha256.cpp hash/sha512.cpp hash/ripemd160_sse.cpp hash/sha256_sse.cpp Bech32.cpp Wildcard.cpp

OBJDIR = obj
CXX = g++
CUDA = $CUDA_PATH
CXXFLAGS = -m64 -mssse3 -Wno-write-strings -O2

all: VanitySearch

VanitySearch: \$(SRC)
	@echo "Compilando VanitySearch..."
	\$(CXX) \$(CXXFLAGS) \$(SRC) -lpthread -o VanitySearch

clean:
	@rm -f VanitySearch
EOF

    if [ $GPU -eq 1 ]; then
        # Adicionar suporte a GPU no Makefile
        sed -i 's/CXXFLAGS = -m64/CXXFLAGS = -DWITHGPU -m64/' Makefile
        sed -i "s|CUDA = $CUDA_PATH|CUDA = $CUDA_PATH\nNVCC = \$(CUDA)/bin/nvcc|" Makefile
        sed -i 's|-lpthread|-lpthread -L$(CUDA)/lib64 -lcudart|' Makefile
        sed -i 's|$(CXX) $(CXXFLAGS) $(SRC) -lpthread -o VanitySearch|$(CXX) $(CXXFLAGS) -I$(CUDA)/include $(SRC) -lpthread -L$(CUDA)/lib64 -lcudart -o VanitySearch\n\t$(NVCC) -maxrregcount=0 --ptxas-options=-v --compile --compiler-options -fPIC -m64 -O2 -I$(CUDA)/include -gencode=arch=compute_'$CCAP',code=sm_'$CCAP' -o obj/GPU/GPUEngine.o -c GPU/GPUEngine.cu|' Makefile
    fi
fi

# Compilar
echo "Compilando..."
if [ $GPU -eq 1 ]; then
    make gpu=1 CCAP=$CCAP -j$(nproc)
else
    make -j$(nproc)
fi

# Verificar se o executável foi criado
if [ -f "VanitySearch" ]; then
    chmod +x VanitySearch
    echo "============================================================="
    echo "Compilação concluída com sucesso!"
    echo "Para executar o programa, use: ./VanitySearch -h"
    echo "============================================================="
else
    echo "ERRO: Executável VanitySearch não encontrado após compilação."
    echo "Verificando erros mais comuns:"
    
    if [ $GPU -eq 1 ] && [ ! -f "obj/GPU/GPUEngine.o" ]; then
        echo "- Falha ao compilar GPU/GPUEngine.cu"
        echo "  Tentando compilar sem suporte a GPU..."
        sed -i 's/CXXFLAGS = -DWITHGPU -m64/CXXFLAGS = -m64/' Makefile
        make clean
        make -j$(nproc)
        
        if [ -f "VanitySearch" ]; then
            chmod +x VanitySearch
            echo "============================================================="
            echo "Compilação sem GPU concluída com sucesso!"
            echo "Para executar o programa, use: ./VanitySearch -h"
            echo "============================================================="
            exit 0
        fi
    fi
    
    echo "Falha na compilação. Por favor, verifique os erros acima."
    exit 1
fi 