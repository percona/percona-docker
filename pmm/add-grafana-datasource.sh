#!/bin/sh

service grafana-server start

for i in `seq 30`; do
	if curl -s http://admin:admin@localhost:3000/api/datasources; then
		curl http://admin:admin@localhost:3000/api/datasources -X POST -H 'Content-Type: application/json' --data-binary '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"proxy","isDefault":true}'
		echo "Added Prometheus data source to Grafana"
		break
	else
		echo "Waiting for Grafana..."
		sleep 1
	fi
done
