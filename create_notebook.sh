#! /bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -o errtrace
set -x

PROJECT_NAME=${1:-notebook}
WORKBENCH_NAME=${2:-workbench}

echo "Creating the notebook '$WORKBENCH_NAME' in the project '$PROJECT_NAME'"

# ---

IMAGESTREAM=s2i-generic-data-science-notebook
IMAGESTREAM_TAG=py3.8-v1

NOTEBOOK_FILENAME=benchmark_entrypoint.ipynb

BENCHMARK_NAME=pyperf_bm_go
BENCHMARK_NUMBER=2
BENCHMARK_REPEAT=2

NOTEBOOK_FILE_DIR=notebook

# ---

CONFIG_MAP_NAME=${WORKBENCH_NAME}-files
NOTEBOOK_IMAGE=image-registry.openshift-image-registry.svc:5000/redhat-ods-applications/$IMAGESTREAM:$IMAGESTREAM_TAG
# ---

mkdir artifacts/src -p

dashboard_route_host=$(oc get route/rhods-dashboard -n redhat-ods-applications -ojsonpath={.spec.host})

echo "Creating the notebook project ..."
if ! oc get project "$PROJECT_NAME" 2>/dev/null; then
    oc new-project "$PROJECT_NAME" --skip-config-write
fi

# this labels ensures that RHODS Dashboard lists it in the user's projects
oc label ns "$PROJECT_NAME" opendatahub.io/dashboard=true --overwrite

echo "Creating the notebook configmap ..."
oc delete cm "$CONFIG_MAP_NAME" -n "$PROJECT_NAME" --ignore-not-found
oc create cm "$CONFIG_MAP_NAME" -n "$PROJECT_NAME" --from-file=$NOTEBOOK_FILE_DIR

echo "Creating the notebook ..."
cat notebook.template.yaml \
    | sed "s/{{ notebook_namespace }}/$PROJECT_NAME/g" \
    | sed "s/{{ notebook_name }}/$WORKBENCH_NAME/g" \
    | sed "s|{{ notebook_image_address }}|$NOTEBOOK_IMAGE|g" \
    | sed "s|{{ notebook_files_configmap }}|$CONFIG_MAP_NAME|g" \
    | sed "s|{{ notebook_filename }}|$NOTEBOOK_FILENAME|g" \
    | sed "s|{{ benchmark_name }}|$BENCHMARK_NAME|g" \
    | sed "s|{{ benchmark_number }}|$BENCHMARK_NUMBER|g" \
    | sed "s|{{ benchmark_repeat }}|$BENCHMARK_REPEAT|g" \
    | sed "s|{{ dashboard_route_host }}|$dashboard_route_host|g" \
          \
    | tee "artifacts/src/notebook.$PROJECT_NAME.$WORKBENCH_NAME.yaml" \
    | oc apply -f- -n "$PROJECT_NAME"

# wait for the pod to appear
echo "Waiting for the Notebook Pod to appear ..."
while ! oc get pods -n "$PROJECT_NAME" -lapp=$WORKBENCH_NAME -oname | grep . --quiet; do
    sleep 1
done
echo "Pod appeared. Waiting for it to be ready ..."
while [[ $(oc get -n "$PROJECT_NAME" notebook/$WORKBENCH_NAME -ojsonpath={.status.readyReplicas}) != 1 ]]; do
    sleep 1
done
echo "Notebook is ready!"
oc get pods -n "$PROJECT_NAME"
echo "Copy the notebook files to \$HOME"
oc rsh -n "$PROJECT_NAME" -c "${WORKBENCH_NAME}" "${WORKBENCH_NAME}-0" \
   bash -exc 'cp "$NOTEBOOK_FILES"/* .'

echo "Run the notebook"
oc rsh -n "$PROJECT_NAME" -c "${WORKBENCH_NAME}" "${WORKBENCH_NAME}-0" \
   bash -exc 'jupyter nbconvert --to notebook --execute "$NOTEBOOK_FILENAME"
              mv "$(basename "$NOTEBOOK_FILENAME" .ipynb).nbconvert.ipynb" $(basename "$NOTEBOOK_FILENAME" .ipynb).executed.ipynb
              jupyter nbconvert --to html $(basename "$NOTEBOOK_FILENAME" .ipynb).executed.ipynb'

HTML_DEST="notebook.$PROJECT_NAME.$WORKBENCH_NAME.$(basename "$NOTEBOOK_FILENAME" .ipynb).executed.html"
oc cp -c "${WORKBENCH_NAME}" "$PROJECT_NAME/${WORKBENCH_NAME}-0":$(basename "$NOTEBOOK_FILENAME" .ipynb).executed.html "./artifacts/$HTML_DEST"

echo "All done, ./artifacts/$HTML_DEST has been saved."
