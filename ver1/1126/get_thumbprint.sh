#!/bin/bash

THUMBPRINT=$(echo | openssl s_client -servername token.actions.githubusercontent.com -showcerts -connect token.actions.githubusercontent.com:443 < /dev/null 2>/dev/null | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' | sed "0,/-END CERTIFICATE-/d")

THUMBPRINT_JSON=$(echo "$THUMBPRINT" | openssl x509 -fingerprint -noout | cut -f2 -d'=' | tr -d ':' | tr '[:upper:]' '[:lower:]')

echo "{\"thumbprint\": \"${THUMBPRINT_JSON}\"}"