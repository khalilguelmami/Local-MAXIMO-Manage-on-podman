######################################
# Helper stage: get the ping binary from a full UBI image
######################################
FROM registry.access.redhat.com/ubi8/ubi:8.8 AS pingbuilder
USER root
RUN dnf install -y iputils && dnf clean all

######################################
# Build stage: rebuild the Maximo EAR from the -admin image
######################################
FROM localhost/manage-admin-dev as admin

WORKDIR /opt/IBM/SMP/maximo/applications/maximo
RUN rm -rf businessobjects/classes/custom \
    && rm -rf maximouiweb/webmodule/WEB-INF/classes/custom

# Switch each web module from OIDC (MAS core) to local authentication.
# The OIDC descriptors are kept as web-oidc.xml.
WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/maximouiweb/webmodule/WEB-INF/
RUN mv web.xml web-oidc.xml
RUN mv web-dev.xml web.xml

WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/maxrestweb/webmodule/WEB-INF/
RUN mv web.xml web-oidc.xml
RUN mv web-dev.xml web.xml

WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/mboweb/webmodule/WEB-INF/
RUN mv web.xml web-oidc.xml
RUN mv web-dev.xml web.xml

WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/meaweb/webmodule/WEB-INF/
RUN mv web.xml web-oidc.xml
RUN mv web-dev.xml web.xml

# Build maximo-all.ear
WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default
RUN ./maximo-all.sh

######################################
# Final image: the -all server bundle with the rebuilt EAR
######################################
FROM localhost/manage-all-dev
USER root

# ping, handy to test database connectivity from the container
COPY --from=pingbuilder /usr/bin/ping /usr/bin/ping
COPY --from=pingbuilder /usr/lib64/libcap.so.2 /usr/lib64/

# Copy the rebuilt EAR
COPY --from=admin /opt/IBM/SMP/maximo/deployment/was-liberty-default/deployment/maximo-all/maximo-all-server/apps/maximo-all.ear /config/apps/

# Expand the EAR (and businessobjects.jar / maximouiweb.war) so classes and JSPs
# can be replaced in place while debugging
WORKDIR /config/apps
RUN mv maximo-all.ear _maximo-all.ear \
    && mkdir maximo-all.ear \
    && unzip -qq _maximo-all.ear -d maximo-all.ear \
    && ( \
        cd maximo-all.ear \
        && mv businessobjects.jar _businessobjects.jar \
        && mv maximouiweb.war _maximouiweb.war \
        && mkdir businessobjects.jar maximouiweb.war \
        && unzip -qq _businessobjects.jar -d businessobjects.jar \
        && unzip -qq _maximouiweb.war -d maximouiweb.war \
        && rm -f _businessobjects.jar _maximouiweb.war \
    ) \
    && rm -f _maximo-all.ear

# Use the development server.xml (local authentication) and drop the MQ JMS client
WORKDIR /config
RUN mv server.xml server-oidc.xml \
    && mv server-dev.xml server.xml \
    && sed -i '/wmqJmsClient/d' server.xml

# Non-secret settings. Database credentials and crypto keys are NOT baked into
# the image: they are passed at run time from manage-dev.env (see README).
ENV DB_SSL_ENABLED=nossl
ENV MXE_DB_DRIVER='com.microsoft.sqlserver.jdbc.SQLServerDriver'
ENV MXE_USEAPPSERVERSECURITY=0
ENV MXE_MASDEPLOYED=0
ENV LC_ALL=en_US.UTF-8

# Open Liberty remote debug (port 7777), without waiting for a debugger
ENV WLP_DEBUG_SUSPEND=n
ENV WLP_DEBUG_REMOTE=y

USER 1001

CMD ["/opt/ibm/wlp/bin/server", "debug", "defaultServer"]
