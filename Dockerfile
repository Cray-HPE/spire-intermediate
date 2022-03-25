#
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
FROM artifactory.algol60.net/docker.io/library/alpine

RUN apk update && apk -U upgrade && \
  apk add --upgrade --no-cache apk-tools coreutils curl unzip jq openssl && \
  rm -rf /var/cache/apk/*

RUN curl https://storage.googleapis.com/kubernetes-release/release/v1.20.13/bin/linux/amd64/kubectl > /kubectl && chmod +x /kubectl

RUN curl https://releases.hashicorp.com/vault/1.5.5/vault_1.5.5_linux_amd64.zip > vault.zip \
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
