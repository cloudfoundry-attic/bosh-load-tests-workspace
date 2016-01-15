#!/usr/bin/env bash

set -e

export PATH=/usr/local/ruby/bin:/usr/local/go/bin:$PATH

echo 'Starting DB...'
su postgres -c '
  export PATH=/usr/lib/postgresql/9.4/bin:$PATH
  export PGDATA=/tmp/postgres
  export PGLOGS=/tmp/log/postgres
  mkdir -p $PGDATA
  mkdir -p $PGLOGS
  initdb -U postgres -D $PGDATA
  pg_ctl start -l $PGLOGS/server.log
'

source /etc/profile.d/chruby.sh
chruby $RUBY_VERSION

echo 'Installing dependencies...'
(
  cd bosh-src
  bundle install --local
  bundle exec rake spec:integration:install_dependencies

  echo "Building agent..."
  go/src/github.com/cloudfoundry/bosh-agent/bin/build
)

echo 'Running tests...'

export GOPATH=$(realpath bosh-load-tests-workspace)

bosh_src_path="$( cd bosh-src && pwd )"
legacy=${LEGACY:-false}

sed -i s#BOSH_SRC_PATH#${bosh_src_path}#g bosh-load-tests-workspace/ci/concourse-config.json
sed -i s#\"USING_LEGACY_MANIFEST\"#${legacy}#g bosh-load-tests-workspace/ci/concourse-config.json

go run bosh-load-tests-workspace/src/github.com/cloudfoundry-incubator/bosh-load-tests/main.go bosh-load-tests-workspace/ci/concourse-config.json
