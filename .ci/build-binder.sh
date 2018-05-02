#!/bin/sh

# This script gets called from CI to push a docker image for binder to Docker
# Hub and also to push corresponding binder configuration to the github
# repository $SAGE_BINDER_ENV_GITHUB.

# The following environment variables are required in your CI system:
# * DOCKER_IMAGE the public name of the sagemath image for which we should
#   build a binder image
# * HTTP_GIT_SAGE (used to build a link to the commit represented by this
#   binder image as $HTTP_GIT_SAGE/COMMIT_SHA )
# * SSH_GIT_BINDER (repository to push the autogenerated binder configuration
#   to, git@ URL)
# * BINDER_REPOSITORY (the middle part of the binder URL identifying the
#   repository where the binder configuration lives, see below)
# * SECRET_SSH_GIT_BINDER_KEY (an RSA private key with push access to GIT_BINDER)

# Warning: It is a bit scary to give CI push access to git. We try to make sure
# that your key does not leak into the logs, see ./protect-secrets.sh.
# However, please make sure that the key has only push access to GIT_BINDER and
# that you do nothing otherwise too important in that repository.

# ****************************************************************************
#       Copyright (C) 2018 Julian Rüth <julian.rueth@fsfe.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  http://www.gnu.org/licenses/
# ****************************************************************************

set -ex

if [[ -z "$DOCKER_IMAGE" ]]; then
    echo "DOCKER_IMAGE is not set. The image is not available on a public registry. Cannot build binder."
    exit 0
fi

if [[ -z "$SECRET_SSH_GIT_BINDER_KEY" ]]; then
    echo "No deployment key for git configured. Not pushing binder configuration."
    exit 0
fi

if [[ -z "$SSH_GIT_BINDER" ]]; then
    echo "No git repository configured for binder builds. Not pushing binder configuration."
    exit 0
fi

# Restore private key for ${SECRET_SSH_GIT_BINDER_KEY}.
mkdir -p ~/.ssh/
cat "$SECRET_SSH_GIT_BINDER_KEY" | sed 's/\\n/\n/g' > ~/.ssh/id_rsa
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_rsa

# Setup known_hosts to be able to git push without "Host key verification
# failed" later. (Some default hosts are configured in .ci/known_hosts, you may
# add more in $SSH_KNOWN_HOSTS through CI variables.
cat .ci/known_hosts/* >> ~/.ssh/known_hosts
echo "$SSH_KNOWN_HOSTS" | sed 's/\\n/\n/g' >> ~/.ssh/known_hosts

# escape_md: Escape for interpolation in Markdown literal blocks by stripping out all backticks.
escape_md() {
    echo -n "$*" | sed 's/`//g'
}
# escape_json: Escape for interpolation in JSON double quoted strings.
escape_json() {
    echo -n "$*" | python -c 'import json,sys; print(json.dumps(sys.stdin.read())[1:-1])'
}
# Collect some metadata to include in the home page of the Jupyter notebook and
# also in the README of the branch on SSH_GIT_BINDER.
export AUTHOR="`git log -1 --format=format:%an`"
export AUTHOR_MD="$(escape_md $AUTHOR)"
export AUTHOR_JSON="$(escape_json $AUTHOR_MD)"
export COMMIT_MESSAGE="`git log -1 --format=format:%s%n%n%-b`"
export COMMIT_MESSAGE_MD="$(escape_md $COMMIT_MESSAGE)"
export COMMIT_MESSAGE_JSON="$(escape_json $COMMIT_MESSAGE_MD)"
export COMMIT_TIMESTAMP="$(git log -1 --format=format:%aD)"
export COMMIT_URL="${HTTP_GIT_SAGE}/$(git log -1 --format=%H)"
export BINDER_URL="https://mybinder.org/v2/${BINDER_REPOSITORY}/${BRANCH}?filepath=review.ipynb"

# Substitute the above variables in all files in .ci/binder.
cd .ci/binder
git init
for template in *;do
    mv "$template" "${template}.tmpl"
    envsubst < "${template}.tmpl" > "$template"
    rm -f "${template}.tmpl"
    cat "$template"
    git add "$template"
done
# Verify that the notebook is valid JSON
python -m json.tool < review.ipynb > /dev/null

# Force push a new README and configuration to BRANCH on SSH_GIT_BINDER.
git -c user.name=sage.binder -c user.email=sage.binder@build.invalid commit -m "automatically generated from template"
unset SSH_AUTH_SOCK
unset SSH_ASKPASS
git push --force "${SSH_GIT_BINDER}" "HEAD:${BRANCH}"

echo "Your binder setup has been created. You can try out the code on this branch by going to ${BINDER_URL}"
