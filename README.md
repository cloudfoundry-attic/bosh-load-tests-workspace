# BOSH load tests

To run tests:

```
cd ci
vagrant up
cd -
fly sync
fly execute -c ci/tasks/test.yml -x -i bosh-src=/Users/pivotal/workspace/bosh -i bosh-load-tests-workspace=$PWD
```

To run tests & pollute local environment:

```
export GOPATH=$PWD
DB=postgresql go run src/github.com/cloudfoundry-incubator/bosh-load-tests/main.go config.json
```

Tests use config.json, which specifies the paths to the dummy environment setup and the cli command.

Note: If you want to run the legacy load tests locally, make sure to change the following in `config.json` to these values:

```
{ 
  ...
  "number_of_workers": 3,
  "number_of_deployments": 1,
  "using_legacy_manifest": true,
  ...
}
```

To update dependencies:

```
./update_deps
```

It will pull latest master and records dependencies git sha in deps.txt.
