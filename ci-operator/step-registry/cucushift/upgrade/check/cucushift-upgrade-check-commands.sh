#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

cp -Lrvf "${KUBECONFIG}" /tmp/kubeconfig

if test -f "${SHARED_DIR}/proxy-conf.sh"
then
    # shellcheck disable=SC1090
    source "${SHARED_DIR}/proxy-conf.sh"
fi

#shellcheck source=${SHARED_DIR}/runtime_env
. .${SHARED_DIR}/runtime_env

upuser1=$(echo "${USERS}" | cut -d ',' -f 1)
upuser2=$(echo "${USERS}" | cut -d ',' -f 2)
export BUSHSLICER_CONFIG="
environments:
  ocp4:
    static_users_map:
      upuser1: '${upuser1}'
      upuser2: '${upuser2}'
"
export OPENSHIFT_ENV_OCP4_USER_MANAGER=UpgradeUserManager
export OPENSHIFT_ENV_OCP4_USER_MANAGER_USERS=${USERS}
export BUSHSLICER_REPORT_DIR="${ARTIFACT_DIR}/upgrade-check"

cd verification-tests
cucumber --tags "${UPGRADE_CHECK_RUN_TAGS} and ${UPGRADE_SKIP_TAGS}" -p junit || true

# only exit 0 if junit result has no failures
echo "Summarizing test result..."
failures=$(grep '<testsuite failures="[1-9].*"' "${BUSHSLICER_REPORT_DIR}" -r | wc -l || true)
if [ $((failures)) == 0 ]; then
    echo "All upgrade-check have passed"
    exit 0
else
    echo "There are ${failures} test failures in upgrade-check"
    exit 1
fi