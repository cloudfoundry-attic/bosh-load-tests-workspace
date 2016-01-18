# BOSH load tests

To run tests:

```
cd ci
vagrant up
cd -
fly sync
fly execute -c ci/tasks/test.yml -i bosh-src=/Users/pivotal/workspace/bosh -i bosh-load-tests-workspace=$PWD
```

To run tests & pollute local environment:

```
export GOPATH=$PWD
go run src/github.com/cloudfoundry-incubator/bosh-load-tests/main.go config.json
```

Tests use config.json, which specifies the paths to the dummy environment setup and the cli command.

To update dependencies:

```
./update_deps
```

It will pull latest master and records dependencies git sha in deps.txt.