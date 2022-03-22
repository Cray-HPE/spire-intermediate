#!/bin/ash
export VAULT_ADDR="http://cray-vault.vault.svc.cluster.local:8200"
SECONDS_BETWEEN_CHECKS=5
LEASE_TIME="8760h"
ROLE=spire-intermediate

# Verify that vault is unsealed
check=1
while [ $check -lt 31 ]; do
	echo "Checking to see if Vault is unsealed (${check}/30)"
	if /vault status | grep -qe 'Sealed\ *false'; then
		break
	fi
	check=$(echo $check + 1 | bc)
	sleep "${SECONDS_BETWEEN_CHECKS}"
done

if [ "$check" -gt 30 ]; then
	echo Error. Vault failed to unseal after "$(echo "$SECONDS_BETWEEN_CHECKS" \* "$check" | bc)" seconds. >&2
	exit 1
fi

echo "Vault is unsealed. Continuing PKI setup."

# Verify that pki_common ca is ready
check=1
while [ $check -lt 31 ]; do
	echo "Checking to see if we can fetch ${PKI_PATH}'s CA (${check}/30)"
	if /vault read --format=json pki_common/cert/ca >/dev/null 2>&1; then
		break
	fi
	check=$(echo $check + 1 | bc)
	sleep "${SECONDS_BETWEEN_CHECKS}"
done

if [ "$check" -gt 30 ]; then
	echo Error. CA not ready after "$(echo "$SECONDS_BETWEEN_CHECKS" \* "$check" | bc)" seconds. >&2
	exit 1
fi

echo "CA is ready. Continuing PKI setup."

# Exit on any failure past here
set -euo pipefail

echo "Logging into vault"

KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
VAULT_TOKEN=$(curl --request POST \
	--data '{"jwt": "'"$KUBE_TOKEN"'", "role": "'"$ROLE"'"}' \
	$VAULT_ADDR/v1/auth/kubernetes/login | jq -r .auth.client_token)

/vault login "$VAULT_TOKEN" >/dev/null 2>&1

# Create an interemediate CA for each spire instance. This is required on a per
# namespace basis because pods cannot read secrets in other namespaces.
for NAMESPACE in $(echo $NAMESPACES | tr -d ']['); do

	TMP_PATH="/tmp/${NAMESPACE}"

	mkdir "$TMP_PATH"
	cd "$TMP_PATH"

	if /kubectl get secrets -n "$NAMESPACE" | grep -q "spire.${NAMESPACE}.ca-tls"; then
		cert=$(date --date="$(/kubectl get secret -n spire spire.spire.ca-tls -o json | jq -r '.data."tls.crt" | @base64d' | openssl x509 -noout -enddate | awk -F= '{print $NF}')" +%s)
		curr=$(date +%s)
		month=2629746
		if [ $((cert - curr)) -gt $month ]; then
			echo "spire.${NAMESPACE}.ca-tls secret already exists and has $((cert - curr - month)) seconds left."

			# Kill Istio sidecar
			echo "Stopping Istio Sidecar."
			curl -X POST http://localhost:15020/quitquitquit
			exit 0
		else
			echo "spire.${NAMESPACE}.ca-tls has less than a month left. replacing."
			/kubectl delete -n spire secret "spire.${NAMESPACE}.ca-tls"
		fi
	fi

	echo "Creating self-signed intermediate for ${NAMESPACE}"
	openssl req -nodes -newkey rsa:4096 -keyout "${TMP_PATH}/tls.key" -out "${TMP_PATH}/tls.csr" -subj "/C=US/ST=Minnesota/L=Minneapolis/O=Shasta/OU=Platform/CN=${NAMESPACE} - L2 Intermediate CA"

	/vault write -format=json "${PKI_PATH}/root/sign-intermediate" "csr=@${TMP_PATH}/tls.csr" \
		format=pem_bundle ttl="${LEASE_TIME}" |
		jq -r '.data.certificate' >"${TMP_PATH}/tls.crt"

	/vault read --format=json pki_common/cert/ca | jq -r .data.certificate >"${TMP_PATH}/ca.crt"

	/kubectl -n "$NAMESPACE" create secret generic "spire.${NAMESPACE}.ca-tls" \
		--from-file=./ca.crt --from-file=./tls.crt --from-file=./tls.key
	echo "Completed creating intermediate certificates."
done

# Kill Istio sidecar
echo "Stopping Istio Sidecar."
curl -X POST http://localhost:15020/quitquitquit
