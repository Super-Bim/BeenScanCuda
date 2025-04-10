#!/bin/bash
#
# Script de compilação para VanitySearch no Linux
#

# Detectar versão do CUDA
echo "Detectando instalação do CUDA..."

CUDA_FOUND=0
CUDA_PATH=""

# Verificar versões modernas do CUDA
for VERSION in 12.8 12.6 12.0 11.8 11.0; do
    if [ -d "/usr/local/cuda-$VERSION" ]; then
        CUDA_PATH="/usr/local/cuda-$VERSION"
        CUDA_FOUND=1
        echo "Encontrado CUDA $VERSION em $CUDA_PATH"
        break
    fi
done

# Verificar instalação genérica do CUDA
if [ $CUDA_FOUND -eq 0 ] && [ -d "/usr/local/cuda" ]; then
    CUDA_PATH="/usr/local/cuda"
    CUDA_FOUND=1
    CUDA_VERSION=$(ls -l $CUDA_PATH 2>/dev/null | grep -oP "cuda-\K[0-9]+\.[0-9]+" | head -1)
    echo "Encontrado CUDA em $CUDA_PATH (versão: $CUDA_VERSION)"
fi

if [ $CUDA_FOUND -eq 0 ]; then
    echo "CUDA não encontrado. Por favor, instale o CUDA Toolkit 11.0 ou superior."
    echo "Visite https://developer.nvidia.com/cuda-downloads para instruções."
    exit 1
fi

# Adicionar CUDA ao PATH e LD_LIBRARY_PATH se necessário
export PATH=$CUDA_PATH/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_PATH/lib64:$LD_LIBRARY_PATH

# Detectar capacidade computacional das GPUs disponíveis
echo "Verificando GPUs disponíveis..."
$CUDA_PATH/bin/deviceQuery 2>/dev/null | grep "CUDA Capability" | head -1

# Pegar um valor de CCAP padrão baseado na GPU detectada
CCAP=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader | head -1 | sed 's/\.//g')

if [ -z "$CCAP" ]; then
    echo "Não foi possível detectar a capacidade computacional da GPU."
    echo "Usando valor padrão CCAP=75 (Turing)."
    CCAP=75
else
    echo "Capacidade computacional detectada: $CCAP"
fi

# Verificar versão do GCC
GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)
GXX_CUDA=""

if [ $GCC_VERSION -gt 10 ]; then
    if command -v g++-10 &> /dev/null; then
        GXX_CUDA="CXXCUDA=g++-10"
        echo "Usando g++-10 para compatibilidade com CUDA"
    else
        echo "AVISO: Seu GCC $GCC_VERSION pode ser incompatível com CUDA."
        echo "Considere instalar GCC-10: sudo apt-get install gcc-10 g++-10"
    fi
fi

# Compilar
echo "Compilando VanitySearch com suporte a GPU..."
echo "make gpu=1 CCAP=$CCAP $GXX_CUDA"

make gpu=1 CCAP=$CCAP $GXX_CUDA

if [ $? -eq 0 ]; then
    echo "Compilação bem-sucedida!"
    echo "Execute com: ./VanitySearch -gpu <padrão>"
else
    echo "A compilação falhou. Verifique os erros acima."
    exit 1
fi 