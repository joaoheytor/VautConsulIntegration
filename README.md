# VautConsulIntegration
This script is used to test the usage of the Hashicorp Vault + Hashicorp Consul.

## Requirements
- DockerCompose

## Start the DockerCompose
docker-compose up -d --build

## Enter the Vault container
docker-compose exec vault bash

## Initiate the Hashicorp Vault
vault operator init

## Unseal the Vault to be able to receive/send data
vault operator unseal <RECOVERY_KEY>
Obs.: Execute this command 3 times

## Default ports
To open the GUI of the Vault/Consul, use the default ports:
- Vault Address: http://127.0.0.1:8200/
- Consul Address: http://127.0.0.1:8500

# Doing
Creating scripts to install this infraestructure on Azure with VMSS and VMSS Extensions