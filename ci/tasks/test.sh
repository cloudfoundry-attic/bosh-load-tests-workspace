#!/usr/bin/env bash

set -exu

ROOT_DIR=$PWD


cp -f ${PWD}/config-server-release/* /tmp/config-server-release

start-bosh \
    -o /usr/local/bosh-deployment/local-bosh-release.yml \
    -o /usr/local/bosh-deployment/uaa.yml \
    -o /usr/local/bosh-deployment/config-server.yml \
    -o $ROOT_DIR/bosh-load-tests-workspace/assets/add-updates-section.yml \
    -o $ROOT_DIR/bosh-load-tests-workspace/assets/scale-up-pg-connections.yml \
    -v local_bosh_release=$PWD/bosh-candidate-release/bosh-dev-release.tgz

local_bosh_dir="/tmp/local-bosh/director"
source "${local_bosh_dir}/env"

# TODO: Can we clean up all these SSH keys? our ginkgo tests here probably aren't using them.
bosh int /tmp/local-bosh/director/creds.yml --path /jumpbox_ssh/private_key > /tmp/jumpbox_ssh_key.pem
chmod 400 /tmp/jumpbox_ssh_key.pem

export BOSH_GW_PRIVATE_KEY="/tmp/jumpbox_ssh_key.pem"
export BOSH_GW_USER="jumpbox"
export BOSH_DIRECTOR_IP="10.245.0.3"

bosh -n update-cloud-config $ROOT_DIR/bosh-load-tests-workspace/assets/cloud_config.yml -v network=director_network

bosh upload-stemcell bosh-candidate-stemcell/bosh-stemcell-*.tgz

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

sed -i "s#BOSH_CLI_BIN#${BOSH_CLI_BIN}#g" $config_file_path

sed -i s#PWD#${PWD}#g $config_file_path


# PUT required parameters in config-server
set +eu
source /etc/profile.d/chruby.sh
chruby 2.3.1
yes y | gem install cf-uaac --no-document

uaac  target https://${BOSH_DIRECTOR_IP}:8443 --skip-ssl-validation

config_server_password=$(bosh int "${local_bosh_dir}/creds.yml" --path /director_config_server_client_secret)
uaac token client get director_config_server -s ${config_server_password}

cat <<EOF >payload.json
{ "name": "/num_instances", "value": 10 }
EOF
uaac curl --insecure --request PUT --header Content-Type:Application/JSON --data "$(cat payload.json)" "https://${BOSH_DIRECTOR_IP}:8080/v1/data"

# Stubbing out uaac, to prevent uaa starting and instead using uaa from our 'bosh uaa deployment'
yes y| gem uninstall cf-uaac

cat <<HERE >/usr/local/bin/uaac
#!/usr/bin/env bash

HERE
chmod +x /usr/local/bin/uaac


go run bosh-load-tests-workspace/src/github.com/cloudfoundry-incubator/bosh-load-tests/main.go $config_file_path
