FROM eclipse-temurin:17.0.3_7-jre

ENV LANG C.UTF-8
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
    bash curl ca-certificates findutils coreutils gettext pwgen procps tini \
    ; \
    rm -rf /var/lib/apt/lists/*

# Fuseki version
ENV FUSEKI_SHA512 12a7c242584fa739d0d1d2a4025267552069d8bf7b411545d0328e3cacc3bceddaac0584b405772b51464c33f695da86182a60480c72a661264677281771e700
ENV FUSEKI_VERSION 4.6.1
ENV ASF_CDN https://dlcdn.apache.org/jena/binaries

# Config and data
ENV FUSEKI_BASE /fuseki

# Installation folder
ENV FUSEKI_HOME /jena-fuseki

WORKDIR /tmp
# published sha512 checksum
RUN echo "$FUSEKI_SHA512  fuseki.tar.gz" > fuseki.tar.gz.sha512
# Download/check/unpack/move in one go (to reduce image size)
RUN curl --silent --show-error --fail --retry-connrefused --retry 3 --output fuseki.tar.gz ${ASF_CDN}/apache-jena-fuseki-$FUSEKI_VERSION.tar.gz && \
    sha512sum -c fuseki.tar.gz.sha512 && \
    tar zxf fuseki.tar.gz && \
    mv apache-jena-fuseki* $FUSEKI_HOME && \
    rm fuseki.tar.gz* && \
    cd $FUSEKI_HOME && rm -rf fuseki.war && chmod 755 fuseki-server

# Test the install by testing it's ping resource. 20s sleep because Docker Hub.
RUN $FUSEKI_HOME/fuseki-server --port 8080 & \
    sleep 20 && \
    curl -sS --fail 'http://localhost:8080/$/ping'

# No need to kill Fuseki as our shell will exit after curl

COPY shiro.ini $FUSEKI_HOME/

RUN mkdir $FUSEKI_HOME/dataset-config
COPY dataset-config/*.ttl $FUSEKI_HOME/dataset-config/

COPY entrypoint.sh /
RUN chmod 755 /entrypoint.sh

COPY load.sh $FUSEKI_HOME/
COPY tdbloader $FUSEKI_HOME/
COPY tdbloader2 $FUSEKI_HOME/
RUN chmod 755 $FUSEKI_HOME/load.sh $FUSEKI_HOME/tdbloader $FUSEKI_HOME/tdbloader2

# Where we start our server from
WORKDIR $FUSEKI_HOME

# Make sure we start with empty /fuseki
RUN rm -rf $FUSEKI_BASE
VOLUME $FUSEKI_BASE

EXPOSE 8080
ENTRYPOINT ["/usr/bin/tini", "-s", "--", "/entrypoint.sh"]
CMD ["/jena-fuseki/fuseki-server", "--port", "8080"]
