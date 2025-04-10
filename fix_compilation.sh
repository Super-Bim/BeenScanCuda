#!/bin/bash
#
# Script para detectar e corrigir problemas comuns na compilação
#

# Cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Verificando e corrigindo problemas na compilação VanitySearch${NC}"

# Detectar o CUDA
CUDA_PATH=""
if [ -d "/usr/local/cuda" ]; then
    CUDA_PATH="/usr/local/cuda"
    echo -e "${GREEN}Detectado CUDA em $CUDA_PATH${NC}"
else
    # Tentar encontrar versões específicas
    for VER in 12.8 12.6 12.0 11.8 11.0 10.2; do
        if [ -d "/usr/local/cuda-$VER" ]; then
            CUDA_PATH="/usr/local/cuda-$VER"
            echo -e "${GREEN}Detectado CUDA $VER em $CUDA_PATH${NC}"
            break
        fi
    done
fi

if [ -z "$CUDA_PATH" ]; then
    echo -e "${RED}Não foi possível encontrar o CUDA. Por favor, instale-o primeiro.${NC}"
    exit 1
fi

# Adicionar CUDA ao PATH e LD_LIBRARY_PATH
export PATH=$CUDA_PATH/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_PATH/lib64:$LD_LIBRARY_PATH

# Verificar versão do GCC
GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)
echo -e "${YELLOW}Versão do GCC: $GCC_VERSION${NC}"

# Verificar versão do CUDA
CUDA_VERSION=$($CUDA_PATH/bin/nvcc --version | grep release | awk '{print $6}' | cut -d, -f1)
echo -e "${YELLOW}Versão do CUDA: $CUDA_VERSION${NC}"

# Verificar se o Makefile tem regra .PHONY
if ! grep -q "\.PHONY" Makefile; then
    echo -e "${YELLOW}Adicionando regra .PHONY ao Makefile...${NC}"
    sed -i '1i .PHONY: all clean' Makefile
    echo -e "${GREEN}Regra .PHONY adicionada${NC}"
fi

# Limpar compilação anterior
echo -e "${YELLOW}Limpando compilação anterior...${NC}"
make clean

# Verificar e criar diretórios
echo -e "${YELLOW}Verificando diretórios de compilação...${NC}"
mkdir -p obj obj/GPU obj/hash
echo -e "${GREEN}Diretórios verificados e criados${NC}"

# Detectar compatibilidade do GCC com CUDA
CUDA_MAJOR=$(echo $CUDA_VERSION | cut -d. -f1)
CUDA_MINOR=$(echo $CUDA_VERSION | cut -d. -f2)

COMPATIBLE_GCC=true
NEED_GCC10=false

if [ "$GCC_VERSION" -gt "10" ]; then
    if [ "$CUDA_MAJOR" -lt "11" ] || ([ "$CUDA_MAJOR" -eq "11" ] && [ "$CUDA_MINOR" -lt "4" ]); then
        COMPATIBLE_GCC=false
        if command -v g++-10 &> /dev/null; then
            NEED_GCC10=true
            echo -e "${YELLOW}Seu GCC $GCC_VERSION pode ser incompatível com CUDA $CUDA_VERSION.${NC}"
            echo -e "${GREEN}Usando g++-10 para compilação.${NC}"
        else
            echo -e "${YELLOW}Seu GCC $GCC_VERSION pode ser incompatível com CUDA $CUDA_VERSION.${NC}"
            echo -e "${YELLOW}Tentando compilar com flag de compatibilidade não suportada.${NC}"
        fi
    fi
fi

# Tentar primeiro compilar com método normal
echo -e "${YELLOW}Tentando compilação normal...${NC}"
if [ "$NEED_GCC10" = true ]; then
    make gpu=1 CCAP=75 CXXCUDA=g++-10
else
    if [ "$COMPATIBLE_GCC" = false ]; then
        make gpu=1 CCAP=75 NVCC_COMPAT_FLAGS=--allow-unsupported-compiler
    else
        make gpu=1 CCAP=75
    fi
fi

# Verificar se o executável foi criado
if [ -f "VanitySearch" ]; then
    echo -e "${GREEN}Compilação bem-sucedida!${NC}"
    chmod +x VanitySearch
    echo -e "${GREEN}Executável pronto para uso.${NC}"
    exit 0
fi

echo -e "${YELLOW}Compilação normal falhou. Tentando método alternativo...${NC}"

# Se falhou, tente compilar manualmente
echo -e "${YELLOW}Compilando primeiramente o arquivo CUDA...${NC}"

if [ "$NEED_GCC10" = true ]; then
    COMPILE_CMD="$CUDA_PATH/bin/nvcc -maxrregcount=0 --ptxas-options=-v --compile --compiler-options -fPIC -ccbin g++-10 -m64 -O2 -I. -I$CUDA_PATH/include -gencode=arch=compute_75,code=sm_75 -o obj/GPU/GPUEngine.o -c GPU/GPUEngine.cu"
else
    if [ "$COMPATIBLE_GCC" = false ]; then
        COMPILE_CMD="$CUDA_PATH/bin/nvcc -maxrregcount=0 --ptxas-options=-v --allow-unsupported-compiler --compile --compiler-options -fPIC -ccbin g++ -m64 -O2 -I. -I$CUDA_PATH/include -gencode=arch=compute_75,code=sm_75 -o obj/GPU/GPUEngine.o -c GPU/GPUEngine.cu"
    else
        COMPILE_CMD="$CUDA_PATH/bin/nvcc -maxrregcount=0 --ptxas-options=-v --compile --compiler-options -fPIC -ccbin g++ -m64 -O2 -I. -I$CUDA_PATH/include -gencode=arch=compute_75,code=sm_75 -o obj/GPU/GPUEngine.o -c GPU/GPUEngine.cu"
    fi
fi

echo "Executando: $COMPILE_CMD"
eval $COMPILE_CMD

if [ $? -ne 0 ]; then
    echo -e "${RED}Falha ao compilar o arquivo CUDA${NC}"
    exit 1
fi
echo -e "${GREEN}Arquivo CUDA compilado com sucesso${NC}"

# Agora compila os arquivos C++
echo -e "${YELLOW}Compilando arquivos C++...${NC}"

CPP_FILES=(
    "Base58.cpp"
    "IntGroup.cpp"
    "main.cpp"
    "Random.cpp"
    "Timer.cpp"
    "Int.cpp"
    "IntMod.cpp"
    "Point.cpp"
    "SECP256K1.cpp"
    "Vanity.cpp"
    "GPU/GPUGenerate.cpp"
    "hash/ripemd160.cpp"
    "hash/sha256.cpp"
    "hash/sha512.cpp"
    "hash/ripemd160_sse.cpp"
    "hash/sha256_sse.cpp"
    "Bech32.cpp"
    "Wildcard.cpp"
)

CPP_COMPILE_FLAGS="-DWITHGPU -m64 -mssse3 -Wno-write-strings -O2 -I. -I$CUDA_PATH/include"

for file in "${CPP_FILES[@]}"; do
    echo "Compilando $file..."
    out_file=$(echo "$file" | sed 's/\.cpp$/\.o/')
    out_path="obj/$out_file"
    
    # Criar diretório se não existir
    out_dir=$(dirname "$out_path")
    mkdir -p "$out_dir"
    
    g++ $CPP_COMPILE_FLAGS -o "$out_path" -c "$file"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Falha ao compilar $file${NC}"
        exit 1
    fi
done
echo -e "${GREEN}Todos os arquivos C++ compilados com sucesso${NC}"

# Linkar tudo
echo -e "${YELLOW}Linkando todos os arquivos objeto...${NC}"
g++ $(find obj -name "*.o" | sort) -lpthread -L$CUDA_PATH/lib64 -lcudart -o VanitySearch

if [ $? -ne 0 ]; then
    echo -e "${RED}Falha na linkagem${NC}"
    exit 1
fi

# Verificação final
if [ -f "VanitySearch" ]; then
    echo -e "${GREEN}Compilação manual bem-sucedida!${NC}"
    chmod +x VanitySearch
    echo -e "${GREEN}Executável VanitySearch criado.${NC}"
else
    echo -e "${RED}Falha ao criar o executável${NC}"
    exit 1
fi 