#!/usr/bin/env bash
###############################################################################
# entrypoint.sh
#
# docker jupyter
#
# entrypoint script for jupyter docker image. it starts jupyter-lab by
# default.
#
###############################################################################

set -e

DAEMON=jupyter-lab

# APT Proxy Cache
if [ -n "${APT_PROXY}" ]; then
	echo "> Setting apt proxy 📌"
	echo "Acquire::http { Proxy \"${APT_PROXY}\"; }" |
		sudo tee /etc/apt/apt.conf.d/01proxy
fi

# dotfiles
if [ -d "$BYODF" ]; then
	echo "> setting dotfiles 📌 at $BYODF"
	stow --adopt -t "$HOME" -d "$(dirname "$BYODF")" "$(basename "$BYODF")"
	git -C "$BYODF" reset --hard 1>/dev/null
fi

# ssh keys
if [ -d "${SSH_KEYDIR}" ]; then
	if [ ! -L /home/"${USER}"/.ssh ]; then
		echo "> Setting SSH key 🔑 at $SSH_KEYDIR"
		ln -s "${SSH_KEYDIR}" /home/"${USER}"/.ssh
	else
		echo "> Setting SSH key 🔑: keys already exists /home/${USER}/.ssh"
	fi
fi

# jupyterlab-lsp
JUPYTER_OPT='--ContentsManager.allow_hidden=True'

# language server symlink
if [ ! -L "${JUPYTER_SERVER_ROOT}"/.lsp_symlink ]; then
	ln -s / .lsp_symlink
fi

start_scripts() {
	if [ ! -d "$START_SCRIPTS" ]; then
		echo "> No start scripts defined."
		return 0
	fi
	echo "> Running start up scripts."

	for f in "${START_SCRIPTS}"/*.sh; do
		echo "> Running $f"
		bash "$f"
	done

}

stop() {
	echo "> 😘 Received SIGINT or SIGTERM. Shutting down $DAEMON"
	# Get PID
	local pid
	pid=$(cat /tmp/$DAEMON.pid)
	# Set TERM
	kill -SIGTERM "${pid}"
	# Wait for exit
	wait "${pid}"
	# All done.
	echo "> Done... $?"
}

# Detect if running under JupyterHub
is_jupyterhub() {
	[ -n "${JUPYTERHUB_API_TOKEN}" ] || [ -n "${JUPYTERHUB_BASE_URL}" ]
}

echo "> Running Jupyter 🐍"
echo "> Running as $(id)"
echo "> Parameters: $*"
echo "> Jupyter options: $JUPYTER_OPT"
if is_jupyterhub; then
	echo "> Detected JupyterHub environment"
fi

if [ "$(basename "$1" 2>/dev/null)" == "jupyterhub-singleuser" ]; then
	# Running as jupyterhub-singleuser (JupyterHub/Kubernetes)
	echo "> Starting $* $JUPYTER_OPT"
	trap stop SIGINT SIGTERM
	start_scripts
	exec "$@" "${JUPYTER_OPT}"

elif [ "$(basename "$1" 2>/dev/null)" == "$DAEMON" ]; then
	echo "> Starting $* $JUPYTER_OPT"
	trap stop SIGINT SIGTERM
	start_scripts
	"$@" "${JUPYTER_OPT}" &
	pid="$!"
	echo $pid >/tmp/$DAEMON.pid
	echo "> $DAEMON pid: $pid"
	wait "${pid}"
	exit $?

elif echo "$*" | grep ^--; then
	# accept parameters from command line or compose
	echo "> Starting $* $JUPYTER_OPT"
	trap stop SIGINT SIGTERM
	start_scripts
	jupyter-lab --no-browser --ip=0.0.0.0 "${JUPYTER_OPT}" "$@" &
	pid="$!"
	echo "$pid" >/tmp/"$DAEMON".pid
	echo "> $DAEMON pid: $pid"
	wait "${pid}"
	exit $?
else
	# run command from docker run
	echo "> Starting $* "
	exec "$@"
fi
