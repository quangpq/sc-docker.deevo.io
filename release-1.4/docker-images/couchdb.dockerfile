# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

FROM ubuntu:16.04

# Add CouchDB user account
RUN groupadd -g 5984 -r couchdb && useradd -u 5984 -d /opt/couchdb -g couchdb couchdb

RUN apt-get update -y && apt-get install -y --no-install-recommends \
        apt-transport-https \
        ca-certificates \
        curl \
        erlang-nox \
        erlang-reltool \
        libicu55 \
        libmozjs185-1.0 \
        openssl \
    && rm -rf /var/lib/apt/lists/*

# grab gosu for easy step-down from root and tini for signal handling
# see https://github.com/apache/couchdb-docker/pull/28#discussion_r141112407
ENV GOSU_VERSION 1.10
ENV TINI_VERSION 0.16.1
RUN set -ex; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends wget; \
	rm -rf /var/lib/apt/lists/*; \
	\
	dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	\
# install gosu
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
        for server in $(shuf -e ha.pool.sks-keyservers.net \
            hkp://p80.pool.sks-keyservers.net:80 \
            keyserver.ubuntu.com \
            hkp://keyserver.ubuntu.com:80 \
            pgp.mit.edu) ; do \
        gpg --keyserver "$server" --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && break || : ; \
        done; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	rm -rf "$GNUPGHOME" || true; rm -r /usr/local/bin/gosu.asc || true; \
	chmod +x /usr/local/bin/gosu; \
	gosu nobody true; \
    \
# install tini
	wget -O /usr/local/bin/tini "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-$dpkgArch"; \
	wget -O /usr/local/bin/tini.asc "https://github.com/krallin/tini/releases/download/v${TINI_VERSION}/tini-$dpkgArch.asc"; \
	export GNUPGHOME="$(mktemp -d)"; \
        for server in $(shuf -e ha.pool.sks-keyservers.net \
            hkp://p80.pool.sks-keyservers.net:80 \
            keyserver.ubuntu.com \
            hkp://keyserver.ubuntu.com:80 \
            pgp.mit.edu) ; do \
        gpg --keyserver "$server" --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 && break || : ; \
        done; \
	gpg --batch --verify /usr/local/bin/tini.asc /usr/local/bin/tini; \
	rm -rf "$GNUPGHOME" || true; rm -r /usr/local/bin/tini.asc || true; \
	chmod +x /usr/local/bin/tini; \
	tini --version; \
	\
	apt-get purge -y --auto-remove wget

# https://www.apache.org/dist/couchdb/KEYS
ENV GPG_KEYS \
  15DD4F3B8AACA54740EB78C7B7B7C53943ECCEE1 \
  1CFBFA43C19B6DF4A0CA3934669C02FFDF3CEBA3 \
  25BBBAC113C1BFD5AA594A4C9F96B92930380381 \
  4BFCA2B99BADC6F9F105BEC9C5E32E2D6B065BFB \
  5D680346FAA3E51B29DBCB681015F68F9DA248BC \
  7BCCEB868313DDA925DF1805ECA5BCB7BB9656B0 \
  C3F4DFAEAD621E1C94523AEEC376457E61D50B88 \
  D2B17F9DA23C0A10991AF2E3D9EE01E47852AEE4 \
  E0AF0A194D55C84E4A19A801CDB0C0F904F4EE9B \
  29E4F38113DF707D722A6EF91FE9AF73118F1A7C \
  2EC788AE3F239FA13E82D215CDE711289384AE37
RUN set -xe \
    && for key in $GPG_KEYS; do \
        for server in $(shuf -e ha.pool.sks-keyservers.net \
            hkp://p80.pool.sks-keyservers.net:80 \
            keyserver.ubuntu.com \
            hkp://keyserver.ubuntu.com:80 \
            pgp.mit.edu) ; do \
        gpg --keyserver "$server" --recv-keys "$key" && break || : ; \
        done; \
    done

ENV COUCHDB_VERSION 2.2.0

# Download dev dependencies
RUN buildDeps=' \
        apt-transport-https \
        gcc \
        g++ \
        build-essential \
        erlang-dev \
        erlang-nox \ 
        erlang-reltool \
        libcurl4-openssl-dev \
        libicu-dev \
        libmozjs185-dev \
        make \
    ' \
    && apt-get update -y -qq && apt-get install -y --no-install-recommends $buildDeps \
    # Acquire CouchDB source code
    && cd /usr/src && mkdir couchdb \
    && curl -fSL https://dist.apache.org/repos/dist/release/couchdb/source/$COUCHDB_VERSION/apache-couchdb-$COUCHDB_VERSION.tar.gz -o couchdb.tar.gz \
    && curl -fSL https://dist.apache.org/repos/dist/release/couchdb/source/$COUCHDB_VERSION/apache-couchdb-$COUCHDB_VERSION.tar.gz.asc -o couchdb.tar.gz.asc \
    && gpg --batch --verify couchdb.tar.gz.asc couchdb.tar.gz \
    && tar -xzf couchdb.tar.gz -C couchdb --strip-components=1 \
    && cd couchdb \
    # Build the release and install into /opt
    && ./configure --disable-docs \
    && make release \
    && mv /usr/src/couchdb/rel/couchdb /opt/ \
    # Cleanup build detritus
    && apt-get purge -y --auto-remove $buildDeps \
    && rm -rf /var/lib/apt/lists/* /usr/src/couchdb* \
    && mkdir /opt/couchdb/data \
    && chown -R couchdb:couchdb /opt/couchdb

# Add configuration
RUN apt-get update -y
RUN apt-get install -y wget
RUN wget -O /opt/couchdb/etc/default.d/10-docker-default.ini "https://raw.githubusercontent.com/hyperledger/fabric-baseimage/master/images/couchdb/10-docker-default.ini"
RUN wget -O /opt/couchdb/etc/default.d/20-fabric-default.ini "https://raw.githubusercontent.com/hyperledger/fabric-baseimage/master/images/couchdb/20-fabric-default.ini"
RUN wget -O /opt/couchdb/docker-entrypoint.sh "https://raw.githubusercontent.com/hyperledger/fabric-baseimage/master/images/couchdb/docker-entrypoint.sh"
RUN wget -O /opt/couchdb/etc/vm.args "https://raw.githubusercontent.com/hyperledger/fabric-baseimage/master/images/couchdb/vm.args"

# Setup directories and permissions
RUN chown -R couchdb:couchdb /opt/couchdb/etc/default.d/ /opt/couchdb/etc/vm.args /opt/couchdb/docker-entrypoint.sh
RUN chmod +x /opt/couchdb/docker-entrypoint.sh

WORKDIR /opt/couchdb
EXPOSE 5984 4369 9100
VOLUME ["/opt/couchdb/data"]

ENTRYPOINT ["tini", "--", "/opt/couchdb/docker-entrypoint.sh"]
CMD ["/opt/couchdb/bin/couchdb"]