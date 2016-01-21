FROM ubuntu:latest

EXPOSE 3000 8000 9001 9090

RUN apt-get -y update && apt-get install -y curl apt-transport-https mysql-server python

RUN echo "deb https://packagecloud.io/grafana/stable/debian/ wheezy main" > /etc/apt/sources.list.d/grafana.list \
	&& curl https://packagecloud.io/gpg.key | apt-key add - \
	&& apt-get -y update \
	&& apt-get -y install grafana

ADD https://github.com/prometheus/prometheus/releases/download/0.16.2/prometheus-0.16.2.linux-amd64.tar.gz /root/

COPY grafana.ini /etc/grafana/grafana.ini

COPY grafana-dashboards/* /var/lib/grafana/dashboards/

COPY prometheus.yml prometheus-datasource.json start.sh /root/

CMD ["/root/start.sh"]
