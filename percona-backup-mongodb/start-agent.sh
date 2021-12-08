#!/bin/bash

for argv; do
	if [[ -n "$usenext" ]]; then
		export PBM_MONGODB_URI="${argv}"
		break
	fi
	if [[ "$argv" == '--mongodb-uri' ]]; then
		use_next='true'
		# TODO should we check if last?
		continue
	elif [[ "$argv" == '--mongodb-uri='* ]]; then
		export PBM_MONGODB_URI="${argv#--mongodb-uri=}"
		break
	fi
done

# TODO should we check if all parts are set?
set +o xtrace
[[ -z "$PBM_MONGODB_URI" ]] && export PBM_MONGODB_URI="mongodb://${PBM_AGENT_MONGODB_USERNAME}:${PBM_AGENT_MONGODB_PASSWORD}@localhost:${PBM_MONGODB_PORT}/?replicaSet=${PBM_MONGODB_REPLSET}"
set -o xtrace

if [ "${1:0:9}" = "pbm-agent" ]; then
	OUT="$(mktemp)"
	OUT_CFG="$(mktemp)"
	timeout=5
	for i in {1..10}; do
		if [ "${SHARDED}" ]; then
			echo "waiting for sharded scluster"

			# check in case if shard has role 'shardsrv'
			set +o xtrace
			mongo "${PBM_MONGODB_URI}" --eval="db.isMaster().\$configServerState.opTime.ts" --quiet | tee "$OUT"
			set -o xtrace
			exit_status=$?

			# check in case if shard has role 'configsrv'
			set +o xtrace
			mongo "${PBM_MONGODB_URI}" --eval="db.isMaster().configsvr" --quiet | tail -n 1 | tee "$OUT_CFG"
			set -o xtrace
			exit_status_cfg=$?

			ts=$(grep -E '^Timestamp\([0-9]+, [0-9]+\)$' "$OUT")
			isCfg=$(grep -E '^2$' "$OUT_CFG")

			if [[ "${exit_status}" == 0 && "${ts}" ]] || [[ "${exit_status_cfg}" == 0 && "${isCfg}" ]]; then
				break
			else
				sleep "$((timeout * i))"
			fi
		else
			set +o xtrace
			mongo "${PBM_MONGODB_URI}" --eval="(db.isMaster().hosts).length" --quiet | tee "$OUT"
			set -o xtrace
			exit_status=$?
			rs_size=$(grep -E '^([0-9]+)$' "$OUT")
			if [[ "${exit_status}" == 0 ]] && [[ $rs_size -ge 1 ]]; then
				break
			else
				sleep "$((timeout * i))"
			fi
		fi
	done

	rm "$OUT"
fi

exec "$@"
