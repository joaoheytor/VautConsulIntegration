#!/bin/bash

export VAULT_VERSION="1.9.2"
export VAULT_URL="https://releases.hashicorp.com/vault"
export CONSUL_VERSION="1.9.2"
export CONSUL_URL="https://releases.hashicorp.com/consul"
export LOCAL_NAME=`ip -o addr show dev "eth0" | awk '$3 == "inet" {print $4}' | sed -r 's!/.*!!; s!.*\.!!' | sed 's/ //g'`
export LOCAL_IP=`hostname -I`

sudo hostname vaultserver-${LOCAL_NAME}
sudo echo vaultserver-${LOCAL_NAME} > /etc/hostname

sudo apt-get update -y && apt-get upgrade -y
sudo apt-get install -y unzip

sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/vault
sudo mkdir --parents /opt/consul
sudo mkdir --parents /var/consul
sudo chown --recursive consul:consul /opt/consul
sudo chown --recursive consul:consul /var/run/consul
sudo chown --recursive consul:consul /var/consul

cd /opt/consul/
curl --silent --remote-name ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
curl --silent --remote-name ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS
curl --silent --remote-name ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig
unzip consul_${CONSUL_VERSION}_linux_amd64.zip
sudo cp consul /usr/local/bin/consul

cd /opt/vault
curl --silent --remote-name ${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
curl --silent --remote-name ${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS
curl --silent --remote-name ${VAULT_URL}/${VAULT_VERSION}/vault_${VAULT_VERSION}_SHA256SUMS.sig
unzip vault_${VAULT_VERSION}_linux_amd64.zip
sudo cp vault /usr/local/bin/vault

cat << EOF > /etc/vault/vault_server.hcl
    listener "tcp" {
      address          = "0.0.0.0:8200"
      cluster_address  = "${LOCAL_IP}:8201"
      tls_disable      = "true"
    }
    storage "consul" {
      address = "127.0.0.1:8500"
      path    = "vault/"
    }
    api_addr = "http://${LOCAL_IP}:8200"
    cluster_addr = "https://${LOCAL_IP}:8201"
    ui = true
EOF

cat << EOF > /usr/local/etc/consul/consul_c1.json
    {
      "server": false,
      "datacenter": "dc1",
      "node_name": "consul_c1",
      "data_dir": "/var/consul/data",
      "bind_addr": ${LOCAL_IP},
      "client_addr": "127.0.0.1",
      "retry_join": ["10.0.0.4", "10.0.0.7", "10.0.0.8"],
      "log_level": "DEBUG",
      "enable_syslog": true,
      "acl_enforce_version_8": false
    }
EOF

cat << EOF > /etc/systemd/system/consul.service
    ### BEGIN INIT INFO
    # Provides:          consul
    # Required-Start:    $local_fs $remote_fs
    # Required-Stop:     $local_fs $remote_fs
    # Default-Start:     2 3 4 5
    # Default-Stop:      0 1 6
    # Short-Description: Consul agent
    # Description:       Consul service discovery framework
    ### END INIT INFO

    [Unit]
    Description=Consul client agent
    Requires=network-online.target
    After=network-online.target

    [Service]
    User=consul
    Group=consul
    PIDFile=/var/run/consul/consul.pid
    PermissionsStartOnly=true
    ExecStartPre=-/bin/mkdir -p /var/run/consul
    ExecStartPre=/bin/chown -R consul:consul /var/run/consul
    ExecStart=/usr/local/bin/consul agent \
        -config-file=/usr/local/etc/consul/consul_c1.json \
        -pid-file=/var/run/consul/consul.pid
    ExecReload=/bin/kill -HUP $MAINPID
    KillMode=process
    KillSignal=SIGTERM
    Restart=on-failure
    RestartSec=42s

    [Install]
    WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/vault.service
### BEGIN INIT INFO
# Provides:          vault
# Required-Start:    $local_fs $remote_fs
# Required-Stop:     $local_fs $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Vault server
# Description:       Vault secret management tool
### END INIT INFO

[Unit]
Description=Vault secret management tool
Requires=network-online.target
After=network-online.target

[Service]
User=vault
Group=vault
PIDFile=/var/run/vault/vault.pid
ExecStart=/usr/local/bin/vault server -config=/etc/vault/vault_server.hcl -log-level=debug
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGTERM
Restart=on-failure
RestartSec=42s
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

systemctl start consul
systemctl start vault