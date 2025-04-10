#!/bin/bash

echo "Script de compilação para VanitySearch com CUDA 12.8 no Linux"
echo "============================================================="

# Verificar se CUDA está instalado
if ! command -v nvcc &> /dev/null; then
    echo "ERRO: NVCC não encontrado. O CUDA Toolkit 12.8 está instalado?"
    echo "Para instalar o CUDA 12.8, execute:"
    echo "wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_545.23.08_linux.run"
    echo "sudo sh cuda_12.8.0_545.23.08_linux.run"
    exit 1
fi

# Verificar versão do CUDA
CUDA_VERSION=$(nvcc --version | grep "release" | awk '{print $6}' | cut -c2-)
echo "Versão do CUDA detectada: $CUDA_VERSION"

# Copiar arquivos Linux
echo "Copiando arquivos específicos para Linux..."
cp Timer_Linux.cpp Timer.cpp 2>/dev/null || echo "Aviso: Timer_Linux.cpp não encontrado"
cp Timer_Linux.h Timer.h 2>/dev/null || echo "Aviso: Timer_Linux.h não encontrado"
cp Vanity_Linux.cpp Vanity.cpp 2>/dev/null || echo "Aviso: Vanity_Linux.cpp não encontrado"
cp GPUEngine_Linux.cu GPU/GPUEngine.cu 2>/dev/null || echo "Aviso: GPUEngine_Linux.cu não encontrado"
cp Makefile_Linux Makefile 2>/dev/null || echo "Aviso: Makefile_Linux não encontrado"

# Verificar se todos os arquivos necessários existem
if [ ! -f "Makefile" ]; then
    echo "ERRO: Arquivo Makefile não encontrado. A cópia falhou."
    exit 1
fi

# Verificar se diretório GPU existe
if [ ! -d "GPU" ]; then
    echo "ERRO: Diretório GPU não encontrado."
    echo "Criando diretório GPU..."
    mkdir -p GPU
fi

# Detectar GPU e definir compute capability
if command -v nvidia-smi &> /dev/null; then
    echo "Detectando GPU..."
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n 1)
    echo "GPU detectada: $GPU_NAME"
    
    # Detectar compute capability com base no nome da GPU
    # Esta é uma simplificação e pode não cobrir todos os modelos
    if [[ $GPU_NAME == *"RTX 40"* ]]; then
        CCAP="89"
    elif [[ $GPU_NAME == *"RTX 30"* ]]; then
        CCAP="86"
    elif [[ $GPU_NAME == *"RTX 20"* || $GPU_NAME == *"GTX 16"* ]]; then
        CCAP="75"
    elif [[ $GPU_NAME == *"GTX 10"* ]]; then
        CCAP="61"
    elif [[ $GPU_NAME == *"GTX 9"* ]]; then
        CCAP="52"
    else
        CCAP="75" # Default para GPUs mais recentes
    fi
    
    echo "Compute Capability definida para: $CCAP"
else
    CCAP="75" # Default
    echo "nvidia-smi não encontrado. Usando Compute Capability padrão: $CCAP"
fi

# Compilar
echo "Compilando com suporte a GPU..."
make gpu=1 CCAP=$CCAP

# Verificar se a compilação foi bem-sucedida
if [ $? -eq 0 ]; then
    # Verificar se o arquivo executável foi criado
    if [ -f "VanitySearch" ]; then
        # Tornar executável
        chmod +x VanitySearch
        echo "============================================================="
        echo "Compilação concluída com sucesso!"
        echo "Para executar o programa, use: ./VanitySearch -h"
        echo "============================================================="
    else
        echo "ERRO: Arquivo VanitySearch não foi criado apesar da compilação ter sido bem-sucedida."
        echo "Verifique o Makefile para garantir que o nome do arquivo de saída está correto."
        exit 1
    fi
else
    echo "ERRO: A compilação falhou!"
    exit 1
fi 