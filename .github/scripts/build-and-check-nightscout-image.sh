#!/bin/sh
set -eu

sh tests/deployment/test-nightscout-deployment.sh
sh tests/deployment/test-nightscout-access.sh
docker build --platform linux/arm64 -t nightscout:ci .
sh tests/deployment/test-nightscout-image.sh
