FROM ubuntu:18.04

MAINTAINER Jeff Milton
#
#  RUN A WEB SERVICE FOR FAST SEQUENCE SIMILARITY SEARCHES
#
# Install OpenJDK-8
RUN apt-get update -y && \
    apt-get install -y openjdk-8-jdk && \
    apt-get install -y ant && \
    apt-get clean && apt-get install -y wget

# Fix certificate issues
RUN apt-get update && \
    apt-get install ca-certificates-java && \
    apt-get clean && \
    update-ca-certificates -f;

# Setup JAVA_HOME -- useful for docker commandline
ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

ENV HOME /ab
WORKDIR $HOME

ENV TOMCAT_HOME /ab/server/tomcat
RUN mkdir $HOME/server && mkdir $HOME/server/tomcat


#############################################################################################
# INSTALL MYSQL
#############################################################################################
RUN \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server && \
  rm -rf /var/lib/apt/lists/* && \
  mkdir -p /var/run/mysqld && \
  echo " chown " && \
  chown mysql:mysql /var/run/mysqld && \
  echo "mysqld_safe &" > /tmp/config && \
  echo "mysqladmin --silent --wait=30 ping || exit 1" >> /tmp/config && \
  echo "mysql -e 'create database ab;'" >> /tmp/config  && \
  echo "mysql -e 'GRANT ALL ON *.* TO \"arraybase\"@\"localhost\" IDENTIFIED BY \"abab\" WITH GRANT OPTION;'" >> /tmp/config  && \
  echo "mysql -e 'GRANT ALL ON *.* TO \"arraybase\"@\"%\" IDENTIFIED BY \"abab\" WITH GRANT OPTION;'" >> /tmp/config  && \
  bash /tmp/config && \
  rm -f /tmp/config
COPY ./resources/mysql.cnf /etc/mysql/mysql.conf.d/mysqld.cnf


RUN echo "INSTALLING aws"
#############################################################################################
#   INSTALL AWS
#############################################################################################
RUN  apt-get -yq update && \
     apt-get -yqq install ssh
RUN apt-get update
RUN mkdir /root/.ssh


#############################################################################################
#  INSTALL ARRAYBASE v2 
#############################################################################################

#############################################################################################
#############################################################################################
RUN echo "----------------------------------------------------------------------------------"
RUN echo "Installing ArrayBase v2.9 "
RUN echo "----------------------------------------------------------------------------------"

COPY resources/lib $HOME/lib
COPY resources/ab_config $HOME/.ab.config
RUN mkdir $HOME/config && mkdir $HOME/bin
COPY resources/ab_config /root/.ab.config
COPY resources/scripts/start-search-server.sh $HOME/bin/start-search-server.sh
RUN echo "Installing the AB resources" 
RUN echo "Installing the AB resources" 

COPY resources/scripts/installab.sh $HOME/bin/installab.sh
COPY resources/scripts/build-index.sh $HOME/bin/build-index.sh
RUN chmod +x $HOME/bin/*.sh


COPY ./resources/lib/ $HOME/lib
ENV ARRAYBASE $HOME/lib/actgIO.jar

RUN echo ' Adding the instalation directory '
COPY resources/install_config $HOME/install_config


#############################################################################################
# SOLR
#############################################################################################
RUN echo "##################################################################################"
RUN echo "##################################################################################"
RUN echo "##################################################################################"
RUN echo "##################################################################################"
COPY resources/servers/solr-8.1.0.tgz ./server
RUN ls $HOME/server
RUN cd $HOME/server && tar -xvf ./solr-8.1.0.tgz
ENV SOLR_BASE $HOME/server/solr-8.1.0
ENV SOLR_HOME $HOME/server/solr-8.1.0/server/solr
RUN ls $SOLR_BASE
RUN echo "##################################################################################"
RUN echo "Copy the solr cor config into the solr home directory " 
COPY resources/servers/solr-core-config/ $SOLR_HOME
RUN ls $SOLR_HOME
RUN tar -xvzf $SOLR_HOME/cors.tar.gz -C $SOLR_HOME
# instead of doign this we will mount a data volume 

#############################################################################################
# CHECKOUT the plugin src. 
#############################################################################################
RUN echo "\n\n Checkout and configure solr plugin "
# NEED THIS PLUGIN SOURCE BECAUSE IT CONTAINS THE SCHEMA AND CONFIG FILES   
RUN ls $SOLR_HOME
COPY resources/install_config/solrconfig_template.xml $SOLR_HOME 
COPY resources/install_config/solr_template.xml $SOLR_HOME 
RUN echo "\n\n\n\n\n\n Loading the solr plugin into the solr library directory \n\n\n\n\n\n\nn\n " 
COPY resources/lib/absolrplugv1.jar $SOLR_HOME/lib
COPY resources/install_config/web.xml $SOLR_BASE/server/solr-webapp/webapp/WEB-INF
COPY resources/install_config/solr.xml $SOLR_HOME/
RUN echo "JAVA_HOME=/usr/lib/jvm/java-8-oracle" >> /etc/default/tomcat7

#############################################################################################
#  INSTALL THE ISIS main CORES 
#############################################################################################
RUN echo " Installing isis-cores-config " 
RUN echo ls $SOLR_HOME
COPY resources/isis-cores-config.tar $SOLR_HOME
RUN cd $SOLR_HOME && tar -xvf isis-cores-config.tar 


#############################################################################################
#  INSTALL  ab in mysql 
#############################################################################################
RUN echo "Installing AB... " 
RUN cd $HOME/bin && ./installab.sh

#############################################################################################
#   Install TOMCAT
#############################################################################################
ENV APTCVERSION apache-tomcat-9.0.40.tar.gz
ENV APTCFOLDER apache-tomcat-9.0.40
RUN wget https://downloads.apache.org/tomcat/tomcat-9/v9.0.40/bin/$APTCVERSION
RUN tar xzf $APTCVERSION
RUN ls $HOME/server/tomcat

RUN rm -rf $HOME/server/tomcat/*

RUN mv $APTCFOLDER/* $HOME/server/tomcat/ && \
        rm -rf $HOME/server/tomcat/webapps/ROOT
#ADD resources/start_tomcat.sh $HOME/bin/start_tomcat.sh
#RUN chmod +x $HOME/bin/start_tomcat.sh
RUN echo " ------------------------------- " 
RUN echo " --- Done installing TOMCAT ---- " 
RUN echo " ------------------------------- " 

#############################################################################################
#  INSTALL THE mntSearch REST
#############################################################################################
RUN echo " Installing solr-array "
COPY resources/lib/search-array-rest.war $HOME/server/tomcat/webapps/ROOT.war
RUN echo " Installing solrarray " 
COPY resources/lib/solr-array-srv.war $HOME/server/tomcat/webapps/solrarray.war
RUN cd $HOME
ADD resources/scripts/start-rest.sh $HOME/bin/start-rest.sh
ADD resources/scripts/start.sh $HOME/bin/start.sh
RUN chmod +x $HOME/bin/start-rest.sh
RUN chmod +x $HOME/bin/start.sh
RUN mkdir $HOME/index-configs
ENV INDEX-CONFIGS=$HOME/index-configs



#############################################################################################
# INSTALL SOME AWS STUFF
#############################################################################################

RUN apt-get install -y vim && \
        apt-get install -y curl


RUN curl -O https://bootstrap.pypa.io/get-pip.py
RUN apt-get install -y python3-distutils
RUN python3 get-pip.py

RUN pip3 install awscli --upgrade --user


EXPOSE 3306 8080 8983 4200
#ENTRYPOINT ["/search/bin/start.sh" ]
