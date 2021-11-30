FROM artifactory.algol60.net/docker.io/library/alpine

RUN apk update && apk -U upgrade && \
    apk add --upgrade --no-cache apk-tools curl unzip jq openssl && \
    rm -rf /var/cache/apk/*

RUN curl https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl > /kubectl && chmod +x /kubectl

RUN curl https://releases.hashicorp.com/vault/1.3.3/vault_1.3.3_linux_amd64.zip > vault.zip \
      && unzip vault.zip \
      && rm vault.zip

COPY openssl.cnf /openssl.cnf
COPY spire-intermediate.sh /spire-intermediate.sh
RUN chmod +x /spire-intermediate.sh

RUN addgroup -S pki
RUN adduser -S pki -G pki
USER pki
WORKDIR /

CMD ["/spire-intermediate.sh"]
