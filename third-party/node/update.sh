#!/usr/bin/env bash
cd "$(dirname "$0")"

yarn install
buckle run //build/utils/pnp-buck yarn.lock BUCK

