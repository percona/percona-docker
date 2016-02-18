FROM ubuntu:latest

EXPOSE 9000 9001 9002 9090

WORKDIR /opt

# ########################### #
# MySQL and other system pkgs #
# ########################### #

RUN apt-get -y update && apt-get install -y \
	apt-transport-https \
	curl \
	git \
	mysql-server \
	python \
	supervisor

# ########## #
# Prometheus #
# ########## #

ADD https://github.com/prometheus/prometheus/releases/download/0.16.2/prometheus-0.16.2.linux-amd64.tar.gz /opt/
RUN mkdir prometheus && tar xfz prometheus-0.16.2.linux-amd64.tar.gz --strip-components=1 -C prometheus
COPY prometheus.yml /opt/prometheus/

# ####### #
# Grafana #
# ####### #

RUN echo "deb https://packagecloud.io/grafana/stable/debian/ wheezy main" > /etc/apt/sources.list.d/grafana.list \
	&& curl https://packagecloud.io/gpg.key | apt-key add - \
	&& apt-get -y update \
	&& apt-get -y install grafana \
	&& mkdir /var/lib/grafana/dashboards
RUN git clone https://github.com/percona/grafana-dashboards.git \
	&& cp grafana-dashboards/dashboards/* /var/lib/grafana/dashboards/
COPY grafana.ini /etc/grafana/grafana.ini
RUN chgrp grafana /etc/grafana/grafana.ini

# ####################### #
# Percona Query Analytics #
# ####################### #
ADD \
	https://www.percona.com/downloads/TESTING/ppl/open-source/ppl-datastore.tar.gz \
	https://www.percona.com/downloads/TESTING/ppl/open-source/ppl-qan-app.tar.gz \
	/opt/
RUN mkdir qan-api && tar zxf ppl-datastore.tar.gz --strip-components=1 -C qan-api
RUN mkdir qan-app && tar zxf ppl-qan-app.tar.gz   --strip-components=1 -C qan-app
COPY install-qan.sh /opt
RUN /opt/install-qan.sh

# ############################## #
# Run everything with supervisor #
# ############################## #

COPY supervisord.conf /etc/supervisor/conf.d/percona-mms.conf
CMD ["supervisord"]
