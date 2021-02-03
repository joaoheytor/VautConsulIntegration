#!/bin/bash

export CONSUL_VERSION="1.9.2"
export CONSUL_URL="https://releases.hashicorp.com/consul"
export LOCAL_NAME=`ip -o addr show dev "eth0" | awk '$3 == "inet" {print $4}' | sed -r 's!/.*!!; s!.*\.!!'`
export LOCAL_IP=`hostname -I`

sudo hostname consulserver-${LOCAL_NAME}
sudo echo consulserver-${LOCAL_NAME} > /etc/hostname

sudo apt-get update -y && apt-get upgrade -y
sudo apt-get install -y unzip

sudo useradd --system --home /etc/consul.d --shell /bin/false consul
sudo mkdir --parents /opt/consul
sudo chown --recursive consul:consul /opt/consul

cd /opt/consul/
curl --silent --remote-name ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip
curl --silent --remote-name ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS
curl --silent --remote-name ${CONSUL_URL}/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_SHA256SUMS.sig

unzip consul_${CONSUL_VERSION}_linux_amd64.zip

sudo cp consul /usr/bin/

cat << EOF > /opt/consul/consul_s1.json
    {
      "server": true,
      "node_name": "consul_s1",
      "datacenter": "dc1",
      "data_dir": "/var/consul/data",
      "bind_addr": "0.0.0.0",
      "client_addr": "0.0.0.0",
      "advertise_addr": "${LOCAL_IP}", ### ADICIONAR IP DE TODOS OS NÓS
      "bootstrap_expect": 1,
      "retry_join": ["${LOCAL_IP}"],   ### ADICIONAR IP DE TODOS OS NÓS
      "ui": true,
      "log_level": "DEBUG",
      "enable_syslog": true,
      "acl_enforce_version_8": false
    }
EOF

cat << EOF > /etc/systemd/system/consul.service
    # Default-Stop:      0 1 6
    # Short-Description: Consul agent
    # Description:       Consul service discovery framework
    ### END INIT INFO

    [Unit]
    Description=Consul server agent
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
        -config-file=/opt/consul/consul_s1.json \
        -pid-file=/var/run/consul/consul.pid
    ExecReload=/bin/kill -HUP $MAINPID
    KillMode=process
    KillSignal=SIGTERM
    Restart=on-failure
    RestartSec=42s

    [Install]
    WantedBy=multi-user.target
EOF

systemctl start consul
