# VanitySearch para Windows com CUDA 12.6

Este é um fork do projeto VanitySearch atualizado para usar CUDA 12.6 e otimizado para Windows.

## Pré-requisitos

- Windows 10 ou superior
- Visual Studio 2022 (Community Edition ou superior)
- CUDA Toolkit 12.6
- GPU compatível com CUDA 12.6

## Instalação

1. Instale o [Visual Studio 2022](https://visualstudio.microsoft.com/pt-br/downloads/)
2. Instale o [CUDA Toolkit 12.6](https://developer.nvidia.com/cuda-downloads)
3. Clone ou baixe este repositório

## Compilação

### Usando Visual Studio

1. Abra o arquivo `VanitySearchCUDA12_6.sln` no Visual Studio
2. Selecione a configuração "Release" e a plataforma "x64"
3. Compile o projeto (F7 ou Ctrl+Shift+B)

### Usando o script de compilação

1. Abra um "Developer Command Prompt for VS 2022"
2. Navegue até o diretório do projeto
3. Execute o script `build_windows.bat`

## Uso

O programa VanitySearch é usado para encontrar endereços Bitcoin com prefixos específicos.

Exemplo de uso básico:

```
VanitySearchCUDA12_6.exe -gpu -g 0 -o results.txt 1MyPrefix
```

### Parâmetros

- `-gpu` : Usar GPU para acelerar a busca
- `-g N` : Usar GPU número N (padrão: 0)
- `-o filename` : Salvar endereços encontrados em um arquivo
- `-t N` : Usar N threads da CPU (padrão: número de núcleos disponíveis)
- `-c` : Não diferenciar maiúsculas e minúsculas
- `-v` : Mostrar versão do programa
- `-h` : Mostrar ajuda
- `-range start,end` : Definir range de chaves privadas para busca (formato hexadecimal)
- `-keys N` : Número de chaves a processar por core da GPU antes de mudar para outra chave aleatória no range

## Busca em Range Específico

Esta versão adiciona a capacidade de buscar endereços dentro de um range específico de chaves privadas. Isso é útil quando você tem conhecimento de que uma chave privada específica está dentro de um determinado intervalo.

### Exemplo de Busca em Range Específico

Para buscar um endereço com o prefixo "1Gz5L4ywBHSqsyp" dentro de um range específico:

```
VanitySearchCUDA12_6.exe -gpu -g 0 -range 0758fd012128225df164df212ef642926da194be3b017d5a6a97587a30b00000,0758fd012128225df164df212ef642926da194be3b017d5a6a97587a3ef00000 -keys 1024 -stop 1Gz5L4ywBHSqsyp
```

### Explicação dos Parâmetros de Range

- `-range start,end`: Define o intervalo de chaves privadas a ser pesquisado em formato hexadecimal
  - `start`: O valor inicial do range (inclusive)
  - `end`: O valor final do range (inclusive)
- `-keys N`: Define quantas chaves cada core da GPU irá processar antes de mudar para outra chave aleatória dentro do range
  - Valores maiores podem melhorar o desempenho devido a menos realocações, mas reduzem a cobertura uniforme do range
  - Valores menores garantem melhor cobertura do range, mas podem reduzir o desempenho
  - Se não for especificado, o padrão é o tamanho do grupo de processamento (geralmente 1024)

### Estratégia de Busca no Range

O algoritmo funciona da seguinte forma:
1. Cada thread da GPU recebe uma chave inicial aleatória dentro do range especificado
2. A thread processa essa chave e suas derivadas (incrementais) até o limite definido por `-keys`
3. Após processar o número definido de chaves, a thread recebe uma nova chave aleatória do range e continua
4. Este processo se repete até encontrar o endereço desejado ou cobrir todo o range

### Desempenho na Busca por Range

A busca em range específico geralmente é muito mais rápida do que uma busca completa no espaço de 256 bits quando o range é relativamente pequeno. O desempenho depende:

- Do tamanho do range (ranges menores são mais rápidos de verificar)
- Do número de cores na GPU
- Do valor definido para `-keys`
- Da dificuldade do prefixo buscado

## Mudanças em relação à versão original

- Atualizado para usar CUDA 12.6
- Adaptado para compilar nativamente no Windows
- Removido código específico para Linux
- Atualizada a arquitetura de GPU alvo para modelos mais recentes
- Adicionada funcionalidade de busca em range específico de chaves privadas

## Desempenho

O desempenho varia de acordo com a GPU e CPU utilizadas:

- CPU: Tipicamente 1-3 milhões de chaves por segundo por núcleo
- GPU: Dependendo do modelo, de 50 milhões a 1 bilhão de chaves por segundo

## Problemas Conhecidos

- O programa requer uma GPU compatível com CUDA 12.6
- Pode ser necessário ajustar as opções de compilação para GPUs mais antigas 