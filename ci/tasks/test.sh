#!/usr/bin/env bash

set -exu

ROOT_DIR=$PWD

case "$DB" in
  mysql)
    OUTER_CONTAINER_IP=$( ruby -rsocket -e 'puts Socket.ip_address_list
                          .reject { |addr| !addr.ip? || addr.ipv4_loopback? || addr.ipv6? }
                          .map { |addr| addr.ip_address }')
    echo 'Starting DB...'

    service mysql start
    mysql --password='password' <<< "GRANT ALL PRIVILEGES ON *.* TO root @'%' IDENTIFIED BY 'password';"
    mysql --password='password' <<< "create database bosh;"
    mysql --password='password' <<< "create database uaa;"
    mysql --password='password' <<< 'create database `config_server`;'

    start-bosh \
        -o /usr/local/bosh-deployment/local-bosh-release.yml \
        -o /usr/local/bosh-deployment/uaa.yml \
        -o /usr/local/bosh-deployment/misc/config-server.yml \
        -o /usr/local/bosh-deployment/experimental/blobstore-https.yml \
        -o $ROOT_DIR/bosh-load-tests-workspace/assets/remove-postgres.yml \
        -o $ROOT_DIR/bosh-load-tests-workspace/assets/add-updates-section.yml \
        -o $ROOT_DIR/bosh-load-tests-workspace/assets/configure-mysql.yml \
        -o $ROOT_DIR/bosh-load-tests-workspace/assets/make-disk-bigger.yml \
        -v db_host=$OUTER_CONTAINER_IP \
        -v db_user=root \
        -v db_password=password \
        -v db_port=3306 \
        -v local_bosh_release=$PWD/bosh-candidate-release/bosh-dev-release.tgz
    ;;
  postgresql)
    start-bosh \
        -o /usr/local/bosh-deployment/local-bosh-release.yml \
        -o /usr/local/bosh-deployment/uaa.yml \
        -o /usr/local/bosh-deployment/misc/config-server.yml \
        -o /usr/local/bosh-deployment/experimental/blobstore-https.yml \
        -o $ROOT_DIR/bosh-load-tests-workspace/assets/add-updates-section.yml \
        -o $ROOT_DIR/bosh-load-tests-workspace/assets/scale-up-pg-connections.yml \
        -v local_bosh_release=$PWD/bosh-candidate-release/bosh-dev-release.tgz
    ;;
  *)
    echo $"Usage: DB={mysql|postgresql} $0 {commands}"
    exit 1
esac


local_bosh_dir="/tmp/local-bosh/director"
source "${local_bosh_dir}/env"

bosh int /tmp/local-bosh/director/creds.yml --path /jumpbox_ssh/private_key > /tmp/jumpbox_ssh_key.pem
chmod 400 /tmp/jumpbox_ssh_key.pem

export BOSH_GW_PRIVATE_KEY="/tmp/jumpbox_ssh_key.pem"
export BOSH_GW_USER="jumpbox"
export BOSH_DIRECTOR_IP="10.245.0.3"

bosh upload-stemcell bosh-candidate-stemcell/stemcell.tgz

export GOPATH=$(realpath bosh-load-tests-workspace)

legacy=${LEGACY:-false}

if [ $legacy = true ]; then
  echo "Using legacy deployment manifest"
  config_file_path=bosh-load-tests-workspace/ci/legacy-concourse-config.json
else
  echo "Using non-legacy deployment manifest"
  config_file_path=bosh-load-tests-workspace/ci/concourse-config.json
fi

export BOSH_ENVIRONMENT="https://${BOSH_DIRECTOR_IP}:25555"
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int "${local_bosh_dir}/creds.yml" --path /admin_password`
export BOSH_CA_CERT="${local_bosh_dir}/ca.crt"

BOSH_CLI_BIN=$(ls ${PWD}/bosh-cli/alpha-bosh-cli-*-linux-amd64)

chmod +x $BOSH_CLI_BIN

sed -i "s#BOSH_CLI_BIN#${BOSH_CLI_BIN}#g" $config_file_path

sed -i s#PWD#${PWD}#g $config_file_path

export CONFIG_SERVER_PASSWORD=$(bosh int "${local_bosh_dir}/creds.yml" --path /director_config_server_client_secret)

gem install cf-uaac --no-document

go run bosh-load-tests-workspace/src/github.com/cloudfoundry-incubator/bosh-load-tests/main.go $config_file_path
