#!/bin/bash

function set_trap_err {
  # Let's propagate traps to all functions
  set -E

  # Let's call trap_error if we catch an ERR
  trap 'trap_error' ERR
}

NOTRAP=
function trap_error {
  set +x
  declare -F err_cleanup && err_cleanup
  if [ -z "$NOTRAP" ]; then
    echo "An issue occured and you asked me to stay alive."
    echo "You can connect to me with: sudo docker exec -i -t $HOSTNAME /bin/bash"
    echo "The current environment variables will be reloaded by this bash to be in a similar context."
    echo "When debugging is over stop me with: pkill sleep"
    echo "I'll sleep for 365 days waiting for you darling, bye bye"

    # exporting current environement so the next bash will be in the same setup
    env | while IFS= read -r value; do
      echo "export $value" >> /root/.bashrc
    done

    sleep 365d
  else
    # If NOTRAP is defined, we need to return true to avoid triggering an ERR
    true
  fi
}

child_for_exec=1
function _term {
  echo "Sending SIGTERM to PID $child_for_exec"

  # Disabling the ERR trap before killing the process
  # That's an expected failure so don't handle it
  # Doing "trap ERR" or "trap - ERR" didn't worked :/
  NOTRAP="yes"
  declare -F sigterm_cleanup_pre && sigterm_cleanup_pre
  kill -TERM "$child_for_exec" 2>/dev/null
  declare -F sigterm_cleanup_post && sigterm_cleanup_post
}

function exec {
  # This function overrides the built-in exec() call
  # It starts the process in background to catch ERR but
  # as per docker requirement, forward the SIGTERM to it.
  trap _term SIGTERM

  "$@" &
  child_for_exec=$!
  echo "exec: PID $child_for_exec: spawning $*"
  wait "$child_for_exec"
  return_code=$?
  echo "exec: PID $child_for_exec: exit $return_code"
  # If needed, it's possible to execute some user defined code if the exec'd process fails
  if [ "$return_code" -ne 0 ]; then
    declare -F trap_exec_failure && trap_exec_failure
  fi
  exit $return_code
}
