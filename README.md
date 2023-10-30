# At02_AWS_Docker-CompassUOL
Repositorio para a atividade de Docker, do programa de bolsas da Compass UOL.

# Sumário
- [Sobre a Atividade](#sobre-a-atividade)
- [Configurando instância EC2](#configurando-instância-ec2)
    - [Configuração dos grupos de seguranças](#configuração-dos-grupos-de-seguranças)
    - [Configuração da VPC](#configuração-da-vpc)
        - [Configuração das sub-redes](#configuração-das-sub-redes)
        - [Configuração dos gateways](#configuração-dos-gateways)
    - [Pares de chaves](#pares-de-chaves)
    - [Executando instância da aplicação](#executando-instância-da-aplicação)
- [Instalação do Docker na instância](#instalação-docker-na-instância)
- [Instalação do Docker Compose](#instalação-do-docker-compose)
- [Montagem do EFS](#montagem-do-efs)
- [Executando contêineres via Docker Compose](#executando-contêineres-via-docker-compose)
- [Configuração do balanceador de cargas](#configuração-do-balanceador-de-cargas)
    - [Aplication Load Balancer](#aplication-load-balancer)

# Sobre a atividade
## Requisitos

- Instalação e configuração do DOCKER ou CONTAINERD no host EC2;
- Ponto adicional para o trabalho utilizar a instalação via script de Start Instance (user_data.sh)
- Efetuar Deploy de uma aplicação Wordpress com: 
  - Container de aplicação
  - RDS database Mysql
  - Configuração da utilização do serviço EFS AWS para estáticos do container de aplicação Wordpress
  - Configuração do serviço de Load Balancer AWS para a aplicação Wordpress

## Pontos de atenção

- Não utilizar ip público para saída do serviços WP (Evitar publicar o serviço WP via IP Público)
- Sugestão para o tráfego de internet sair pelo LB (Load Balancer Classic)
- Pastas públicas e estáticos do wordpress sugestão de utilizar o EFS (Elastic File Sistem)
- Fica a critério de cada integrante (ou dupla) usar Dockerfile ou Dockercompose;
- Necessário demonstrar a aplicação wordpress funcionando (tela de login)
- Aplicação Wordpress precisa estar rodando na porta 80 ou 8080;
- Utilizar repositório git para versionamento;
- Criar documentação

# Configurando instância EC2

## Configuração do grupo de segurança

Configurar 2 grupos de segurança, um para a instância e outro para o load balancer.

- Grupo de segurança do balanceador de carga
  Porta | Protocolo | Origem
  --- | --- | ---
  80  | TCP | 0.0.0.0/0

- Grupo de segurança da aplicação
  Porta | Protocolo | Origem 
  --- | --- | ---
  22 | TCP | Grupo de segurança do Bastion Host
  2049 | TCP | 172.0.0.0/16
  2049 | UDP | 172.0.0.0/16
  80 | TCP | Grupo de segurança do balanceador de carga

## Configuração da VPC

Inicie navegando para o console da VPC no link https://us-east-1.console.aws.amazon.com/vpc/home
### Configuração das sub-redes
Utilizar a VPC padrão já criada, porém pra essa vpc devemos considerar o uso de quatro sub-redes, sendo duas privada, que contém a instância da aplicação em duas zona de disponibilidade(AZ) diferentes, e as outras duas públicas, que contém a instância do bastion. Então, navegue para seção de sub-redes.

- Criando sub-rede privada
    - `Nome: wordpress01prv-pb-ufc`
    - `Zona de disponibilidade: us-east-1a`
    - `CIDR: 172.0.0.0/24`

    - `Nome: wordpress02prv-pb-ufc`
    - `Zona de disponibilidade: us-east-1b`
    - `CIDR: 172.0.1.0/24`

- Criando sub-rede pública
    - `Nome: pub1-pb-ufc`
    - `Zona de disponibilidade: us-east-1a`
    - `CIDR: 172.0.2.0/24`

    - `Nome: pub2-pb-ufc`
    - `Zona de disponibilidade: us-east-1b`
    - `CIDR: 172.0.3.0/24`

### Configuração dos Gateways

Para uma instância privada obter acesso a internet para baixar/instalar alguns pacotes devemos utilizar um gateway NAT, o qual é associado a um gateway da internet. Então, navegue para seção de gateway.

- Criando gateway da internet
    - `Nome: ig-pb-ufc`
    
- Criando gateway NAT
    - `Nome: gtw-pb-ufc`
    - `Sub-rede: pub1-pb-ufc`
    - `Conectividade: Público`
    - `IP elástico: alocar IP elástico`

### Tabela de rotas
Precisaremos criar duas tabela de roteamento, sendo uma para as sub-redes privadas e outra para as publicas, onde uma vai permitir o tráfego à internet pelo gateway da internet e o outro vai permitir o tráfego à internet pelo gateway NAT. Então, navegue para seção de tabela de rotas.

- Criando a tabela de roteamento para as sub-redes pública
    - `Nome: rt-pb-ufc`
    - `VPC: vpc-pb-ufc`
- Criando a tabela de roteamento para as sub-redes privada
    - `Nome: nat-route-pb-ufc`
    - `VPC: vpc-pb-ufc`

Após isso devemos associar cada sub-rede criada anteriormente a sua respectiva tabela de roteamento. 

- Associando sub-redes privada a sua tabela de roteamento

    Selecione a tabela de roteamento, siga para associações de sub-redes e selecione `Editar associações`. Após isso, selecione as sub-redes privada, com nome `nat-route-pb-ufc` e clique `salvar`.

- Associando sub-redes pública a sua tabela de roteamento

    Selecione a tabela de roteamento, siga para associações de sub-redes e selecione `Editar associações`. Após isso, selecione as sub-redes pública, com nome ' rt-pb-ufc` e clique `salvar`.

Além disso, devemos também permitir o tráfego a internet para cada sub-rede, sendo pelo gateway da internet para sub-rede pública e gateway NAT para sub-rede privada.

- Adicionando rota para gateway da internet na tabela de roteamento da sub-rede pública

    Selecione a tabela de roteamento, siga para rotas e selecione `Editar rotas`. Após isso, selecione `adicionar rotas` e preencha:
    
    Destino    | Alvo 
     ---       |  --- 
     0.0.0.0/0 | gateway da internet
   
- Adicionando rota para gateway da internet na tabela de roteamento da sub-rede pública

    Selecione a tabela de roteamento, siga para rotas e selecione `Editar rotas`. Após isso, selecione `adicionar rotas` e preencha:

    Destino    | Alvo 
     ---       |  --- 
     0.0.0.0/0 | gateway NAT

Após esses passos, finalizamos as configurações necessárias para o serviço de VPC.

## Pares de chaves

Inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/ec2/home

Antes da execução das instâncias, devemos iniciar com a criação dos par de chaves. Então, navegue para seção de pares de chaves.

- Criação do par de chaves
    - `Nome: keySSH-pb-UFC`
    - `Tipo: RSA`
    - `Formato: .pem`

Seguindo com a execução das instâncias, iremos continuar com a execução do Bastion Host.

## Executando Bastion Host
Inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/ec2/home e selecione `executar instância`.

### Configuração da instância
- `AMI: Linux 2`
- `VPC: default`
- `Sub-rede:  `
- `Tipo da instância: t2.micro`
- `par de chaves: keySSH-pb-UFC.pem`
- `EBS: 16GB GP3`
- `Auto-associamento de IP público: habilitado`

## Executando instância da aplicação
Inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/ec2/home e selecione `executar instância`.

### Configuração da instância 1
- `AMI: Linux 2`
- `VPC: vpc-pb-ufc`
- `Sub-rede:  wordpress01prv-pb-ufc`
- `Tipo da instância: t2.micro`
- `par de chaves: keySSHAntonio`
- `EBS: 16GB GP3`
- `Auto-associamento de IP público: desabilitado`

### Configuração da instância 2
- `AMI: Linux 2`
- `VPC: vpc-pb-ufc`
- `Sub-rede:  wordpress02prv-pb-ufc`
- `Tipo da instância: t2.micro`
- `par de chaves: keySSH-pb-UFC.pem`
- `EBS: 16GB GP3`
- `Auto-associamento de IP público: desabilitado`

# Instalação Docker na instância

Para instalar o docker na instância iremos executar os seguintes comandos:

```bash
#atualizar os pacotes para a última versão
sudo yum update -y
#instalar o docker
sudo yum install docker
#iniciar o serviço do docker
sudo systemctl start docker
#habilitar o serviço do docker para iniciar automaticamente
sudo systemctl enable docker
#adicionar o usuário ec2-user ao grupo docker
sudo usermod -aG docker ${USER}
```
Configurando permissões do socket do Docker

```bash
chmod 666 /var/run/docker.sock
```

# Instalação do Docker Compose
Para instalar o docker compose na instância iremos executar os seguintes comando:

```bash
# baixar o docker-compose para a pasta /usr/local/bin
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
# dar permissão de execução ao binário do docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

# Montagem do EFS

Para acessar o EFS configurado podemos executar os seguinte comandos:

```bash
# criar o diretório para o EFS
mkdir -p /mnt/nfs
# Conceder permissões de leitura, gravação e execução a todos os usuários para o diretório /mnt/efs/
chmod +rwx /mnt/efs/
# montar o EFS
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport efs.us-east-1.amazonaws.com:/ /mnt/efs/
# adicionar o EFS no fstab
echo "efs.us-east-1.amazonaws.com:/ /mnt/efs nfs defaults 0 0" >> /etc/fstab
```

# Executando contêineres via Docker Compose

Para subir os contêineres que estarão responsáveis pela aplicação do Wordpress, iremos utilizar a execução de um [docker-compose.yml](/docker-compose.yml) que está disponibilizado nesse repositório. Então o primeiro passo é clonar esse arquivo para dentro da instância, iremos fazer isso usando os seguintes comandos:

```bash
curl -sL "https://github.com/Dheymison201n/At02_AWS_Docker-CompassUOL/raw/main/docker-compose.yml" --output "/home/ec2-user/docker-compose.yml"
```
Após isso podemos subir os contêineres utilizando o seguinte comando:
```bash 
docker-compose -f /home/ec2-user/docker-compose.yml up -d
```

# Configuração do balanceador de cargas

Inicie navegando para o console da EC2 no link https://us-east-1.console.aws.amazon.com/ec2/home e acesse a seção do balanceador de carga.

## Aplication Load Balancer
Seguimos com a criação do ALB.

- Criação do Aplication Load Balancer
    - `Nome: lb-pb-ufc`
    - `Esquema: voltado pra internet`
    - `Tipo de endereço IP: IPv4`
    - `VPC: vpc-pb-ufc`
    - `Mapeamento:`
        - `us-east-1a`
        - `us-east-1b`
    - `Grupo de segurança: as-lb-pb-ufc`

[Voltar para o início](#atividade-aws-docker)
