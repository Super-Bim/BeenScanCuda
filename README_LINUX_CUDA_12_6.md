# BeenScanCuda para Linux com CUDA 12.6

Este é um fork do projeto original atualizado para usar CUDA 12.6 no sistema Linux.

## Pré-requisitos

- Linux (Ubuntu/Debian recomendado)
- GCC/G++ (versão 9 ou superior)
- CUDA Toolkit 12.6
- GPU compatível com CUDA 12.6

## Instalação

1. Instale o CUDA Toolkit 12.6:
   ```
   wget https://developer.download.nvidia.com/compute/cuda/12.6.0/local_installers/cuda_12.6.0_535.104.05_linux.run
   sudo sh cuda_12.6.0_535.104.05_linux.run
   ```

2. Atualize o PATH e LD_LIBRARY_PATH no seu .bashrc:
   ```
   export PATH=/usr/local/cuda-12.6/bin${PATH:+:${PATH}}
   export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}
   ```

3. Clone ou baixe este repositório:
   ```
   git clone https://github.com/seu-usuario/BeenScanCuda.git
   cd BeenScanCuda
   ```

## Compilação

### Usando o Script de Compilação Automática

O projeto inclui um script que automatiza o processo de compilação para Linux:

1. Torne o script executável:
   ```
   chmod +x compile_linux.sh
   ```

2. Execute o script:
   ```
   ./compile_linux.sh
   ```

O script executará as seguintes tarefas automaticamente:
- Verificará se o CUDA está instalado e exibirá a versão
- Copiará os arquivos específicos para Linux
- Detectará sua GPU e configurará a Compute Capability apropriada
- Compilará o projeto com suporte a GPU
- Tornará o executável final pronto para uso

### Compilação Manual

Se preferir compilar manualmente:

1. Certifique-se de que o caminho do CUDA está correto no Makefile_Linux:
   ```
   CUDA = /usr/local/cuda-12.6
   ```

2. Compile com suporte a GPU:
   ```
   cp Makefile_Linux Makefile
   make gpu=1
   ```

3. Ou, para compilar apenas com CPU (sem GPU):
   ```
   cp Makefile_Linux Makefile
   make
   ```

### Ajustes opcionais

- Para especificar a Compute Capability (arquitetura) da sua GPU:
  ```
  make gpu=1 CCAP=75
  ```
  Nota: Compute Capability 75 corresponde a arquitetura Turing (RTX 2000/GTX 1600 series)

## Uso

O programa BeenScanCuda é usado para encontrar endereços Bitcoin com prefixos específicos.

Exemplo de uso básico:

```
./BeenScanCuda -gpu -g 0 -o results.txt 1MyPrefix
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
./BeenScanCuda -gpu -g 0 -range 0758fd012128225df164df212ef642926da194be3b017d5a6a97587a30b00000,0758fd012128225df164df212ef642926da194be3b017d5a6a97587a3ef00000 -keys 1024 -stop 1Gz5L4ywBHSqsyp
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

## Solução de Problemas

1. Se você encontrar erros relacionados a bibliotecas CUDA não encontradas, verifique se a variável LD_LIBRARY_PATH está corretamente configurada:
   ```
   export LD_LIBRARY_PATH=/usr/local/cuda-12.6/lib64:$LD_LIBRARY_PATH
   ```

2. Para verificar se o CUDA está instalado corretamente:
   ```
   nvcc --version
   ```

3. Se você encontrar problemas de compatibilidade com a sua GPU, tente ajustar a Compute Capability no Makefile.

## Mudanças em relação à versão original

- Renomeado para BeenScanCuda
- Atualizado para usar CUDA 12.6
- Adicionada funcionalidade de busca em range específico de chaves privadas
- Atualizado para computadores com arquiteturas de GPU modernas

## Desempenho

O desempenho varia de acordo com a GPU e CPU utilizadas:

- CPU: Tipicamente 1-3 milhões de chaves por segundo por núcleo
- GPU: Dependendo do modelo, de 50 milhões a 1 bilhão de chaves por segundo 