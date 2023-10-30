#!/bin/bash
# Instalacao e configuracao do Docker
yum update -y
yum install docker -y
systemctl start docker
systemctl enable docker
usermod -aG docker ${USER}
# Configurando permissões do socket do Docker
chmod 666 /var/run/docker.sock
# Instalacao do docker-compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
# Instalacao do cliente nfs
yum install nfs-utils -y
# Montagem do efs
mkdir -p /mnt/efs
chmod +rwx /mnt/efs/
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport fs-0a32669c082f3c134.efs.us-east-1.amazonaws.com:/ /mnt/efs/
echo "fs-0a32669c082f3c134.efs.us-east-1.amazonaws.com:/ /mnt/efs nfs defaults 0 0" >> /etc/fstab
# Executando o docker-compose do repositorio
curl -sL "https://github.com/Dheymison201n/At02_AWS_Docker-CompassUOL/raw/main/docker-compose.yml" --output "/home/ec2-user/docker-compose.yml"
docker-compose -f /home/ec2-user/docker-compose.yml up -d
