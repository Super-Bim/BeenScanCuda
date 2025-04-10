#!/bin/bash
#
# Script para detectar a GPU e compilar com a capacidade computacional correta
#

echo "Detectando GPU e compilando VanitySearch..."

# Detectar CUDA
CUDA_PATH=""
for VER in 12.8 12.6 12.0 11.8 11.0 10.2; do
    if [ -d "/usr/local/cuda-$VER" ]; then
        CUDA_PATH="/usr/local/cuda-$VER"
        echo "Detectado CUDA $VER em $CUDA_PATH"
        break
    fi
done

if [ -z "$CUDA_PATH" ] && [ -d "/usr/local/cuda" ]; then
    CUDA_PATH="/usr/local/cuda"
    echo "Detectado CUDA em $CUDA_PATH"
fi

if [ -z "$CUDA_PATH" ]; then
    echo "CUDA não encontrado. Por favor, instale o CUDA primeiro."
    exit 1
fi

# Adicionar CUDA ao PATH
export PATH=$CUDA_PATH/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_PATH/lib64:$LD_LIBRARY_PATH

# Detectar capacidade computacional da GPU
COMPUTE_CAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1)
if [ -z "$COMPUTE_CAP" ]; then
    echo "Erro: Não foi possível detectar a capacidade computacional da GPU."
    echo "Verifique se nvidia-smi está instalado e a GPU está detectada."
    exit 1
fi

# Remover o ponto da capacidade computacional
CCAP=$(echo $COMPUTE_CAP | tr -d '.')
echo "Capacidade computacional detectada: $COMPUTE_CAP (CCAP=$CCAP)"

# Verificar GCC
GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)
echo "Versão GCC: $GCC_VERSION"

# Opções extras para GCC incompatível
EXTRA_OPTS=""
if [ "$GCC_VERSION" -gt "10" ]; then
    CUDA_VERSION_MAJOR=$(echo "$CUDA_PATH" | grep -oP "cuda-\K[0-9]+" || echo "$($CUDA_PATH/bin/nvcc --version | grep release | awk '{print $6}' | cut -d. -f1)")
    CUDA_VERSION_MINOR=$(echo "$CUDA_PATH" | grep -oP "cuda-[0-9]+\.\K[0-9]+" || echo "$($CUDA_PATH/bin/nvcc --version | grep release | awk '{print $6}' | cut -d. -f2)")
    
    if [ -z "$CUDA_VERSION_MAJOR" ] || [ -z "$CUDA_VERSION_MINOR" ]; then
        CUDA_VERSION_STR=$($CUDA_PATH/bin/nvcc --version | grep "release" | awk '{print $6}' | cut -d, -f1)
        CUDA_VERSION_MAJOR=$(echo $CUDA_VERSION_STR | cut -d. -f1)
        CUDA_VERSION_MINOR=$(echo $CUDA_VERSION_STR | cut -d. -f2)
    fi
    
    if [ "$CUDA_VERSION_MAJOR" -lt "11" ] || ([ "$CUDA_VERSION_MAJOR" -eq "11" ] && [ "$CUDA_VERSION_MINOR" -lt "4" ]); then
        if command -v g++-10 &> /dev/null; then
            echo "Usando g++-10 para compatibilidade com CUDA"
            EXTRA_OPTS="CXXCUDA=g++-10"
        else
            echo "AVISO: GCC $GCC_VERSION pode ser incompatível com CUDA $CUDA_VERSION_MAJOR.$CUDA_VERSION_MINOR"
            echo "Tentando compilar com flag de compatibilidade não suportada"
            EXTRA_OPTS="NVCC_COMPAT_FLAGS=--allow-unsupported-compiler"
        fi
    fi
fi

# Limpar antes de compilar
echo "Limpando compilação anterior..."
make clean

# Compilar
echo "Compilando com CCAP=$CCAP..."
make gpu=1 CCAP=$CCAP $EXTRA_OPTS

if [ $? -eq 0 ]; then
    echo "Compilação concluída com sucesso!"
    echo "Execute com: ./VanitySearch -gpu <padrão>"
    chmod +x VanitySearch
else
    echo "Erro na compilação."
    exit 1
fi 