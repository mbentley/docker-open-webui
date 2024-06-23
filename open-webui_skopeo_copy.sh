#!/bin/bash

set -e

# set expected major.minor tags
EXPECTED_MAJOR_MINOR_TAGS="0.1 0.2 0.3"

# set expected major tags from the major.minor list
EXPECTED_MAJOR_TAGS="$(echo "${EXPECTED_MAJOR_MINOR_TAGS}" | tr " " "\n" | awk -F '.' '{print $1}' | sort -nu | xargs)"

# combine list of all expected tags
ALL_EXPECTED_TAGS="${EXPECTED_MAJOR_MINOR_TAGS} ${EXPECTED_MAJOR_TAGS}"

# make sure we have the latest skopeo image
echo "INFO: pulling quay.io/skopeo/stable..."
docker pull quay.io/skopeo/stable
echo -e "done\n"

tag_manifest() {
  # get expected tag from first argument
  EXPECTED_TAG="${1}"

  # test if major.minor or just major
  if ! echo "${EXPECTED_TAG}" | grep -q '\.'
  then
    # major only; set variable
    MAJOR_ONLY=true
  fi

  # get latest full version from GitHub releases
  echo -n "INFO: Getting full version for ${EXPECTED_TAG} from GitHub releases..."
  OPEN_WEBUI_VERSION="$(echo "${OPEN_WEBUI_RELEASES}" | grep "^v${EXPECTED_TAG}\." | head -n 1)"

  # check to see if we received a open webui version from github tags
  if [ -z "${OPEN_WEBUI_VERSION}" ]
  then
    echo -e "error\nERROR: unable to retrieve the Grafana version from GitHub\n"
    exit 1
  fi

  echo "${OPEN_WEBUI_VERSION}"

  # check to see if this is a non-GA version
  if [ -n "$(echo "${OPEN_WEBUI_VERSION}" | awk -F '-' '{print $2}')" ]
  then
    echo -e "ERROR: non-GA version ${OPEN_WEBUI_VERSION} found!\n"
    exit 1
  fi

  # see if we want a MAJOR.MINOR or just MAJOR tag
  if [ "${MAJOR_ONLY}" = "true" ]
  then
    # major only; get the destination tag we want to use
    DESTINATION_TAG="$(echo "${OPEN_WEBUI_VERSION}" | awk -F 'v' '{print $2}' | awk -F '.' '{print $1}')"
  else
    # major.minor; get the destination tag we want to use
    DESTINATION_TAG="$(echo "${OPEN_WEBUI_VERSION}" | awk -F 'v' '{print $2}' | awk -F '.' '{print $1"."$2}')"
  fi

  # check to see if we got a tag digest
  if [ -z "${DESTINATION_TAG}" ]
  then
    echo -e "ERROR: DESTINATION_TAG not set!\n"
    exit 1
  fi

  # check to see if the major.minor tag is no longer the value of EXPECTED_TAG
  if [ "${DESTINATION_TAG}" != "${EXPECTED_TAG}" ]
  then
    echo -e "ERROR: the major.minor tag is no longer ${EXPECTED_TAG}; we found ${OPEN_WEBUI_VERSION}!\n"
    exit 1
  fi

  # create the new manifest and push the manifest to docker hub
  echo -n "INFO: Copying image from ghcr and pushing to Docker Hub using skopeo..."
  docker run -t --rm \
    -u "$(id -u):$(id -g)" \
    --name "skopeo-${DESTINATION_TAG}-$(date +%s)" \
    quay.io/skopeo/stable \
      copy \
      --multi-arch all \
      --dest-creds "${HUB_USERNAME}:${HUB_PASSWORD}" \
      "docker://ghcr.io/open-webui/open-webui:${OPEN_WEBUI_VERSION}" "docker://docker.io/mbentley/open-webui:${DESTINATION_TAG}"

  echo -e "done\n"
}

# get last 100 release tags from GitHub; do some filtering to make sure we have something that starts with a normal tag
OPEN_WEBUI_RELEASES="$(wget -q -O - "https://api.github.com/repos/open-webui/open-webui/tags?per_page=100" | jq -r '.[] | select(.name | contains("-") | not) | select((.name | startswith("v0"))) | .name' | sort --version-sort -r)"

# load env_parallel
. "$(command -v env_parallel.bash)"

# run multiple tags in parallel
# shellcheck disable=SC2086
env_parallel -j 4 tag_manifest ::: ${ALL_EXPECTED_TAGS}
