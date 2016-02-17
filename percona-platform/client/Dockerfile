FROM centos

EXPOSE 9104 9204 9304 9100

WORKDIR /opt

RUN yum -y install git make python-setuptools
RUN easy_install supervisor

RUN git clone https://github.com/prometheus/node_exporter.git
RUN cd node_exporter && make
RUN git clone https://github.com/prometheus/mysqld_exporter.git
RUN cd mysqld_exporter && make

ADD https://www.percona.com/downloads/TESTING/ppl/open-source/ppl-agent.tar.gz /opt
RUN mkdir qan-agent && tar zxf ppl-agent.tar.gz --strip-components=1 -C qan-agent

COPY supervisord.conf /etc/
COPY start.sh /opt
CMD ["/opt/start.sh"]
