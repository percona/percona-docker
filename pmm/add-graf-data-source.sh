#!/bin/sh

for i in `seq 30`; do
	if curl -s http://admin:admin@localhost:3000/api/datasources; then
		curl http://admin:admin@localhost:3000/api/datasources -X POST -H 'Content-Type: application/json' --data-binary '{"name":"Prometheus","type":"prometheus","url":"http://localhost:9090","access":"proxy","isDefault":true}'

		sed -i 's/step_input:""/step_input:c.target.step/; s/ HH:MM/ HH:mm/; s/,function(c)/,"templateSrv",function(c,g)/; s/expr:c.target.expr/expr:g.replace(c.target.expr,c.panel.scopedVars)/' /usr/share/grafana/public/app/plugins/datasource/prometheus/query_ctrl.js

		sed -i 's/h=a.interval/h=g.replace(a.interval, c.scopedVars)/' /usr/share/grafana/public/app/plugins/datasource/prometheus/datasource.js

		echo "Added Prometheus data source to Grafana"
		break
	else
		echo "Waiting for Grafana..."
		sleep 1
	fi
done
