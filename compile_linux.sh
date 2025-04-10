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

# Verificar se os diretórios necessários existem
echo "Verificando e criando diretórios necessários..."
mkdir -p GPU
mkdir -p hash
mkdir -p obj
mkdir -p obj/GPU
mkdir -p obj/hash

# Verificar se os arquivos necessários existem
echo "Verificando arquivos cruciais..."
if [ ! -f "Vanity_Linux.cpp" ]; then
    echo "ERRO: Arquivo Vanity_Linux.cpp não encontrado!"
    exit 1
fi

if [ ! -f "Timer_Linux.h" ] || [ ! -f "Timer_Linux.cpp" ]; then
    echo "AVISO: Arquivos Timer_Linux não encontrados. Tentando usar Timer.h e Timer.cpp..."
    if [ ! -f "Timer.h" ] || [ ! -f "Timer.cpp" ]; then
        echo "ERRO: Nem Timer_Linux nem Timer foram encontrados!"
        exit 1
    fi
else
    # Copiar arquivos Linux específicos
    echo "Copiando arquivos específicos para Linux..."
    cp Timer_Linux.cpp Timer.cpp || { echo "ERRO: Falha ao copiar Timer_Linux.cpp!"; exit 1; }
    cp Timer_Linux.h Timer.h || { echo "ERRO: Falha ao copiar Timer_Linux.h!"; exit 1; }
    cp Vanity_Linux.cpp Vanity.cpp || { echo "ERRO: Falha ao copiar Vanity_Linux.cpp!"; exit 1; }
fi

# Lidar com o arquivo GPUEngine.cu
if [ ! -f "GPU/GPUEngine_Linux.cu" ]; then
    echo "AVISO: GPU/GPUEngine_Linux.cu não encontrado!"
    
    if [ -f "GPUEngine_Linux.cu" ]; then
        echo "Encontrado GPUEngine_Linux.cu no diretório raiz. Copiando para GPU/GPUEngine.cu..."
        cp GPUEngine_Linux.cu GPU/GPUEngine.cu || { echo "ERRO: Falha ao copiar GPUEngine_Linux.cu!"; exit 1; }
    elif [ ! -f "GPU/GPUEngine.cu" ]; then
        echo "ERRO: Nenhuma versão do GPUEngine.cu encontrada!"
        exit 1
    else
        echo "Usando GPU/GPUEngine.cu existente..."
    fi
else
    echo "Copiando GPU/GPUEngine_Linux.cu para GPU/GPUEngine.cu..."
    cp GPU/GPUEngine_Linux.cu GPU/GPUEngine.cu || { echo "ERRO: Falha ao copiar GPU/GPUEngine_Linux.cu!"; exit 1; }
fi

# Criar e verificar o Makefile
if [ ! -f "Makefile_Linux" ]; then
    echo "ERRO: Makefile_Linux não encontrado!"
    exit 1
fi

echo "Copiando Makefile_Linux para Makefile..."
cp Makefile_Linux Makefile || { echo "ERRO: Falha ao copiar Makefile_Linux!"; exit 1; }

# Verificar se há erro no Makefile
if ! grep -q "VanitySearch:" Makefile; then
    echo "ERRO: A regra 'VanitySearch:' não foi encontrada no Makefile!"
    echo "Verificando o conteúdo do Makefile:"
    head -n 100 Makefile
    exit 1
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
make gpu=1 CCAP=$CCAP -j4

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
        echo "Verificando possíveis causas:"
        
        # Verificar se o executável está em outro local
        EXECUTABLE=$(find . -name "VanitySearch" -type f)
        if [ ! -z "$EXECUTABLE" ]; then
            echo "Executável encontrado em: $EXECUTABLE"
            echo "Movendo para o diretório atual..."
            cp "$EXECUTABLE" ./ || { echo "ERRO: Falha ao copiar executável!"; exit 1; }
            chmod +x VanitySearch
            echo "============================================================="
            echo "Compilação concluída com sucesso!"
            echo "Para executar o programa, use: ./VanitySearch -h"
            echo "============================================================="
            exit 0
        fi
        
        # Verificar saída do make para identificar problemas
        echo "Verificando se a linking falhou..."
        make gpu=1 CCAP=$CCAP | grep -i error
        echo "Por favor verifique se há erros acima."
        exit 1
    fi
else
    echo "ERRO: A compilação falhou!"
    exit 1
fi 