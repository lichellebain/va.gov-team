#!/bin/bash -e

# note this logic is duplicated in the Dockerfile for prod builds,
# if you make major alteration here, please check that usage as well

BUNDLED_WITH=$(awk '/BUNDLED WITH/{getline; print}' Gemfile.lock | xargs) gem install bundler -v "$BUNDLED_WITH"
bundle binstubs bundler --force
bundle check || bundle install --binstubs="${BUNDLE_APP_CONFIG}/bin" --jobs=4

exec "$@"

if [ -e  "./docker_debugging" ] ; then
  echo starting rake docker_debugging:setup
  rake docker_debugging:setup
fi

