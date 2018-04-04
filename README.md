# BOSH load tests

To run tests:

`fly -t production execute -c ci/tasks/test.yml -x -p -i bosh-load-tests-workspace=.  -j bosh/load-tests-postgres`

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
./update-deps
```

It will pull latest master in the submodule.
