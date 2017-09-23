FROM jenkins/jenkins:2.79

MAINTAINER John Bryan Sazon and Arcy Teodoro 

# Copy in configuration files
COPY resources/plugins.txt /usr/share/jenkins/ref/
COPY resources/init.groovy.d/ /usr/share/jenkins/ref/init.groovy.d/
COPY resources/scripts/ /usr/share/jenkins/ref/adop_scripts/
COPY resources/jobs/ /usr/share/jenkins/ref/jobs/
COPY resources/scriptler/ /usr/share/jenkins/ref/scriptler/scripts/
COPY resources/views/ /usr/share/jenkins/ref/init.groovy.d/
COPY resources/m2/ /usr/share/jenkins/ref/.m2
COPY resources/entrypoint.sh /entrypoint.sh
COPY resources/jenkins_home/ /usr/share/jenkins/ref/
COPY resources/plugins-v2.sh /usr/local/bin/plugins-v2.sh

# Reprotect
USER root
RUN chmod +x -R /usr/share/jenkins/ref/adop_scripts/ && chmod +x /entrypoint.sh

# Install additional packages
# zip is required for plugins-v2.sh
RUN wget "http://http.us.debian.org/debian/pool/main/z/zip/zip_3.0-11+b1_amd64.deb" && \
    dpkg -i zip_3.0-11+b1_amd64.deb && \
    rm -f zip_3.0-11+b1_amd64.deb

# USER jenkins

# Environment variables for SCM
ENV GERRIT_HOST_NAME=gerrit\
    GERRIT_PORT=8080 \
    GERRIT_JENKINS_USERNAME="" \
    GERRIT_JENKINS_PASSWORD="" \
    GITLAB_HOST_NAME=gitlab \
    GITLAB_HTTP_URL=http://${GITLAB_HOST_NAME}/gitlab \
    GITLAB_PORT=80 \
    GITLAB_JENKINS_USERNAME="" \
    GITLAB_JENKINS_PASSWORD="" \
    GITLAB_JENKINS_TOKEN="" \
    GIT_REPO=gitlab

# Environment variables for Plugins switch
ENV ADOP_LDAP_ENABLED=true \
    ADOP_SONAR_ENABLED=true \
    ADOP_ANT_ENABLED=true \
    ADOP_MAVEN_ENABLED=true \
    ADOP_NODEJS_ENABLED=true \
    ADOP_GERRIT_ENABLED=false \
    ADOP_GITLAB_ENABLED=false

ENV JENKINS_OPTS="--prefix=/jenkins -Djenkins.install.runSetupWizard=false"

#RUN /usr/local/bin/plugins.sh /usr/share/jenkins/ref/plugins.txt
RUN /usr/local/bin/plugins-v2.sh /usr/share/jenkins/ref/plugins.txt

ENTRYPOINT ["/entrypoint.sh"]
