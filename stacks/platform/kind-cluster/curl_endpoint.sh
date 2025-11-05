#!/usr/bin/env bash

set -eou pipefail

ENDPOINT="$("$TG_CTX_TF_PATH" output -raw cluster_endpoint)"
CA_CERT="$("$TG_CTX_TF_PATH" output -raw cluster_ca_certificate)"
CLIENT_CERT="$("$TG_CTX_TF_PATH" output -raw client_certificate)"
CLIENT_KEY="$("$TG_CTX_TF_PATH" output -raw client_key)"

curl --silent --show-error \
  --cacert <(echo "$CA_CERT") \
  --cert <(echo "$CLIENT_CERT") \
  --key  <(echo "$CLIENT_KEY") \
  "${ENDPOINT}"/livez
#  "${ENDPOINT}"/opentofu
