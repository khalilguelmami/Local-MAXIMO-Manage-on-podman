######################################
# Stage intermédiaire pour installer ping (UBI complet)
######################################
FROM registry.access.redhat.com/ubi8/ubi:8.8 AS pingbuilder
USER root
RUN dnf install -y iputils && dnf clean all

######################################
# Build Admin image pour Maximo EAR
######################################
FROM localhost/manage-admin-dev as admin

WORKDIR /opt/IBM/SMP/maximo/applications/maximo
RUN rm -rf businessobjects/classes/custom \
    && rm -rf maximouiweb/webmodule/WEB-INF/classes/custom

# Remplacer web.xml pour maximouiweb
WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/maximouiweb/webmodule/WEB-INF/
RUN mv web.xml web-oidc.xml
RUN mv web-dev.xml web.xml

# Remplacer web.xml pour maxrestweb
WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/maxrestweb/webmodule/WEB-INF/
RUN mv web.xml web-oidc.xml
RUN mv web-dev.xml web.xml

# Remplacer web.xml pour mboweb
WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/mboweb/webmodule/WEB-INF/
RUN mv web.xml web-oidc.xml
RUN mv web-dev.xml web.xml

# Remplacer web.xml pour meaweb
WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default/config-deployment-descriptors/maximo-all/meaweb/webmodule/WEB-INF/
RUN mv web.xml web-oidc.xml
RUN mv web-dev.xml web.xml

# Créer le EAR
WORKDIR /opt/IBM/SMP/maximo/deployment/was-liberty-default
RUN ./maximo-all.sh

######################################
# Image finale
######################################
FROM localhost/manage-all-dev
USER root

# Copier le binaire ping depuis le stage UBI
COPY --from=pingbuilder /usr/bin/ping /usr/bin/ping
COPY --from=pingbuilder /usr/lib64/libcap.so.2 /usr/lib64/

# Copier le EAR depuis le stage admin
COPY --from=admin /opt/IBM/SMP/maximo/deployment/was-liberty-default/deployment/maximo-all/maximo-all-server/apps/maximo-all.ear /config/apps/

# Expand l'application
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

# Fix local authentication
WORKDIR /config
RUN mv server.xml server-oidc.xml \
    && mv server-dev.xml server.xml \
    && sed -i '/wmqJmsClient/d' server.xml

# Variables d'environnement
ENV DB_SSL_ENABLED=nossl

ENV MXE_DB_DRIVER='com.microsoft.sqlserver.jdbc.SQLServerDriver'
ENV MXE_SECURITY_OLD_CRYPTO_KEY=QqajEPdJUTPagqSfyiDCDzBF
ENV MXE_SECURITY_CRYPTO_KEY=QqajEPdJUTPagqSfyiDCDzBF
ENV MXE_SECURITY_OLD_CRYPTOX_KEY=znZHfnPQcyJCgJISYWzUluEW
ENV MXE_SECURITY_CRYPTOX_KEY=znZHfnPQcyJCgJISYWzUluEW
ENV MXE_USEAPPSERVERSECURITY=0
ENV MXE_MASDEPLOYED=0
ENV LC_ALL=en_US.UTF-8

# Options debug Open Liberty
ENV WLP_DEBUG_SUSPEND=n
ENV WLP_DEBUG_REMOTE=y


# Repasser en utilisateur non-root
USER 1001

# Commande de démarrage
CMD ["/opt/ibm/wlp/bin/server", "debug", "defaultServer"]
