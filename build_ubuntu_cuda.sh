#!/bin/bash

# Script para compilar VanitySearch com CUDA 12.8 no Ubuntu 22.4
# Autor: AI Assistant

# Verificar se CUDA 12.8 está instalado
if [ ! -d "/usr/local/cuda-12.8" ]; then
    echo "ERRO: CUDA 12.8 não encontrado em /usr/local/cuda-12.8"
    echo "Por favor, instale o CUDA 12.8 antes de continuar."
    exit 1
fi

# Exportar variáveis necessárias
export CUDA=/usr/local/cuda-12.8
export LD_LIBRARY_PATH=$CUDA/lib64:$LD_LIBRARY_PATH
export CXXCUDA=/usr/bin/g++

# Detectar compute capability da GPU
# Valor padrão caso não consiga detectar (atualizado para arquiteturas mais recentes)
DEFAULT_CCAP=90

# Tentar detectar usando nvidia-smi
if command -v nvidia-smi &> /dev/null; then
    # Extrair compute capability do nvidia-smi
    GPU_INFO=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader)
    if [ -n "$GPU_INFO" ]; then
        # Remover o ponto (ex: 8.9 -> 89)
        CCAP=$(echo $GPU_INFO | tr -d '.')
        echo "Compute Capability detectada: $GPU_INFO (usando $CCAP para compilação)"
    else
        CCAP=$DEFAULT_CCAP
        echo "Não foi possível detectar a Compute Capability. Usando o valor padrão: $CCAP"
    fi
else
    CCAP=$DEFAULT_CCAP
    echo "nvidia-smi não encontrado. Usando o valor padrão para Compute Capability: $CCAP"
fi

# Para GPUs mais recentes com Compute Capability 12.0 (Blackwell)
if [ "$CCAP" = "120" ]; then
    echo "Detectada GPU Blackwell com Compute Capability 12.0"
    # Usando formato hexadecimal para SM 12.0 (0xC0)
    CCAP=C0
fi

# Compilar o projeto
echo "Compilando VanitySearch com CUDA 12.8..."
make gpu=1 CCAP=$CCAP

if [ $? -eq 0 ]; then
    echo
    echo "Compilação concluída com sucesso!"
    echo "Para executar o VanitySearch, use:"
    echo "export LD_LIBRARY_PATH=/usr/local/cuda-12.8/lib64:\$LD_LIBRARY_PATH"
    echo "./VanitySearch [opções]"
else
    echo
    echo "Erro durante a compilação!"
fi 