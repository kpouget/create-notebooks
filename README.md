Simple automation for creating a workbench and running a notebook
=================================================================

Just a simple script to create a RHODS workbench, and run a notebook inside it.

Configuration
-------------

Modify these lines to run a different configuration:
```
IMAGESTREAM=s2i-generic-data-science-notebook
IMAGESTREAM_TAG=py3.8-v1

NOTEBOOK_FILE_DIR=notebook
NOTEBOOK_FILENAME=benchmark_entrypoint.ipynb

BENCHMARK_NAME=pyperf_bm_go
BENCHMARK_NUMBER=2
BENCHMARK_REPEAT=2
```

The variables `BENCHMARK_*` are specific to my sample notebook
`benchmark_entrypoint.ipynb`. But mind that they are currently passed
explicitly to the `notebook` resource, so you'll have to update the
script/template to remove them/add new ones.

The content of the directory `NOTEBOOK_FILE_DIR` is passed to the
notebook via a ConfigMap.

The `IMAGESTREAM` and `IMAGESTREAM_TAG` work with RHODS 1.23
.. 1.25. No guarantee for other releases.

You can check the available images with this command:
```
oc get istag -n redhat-ods-applications
```

Execution
---------

```
./create_notebook.sh [PROJECT_NAME=notebook] [WORKBENCH_NAME=workbench]
```

Artifacts
---------

The notebook resource file is stored in `artifacts/src`.

The result of the notebook after its execution in the workbench is stored in `artifacts`.
