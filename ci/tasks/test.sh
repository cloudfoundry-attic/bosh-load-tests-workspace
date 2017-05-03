#!/usr/bin/env bash

set -e

cp $(ls $CLI_DIR_PATH/alpha-bosh-cli-*-linux-amd64) "/tmp/gobosh"
chmod a+x "/tmp/gobosh"

export PATH=/usr/local/ruby/bin:/usr/local/go/bin:$PATH

echo 'Starting DB...'
case "$DB" in
  mysql)
    sudo service mysql start
    ;;
  postgresql)
    export PATH=/usr/lib/postgresql/9.4/bin:$PATH

    su postgres -c '
      export PATH=/usr/lib/postgresql/9.4/bin:$PATH
      export PGDATA=/tmp/postgres
      export PGLOGS=/tmp/log/postgres
      mkdir -p $PGDATA
      mkdir -p $PGLOGS
      initdb -U postgres -D $PGDATA
      pg_ctl start -l $PGLOGS/server.log -o "-N 400"
    '
    ;;
  *)
    echo $"Usage: DB={mysql|postgresql} $0 {commands}"
    exit 1
esac

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

bosh_src_path="$PWD/$BOSH_SRC_PATH"

echo 'Installing dependencies...'

gem install cf-uaac --no-document

agent_path=$bosh_src_path/go/src/github.com/cloudfoundry/
mkdir -p $agent_path
cp -r bosh-agent $agent_path

(
  cd $bosh_src_path
  bundle install --local
  bundle exec rake spec:integration:install_dependencies

  echo "Building agent..."
  go/src/github.com/cloudfoundry/bosh-agent/bin/build
)

echo 'Running tests...'

export GOPATH=$(realpath bosh-load-tests-workspace)

legacy=${LEGACY:-false}

if [ $legacy = true ]; then
  echo "Using legacy deployment manifest"
  config_file_path=bosh-load-tests-workspace/ci/legacy-concourse-config.json
else
  echo "Using non-legacy deployment manifest"
  config_file_path=bosh-load-tests-workspace/ci/concourse-config.json
fi

sed -i s#BOSH_SRC_PATH#${bosh_src_path}#g $config_file_path
sed -i s#PWD#${PWD}#g $config_file_path

sed -i s#RUBY_VERSION#${RUBY_VERSION}#g $config_file_path

cp bosh-load-tests-workspace/assets/ssl/* /tmp/

go run bosh-load-tests-workspace/src/github.com/cloudfoundry-incubator/bosh-load-tests/main.go $config_file_path
