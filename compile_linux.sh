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
cp Timer_Linux.cpp Timer.cpp
cp Timer_Linux.h Timer.h
cp Vanity_Linux.cpp Vanity.cpp
cp GPUEngine_Linux.cu GPUEngine.cu
cp Makefile_Linux Makefile

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

if [ $? -eq 0 ]; then
    echo "============================================================="
    echo "Compilação concluída com sucesso!"
    echo "Para executar o programa, use: ./VanitySearch -h"
    echo "============================================================="
else
    echo "ERRO: A compilação falhou!"
    exit 1
fi

# Tornar executável
chmod +x VanitySearch 