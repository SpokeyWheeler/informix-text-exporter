#!/bin/bash
set -ev
# unit tests here
shellcheck informix-text-runner.sh
shellcheck informix-text-exporter.sh
if [ "${TRAVIS_PULL_REQUEST}" = "false" ]; then
  :
  # integration tests here
fi
