#!/bin/bash
#
# Script de compilação passo a passo para VanitySearch no Linux
#

# Configurações de cores para saída
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Script de compilação detalhado para VanitySearch${NC}"
echo "Este script vai compilar passo a passo e verificar cada etapa"

# Detectar versão do CUDA
echo -e "\n${YELLOW}Detectando instalação do CUDA...${NC}"

CUDA_FOUND=0
CUDA_PATH=""

# Verificar versões modernas do CUDA
for VERSION in 12.8 12.6 12.0 11.8 11.0; do
    if [ -d "/usr/local/cuda-$VERSION" ]; then
        CUDA_PATH="/usr/local/cuda-$VERSION"
        CUDA_FOUND=1
        echo -e "${GREEN}Encontrado CUDA $VERSION em $CUDA_PATH${NC}"
        break
    fi
done

# Verificar instalação genérica do CUDA
if [ $CUDA_FOUND -eq 0 ] && [ -d "/usr/local/cuda" ]; then
    CUDA_PATH="/usr/local/cuda"
    CUDA_FOUND=1
    CUDA_VERSION=$(ls -l $CUDA_PATH 2>/dev/null | grep -oP "cuda-\K[0-9]+\.[0-9]+" | head -1)
    echo -e "${GREEN}Encontrado CUDA em $CUDA_PATH (versão: $CUDA_VERSION)${NC}"
fi

if [ $CUDA_FOUND -eq 0 ]; then
    echo -e "${RED}CUDA não encontrado. Por favor, instale o CUDA Toolkit 11.0 ou superior.${NC}"
    echo "Visite https://developer.nvidia.com/cuda-downloads para instruções."
    exit 1
fi

# Adicionar CUDA ao PATH e LD_LIBRARY_PATH se necessário
export PATH=$CUDA_PATH/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_PATH/lib64:$LD_LIBRARY_PATH

# Detectar capacidade computacional das GPUs disponíveis
echo -e "\n${YELLOW}Verificando GPUs disponíveis...${NC}"
$CUDA_PATH/bin/deviceQuery 2>/dev/null | grep "CUDA Capability" | head -1

# Pegar um valor de CCAP padrão baseado na GPU detectada
CCAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | sed 's/\.//g')

if [ -z "$CCAP" ]; then
    echo -e "${YELLOW}Não foi possível detectar a capacidade computacional da GPU.${NC}"
    echo "Usando valor padrão CCAP=75 (Turing)."
    CCAP=75
else
    echo -e "${GREEN}Capacidade computacional detectada: $CCAP${NC}"
fi

# Verificar versão do GCC
GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)

# Detectar versão do CUDA para determinar compatibilidade com GCC 11
CUDA_VERSION_MAJOR=$(echo $CUDA_PATH | grep -oP "cuda-\K[0-9]+" || echo 0)
CUDA_VERSION_MINOR=$(echo $CUDA_PATH | grep -oP "cuda-[0-9]+\.\K[0-9]+" || echo 0)

# Se não conseguir extrair, tente pelo nvcc
if [ "$CUDA_VERSION_MAJOR" = "0" ]; then
    CUDA_VERSION_STR=$($CUDA_PATH/bin/nvcc --version | grep "release" | awk '{print $6}' | cut -d, -f1)
    CUDA_VERSION_MAJOR=$(echo $CUDA_VERSION_STR | cut -d. -f1)
    CUDA_VERSION_MINOR=$(echo $CUDA_VERSION_STR | cut -d. -f2)
fi

GXX_CUDA=""
NVCC_COMPAT_FLAGS=""

echo -e "\n${YELLOW}Informações de versão:${NC}"
echo "Versão CUDA: $CUDA_VERSION_MAJOR.$CUDA_VERSION_MINOR"
echo "Versão GCC: $GCC_VERSION"

# Para CUDA 11.4 ou superior, GCC 11 é suportado oficialmente
if [ "$GCC_VERSION" -gt "10" ]; then
    if [ "$CUDA_VERSION_MAJOR" -ge "11" ] && [ "$CUDA_VERSION_MINOR" -ge "4" ]; then
        echo -e "${GREEN}CUDA $CUDA_VERSION_MAJOR.$CUDA_VERSION_MINOR suporta GCC $GCC_VERSION${NC}"
    elif command -v g++-10 &> /dev/null; then
        GXX_CUDA="CXXCUDA=g++-10"
        echo -e "${YELLOW}Usando g++-10 para compatibilidade com CUDA${NC}"
    else
        echo -e "${YELLOW}AVISO: Seu GCC $GCC_VERSION pode ser incompatível com CUDA $CUDA_VERSION_MAJOR.$CUDA_VERSION_MINOR${NC}"
        echo "Tentando compilar com flag de compatibilidade não suportada"
        NVCC_COMPAT_FLAGS="NVCC_COMPAT_FLAGS=--allow-unsupported-compiler"
        echo "Se a compilação falhar, instale GCC-10: sudo apt-get install gcc-10 g++-10"
    fi
fi

# Limpeza antes de compilar
echo -e "\n${YELLOW}Limpando compilação anterior...${NC}"
make clean
echo -e "${GREEN}Limpeza concluída${NC}"

# Criar diretórios de saída manualmente
echo -e "\n${YELLOW}Criando diretórios de compilação...${NC}"
mkdir -p obj
mkdir -p obj/GPU
mkdir -p obj/hash
echo -e "${GREEN}Diretórios criados${NC}"

# Começar a compilar somente o arquivo CUDA primeiro
echo -e "\n${YELLOW}Compilando apenas o arquivo CUDA...${NC}"
COMPILE_CMD="$CUDA_PATH/bin/nvcc -maxrregcount=0 --ptxas-options=-v $NVCC_COMPAT_FLAGS --compile --compiler-options -fPIC -ccbin ${CXXCUDA:-g++} -m64 -O2 -I. -I$CUDA_PATH/include -gencode=arch=compute_$CCAP,code=sm_$CCAP -o obj/GPU/GPUEngine.o -c GPU/GPUEngine.cu"
echo "Executando: $COMPILE_CMD"
eval $COMPILE_CMD

if [ $? -ne 0 ]; then
    echo -e "${RED}Falha ao compilar GPUEngine.cu${NC}"
    exit 1
else
    echo -e "${GREEN}Arquivo CUDA compilado com sucesso${NC}"
fi

# Agora vamos compilar cada arquivo CPP individualmente
echo -e "\n${YELLOW}Compilando arquivos C++...${NC}"

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
    else
        echo -e "${GREEN}$file compilado com sucesso${NC}"
    fi
done

# Linkar todos os objetos
echo -e "\n${YELLOW}Linkando todos os arquivos objeto...${NC}"
echo "Objetos a serem linkados:"
find obj -name "*.o" | sort

LINK_CMD="g++ $(find obj -name '*.o' | sort) -lpthread -L$CUDA_PATH/lib64 -lcudart -o VanitySearch"
echo "Executando: $LINK_CMD"
eval $LINK_CMD

if [ $? -ne 0 ]; then
    echo -e "${RED}Falha na linkagem dos objetos${NC}"
    exit 1
else
    echo -e "${GREEN}Linkagem bem-sucedida!${NC}"
fi

# Verificar se o executável foi criado
if [ -f "VanitySearch" ]; then
    echo -e "\n${GREEN}Compilação completa! Executável VanitySearch criado com sucesso.${NC}"
    echo "Execute com: ./VanitySearch -gpu <padrão>"
    # Tornar o arquivo executável
    chmod +x VanitySearch
else
    echo -e "\n${RED}Erro: O executável VanitySearch não foi criado!${NC}"
    exit 1
fi 
