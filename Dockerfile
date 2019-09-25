FROM registry.access.redhat.com/ubi7/s2i-core:latest

EXPOSE 3000

LABEL io.openshift.expose-services="3000:http"

RUN yum install -y java-1.8.0-openjdk && yum clean all

ARG JAVA_XMS=64m
ENV JAVA_XMS=$JAVA_XMS

ARG JAVA_XMX=4g
ENV JAVA_XMX=$JAVA_XMX

ARG JAVA_OPTS
ENV JAVA_OPTS=$JAVA_OPTS

COPY metabase.jar .
RUN echo "#!/usr/bin/env bash\njava -jar -Xms$JAVA_XMS -Xmx$JAVA_XMX $JAVA_OPTS metabase.jar" > ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
