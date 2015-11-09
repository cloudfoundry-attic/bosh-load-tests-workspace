# BOSH load tests

To run tests:

```
cd ci
vagrant up
cd -
fly sync
fly execute -c ci/tasks/test.yml -i bosh-src=/Users/pivotal/workspace/bosh -i bosh-load-tests-workspace=$PWD
```

Tests use config.json that specify paths to dummy environment setup and cli command.

To update dependencies:

```
./update_deps
```

It will pull latest master and records dependencies git sha in deps.txt.