FROM ubuntu:latest

EXPOSE 3000 9090 9001-9003

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
	golang \
	supervisor

# ########## #
# Prometheus #
# ########## #

ADD https://github.com/prometheus/prometheus/releases/download/0.17.0/prometheus-0.17.0.linux-amd64.tar.gz /opt/
RUN mkdir prometheus && \
	tar xfz prometheus-0.17.0.linux-amd64.tar.gz --strip-components=1 -C prometheus
COPY prometheus.yml /opt/prometheus/

# ####### #
# Grafana #
# ####### #

RUN echo "deb https://packagecloud.io/grafana/stable/debian/ wheezy main" > /etc/apt/sources.list.d/grafana.list && \
	curl https://packagecloud.io/gpg.key | apt-key add - && \
	apt-get -y update && \
	apt-get -y install grafana
RUN git clone https://github.com/percona/grafana-dashboards.git && \
	mkdir /var/lib/grafana/dashboards && \
	cp grafana-dashboards/dashboards/* /var/lib/grafana/dashboards/
COPY grafana.ini /etc/grafana/grafana.ini
COPY add-grafana-datasource.sh /opt
RUN chgrp grafana /etc/grafana/grafana.ini && \
	sed -i 's/step_input:""/step_input:c.target.step/; s/ HH:MM/ HH:mm/; s/,function(c)/,"templateSrv",function(c,g)/; s/expr:c.target.expr/expr:g.replace(c.target.expr,c.panel.scopedVars)/' /usr/share/grafana/public/app/plugins/datasource/prometheus/query_ctrl.js && \
	sed -i 's/h=a.interval/h=g.replace(a.interval, c.scopedVars)/' /usr/share/grafana/public/app/plugins/datasource/prometheus/datasource.js && \
	/opt/add-grafana-datasource.sh

# ####################### #
# Percona Query Analytics #
# ####################### #

ADD https://www.percona.com/downloads/TESTING/ppl/open-source/ppl-datastore.tar.gz \
	https://www.percona.com/downloads/TESTING/ppl/open-source/ppl-qan-app.tar.gz /opt/
RUN mkdir qan-api && \
	tar zxf ppl-datastore.tar.gz --strip-components=1 -C qan-api && \
	mkdir qan-app && \
	tar zxf ppl-qan-app.tar.gz --strip-components=1 -C qan-app
COPY install-qan.sh /opt
RUN /opt/install-qan.sh

# ################ #
# prom-config-api  #
# ################ #

RUN git clone https://github.com/percona/prom-config-api.git && \
	cd prom-config-api && \
	mkdir /opt/gopath && \
	export GOPATH=/opt/gopath && \
	go get github.com/julienschmidt/httprouter && \
	go get github.com/percona/prom-config-api/prom && \
	go build -o prom-config-api main.go     

# ############################## #
# Run everything with supervisor #
# ############################## #

COPY supervisord.conf /etc/supervisor/conf.d/pmm.conf
CMD ["supervisord"]
