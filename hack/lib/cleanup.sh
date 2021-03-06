#!/bin/bash

# This library holds functions that are used to clean up local
# system state after other scripts have run.

# os::cleanup::dump_etcd dumps the full contents of etcd to a file.
#
# Globals:
#  ARTIFACT_DIR
# Arguments:
#  None
# Returns:
#  None
function os::cleanup::dump_etcd() {
	os::log::info "Dumping etcd contents to ${ARTIFACT_DIR}/etcd_dump.json"
	os::util::curl_etcd "/v2/keys/?recursive=true" > "${ARTIFACT_DIR}/etcd_dump.json"
}

# os::cleanup::containers operates on k8s containers to stop the containers
# and optionally remove the containers and any volumes they had attached.
#
# Globals:
#  - SKIP_IMAGE_CLEANUP
# Arguments:
#  None
# Returns:
#  None
function os::cleanup::containers() {
	if ! os::util::find::system_binary docker >/dev/null 2>&1; then
		os::log::warning "No \`docker\` binary found, skipping container cleanup."
		return
	fi

	os::log::info "Stopping k8s docker containers"
	for id in $( os::cleanup::internal::list_k8s_containers ); do
		os::log::debug "Stopping ${id}"
		docker stop "${id}" >/dev/null
	done

	if [[ -n "${SKIP_IMAGE_CLEANUP:-}" ]]; then
		return
	fi

	os::log::info "Removing k8s docker containers"
	for id in $( os::cleanup::internal::list_k8s_containers ); do
		os::log::debug "Removing ${id}"
		docker stop "${id}" >/dev/null
	done
}
readonly -f os::cleanup::containers

# os::cleanup::dump_container_logs operates on k8s containers to dump any logs
# from the containers.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:
#  None
function os::cleanup::dump_container_logs() {
	if ! os::util::find::system_binary docker >/dev/null 2>&1; then
		os::log::warning "No \`docker\` binary found, skipping container cleanup."
		return
	fi

	local container_log_dir="${LOG_DIR}/containers"
	mkdir -p "${container_log_dir}"

	os::log::info "Dumping container logs to ${container_log_dir}"
	for id in $( os::cleanup::internal::list_k8s_containers ); do
		local name; name="$( docker inspect --format '{{ .Name }}' "${id}" )"
		os::log::debug "Dumping logs for ${id} to ${name}.log"
		docker logs "${id}" >"${container_log_dir}/${name}.log" 2>&1
	done
}
readonly -f os::cleanup::dump_container_logs



# os::cleanup::internal::list_k8s_containers returns a space-delimited list of
# docker containers that belonged to k8s.
#
# Globals:
#  None
# Arguments:
#  None
# Returns:
#  None
function os::cleanup::internal::list_k8s_containers() {
	local ids;
	for short_id in $( docker ps -aq ); do
		local id; id="$( docker inspect --format '{{ .Id }}' "${short_id}" )"
		local name; name="$( docker inspect --format '{{ .Name }}' "${id}" )"
		if [[ "${name}" =~ ^/k8s_.* ]]; then
			ids+=( "${id}" )
		fi
	done

	echo "${ids[*]:+"${ids[*]}"}"
}
readonly -f os::cleanup::internal::list_k8s_containers