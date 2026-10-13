#!/bin/sh

echo "******************************************************************"
echo " HELIOS base"
echo " Created by Hidehisa Akiyama and Hiroki Shimora"
echo " Copyright 2000-2007.  Hidehisa Akiyama"
echo " Copyright 2007-2011.  Hidehisa Akiyama and Hiroki Shimora"
echo " "
echo " Gliders2d"
echo " Copyright 2018-2019.  Mikhail Prokopenko and Peter Wang"
echo " "
echo " Cyrus2D_base"
echo " Copyright 2021-2022.  Omid Amini and Nader Zare"
echo " All rights reserved."
echo "******************************************************************"


SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if [ X"${SCRIPT_DIR}" = X"" ]; then
  echo "failed to resolve script directory." 1>&2
  exit 1
fi

DIR="${SCRIPT_DIR}"
cd "${DIR}" || exit 1
PROJECT_ROOT=$(CDPATH= cd -- "${DIR}/../.." 2>/dev/null && pwd)
if [ X"${PROJECT_ROOT}" = X"" ]; then
  PROJECT_ROOT="${DIR}"
fi

export UNMARK_DNN_MODEL_PATH="./unmark_dnn_weights.txt"
export GNN_DECISION_MODEL_PATH="./gnn_decision_weights.txt"
export GNN_DECISION_FORCE_FALLBACK=0

auto_gnn_train="true"
gnn_train_epochs=8
gnn_train_max_samples=40000

# 强制使用球队自带的 librcsc 库
export LD_LIBRARY_PATH="./lib:$LD_LIBRARY_PATH"

player="./sample_player"
coach="./sample_coach"
teamname="white"
host="localhost"
port=6000
coach_port=""
debug_server_host=""
debug_server_port=""

find_bundled_runtime_archive()
{
  for candidate in \
      "${DIR}/../bin.tar.xz" \
      "${PROJECT_ROOT}/build/bin.tar.xz" \
      "${PROJECT_ROOT}/bin.tar.xz"
  do
    if [ -f "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

restore_bundled_runtime_archive()
{
  runtime_archive=$(find_bundled_runtime_archive 2>/dev/null)
  if [ X"${runtime_archive}" = X"" ]; then
    return 1
  fi

  if ! command -v tar >/dev/null 2>&1; then
    echo "[bootstrap] tar not found, cannot restore bundled runtime archive." 1>&2
    return 1
  fi

  echo "[bootstrap] restoring bundled runtime from ${runtime_archive}"
  if tar -xJf "${runtime_archive}" -C "${DIR}/.." \
      bin/lib \
      bin/sample_player \
      bin/sample_coach \
      bin/sample_trainer \
      bin/formations-dt \
      bin/formations-keeper \
      bin/formations-taker \
      bin/player.conf \
      bin/coach.conf \
      bin/unmark_dnn_weights.txt \
      bin/team_logo.xpm >/dev/null 2>&1; then
    chmod +x ./sample_player ./sample_coach ./sample_trainer 2>/dev/null || true
    return 0
  fi

  return 1
}

ensure_bundled_runtime_ready()
{
  missing_runtime=0

  if [ ! -f "./lib/librcsc.so" ] && [ ! -f "./lib/librcsc.so.19" ]; then
    missing_runtime=1
  fi

  if [ ! -r "${player}" ] || [ ! -r "${coach}" ]; then
    missing_runtime=1
  fi

  if [ ! -f "./formations-dt/before-kick-off.conf" ] \
     || [ ! -f "./formations-dt/normal-formation.conf" ] \
     || [ ! -f "./player.conf" ] \
     || [ ! -f "./coach.conf" ]; then
    missing_runtime=1
  fi

  if [ ${missing_runtime} -eq 1 ]; then
    restore_bundled_runtime_archive || true
  fi

  chmod +x "${player}" "${coach}" ./sample_trainer 2>/dev/null || true
}

find_elf_loader()
{
  for candidate in \
      "/lib64/ld-linux-x86-64.so.2" \
      "/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2"
  do
    if [ -x "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

ELF_LOADER=""

run_team_binary()
{
  binary_path="${1}"
  shift

  if [ -x "${binary_path}" ]; then
    "${binary_path}" "$@"
    return $?
  fi

  if [ X"${ELF_LOADER}" = X"" ]; then
    ELF_LOADER=$(find_elf_loader 2>/dev/null)
  fi

  if [ X"${ELF_LOADER}" != X"" ]; then
    "${ELF_LOADER}" --library-path "./lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" "${binary_path}" "$@"
    return $?
  fi

  echo "[bootstrap] cannot start ${binary_path}." 1>&2
  echo "[bootstrap] please ensure execute permission is available on Ubuntu." 1>&2
  return 1
}

run_player()
{
  run_team_binary "${player}" "$@"
}

run_coach()
{
  run_team_binary "${coach}" "$@"
}

ensure_bundled_runtime_ready

player_conf="./player.conf"
config_dir="./formations-dt"

coach_conf="./coach.conf"
team_graphic_file=""
team_graphic="--use_team_graphic off"

if [ -f "./team_logo.xpm" ]; then
  team_graphic_file="./team_logo.xpm"
else
  for xpm_file in ./*.xpm; do
    if [ -f "${xpm_file}" ]; then
      team_graphic_file="${xpm_file}"
      break
    fi
  done
fi

if [ X"${team_graphic_file}" != X"" ]; then
  team_graphic="--use_team_graphic on --team_graphic_file ${team_graphic_file}"
fi

number=11
usecoach="true"

unum=0

sleepprog=sleep
goaliesleep=1
sleeptime=0

debugopt=""
coachdebug=""

offline_logging=""
offline_mode=""
fullstateopt=""

usage()
{
  (echo "Usage: $0 [options]"
   echo "Available options:"
   echo "      --help                   prints this"
   echo "  -h, --host HOST              specifies server host (default: localhost)"
   echo "  -p, --port PORT              specifies server port (default: 6000)"
   echo "  -P  --coach-port PORT        specifies server port for online coach (default: 6002)"
   echo "  -t, --teamname TEAMNAME      specifies team name"
   echo "  -n, --number NUMBER          specifies the number of players"
   echo "  -u, --unum UNUM              specifies the uniform number of players"
   echo "  -C, --without-coach          specifies not to run the coach"
   echo "  -f, --formation DIR          specifies the formation directory"
   echo "  --team-graphic FILE          specifies the team graphic xpm file"
   echo "  --offline-logging            writes offline client log (default: off)"
   echo "  --offline-client-mode        starts as an offline client (default: off)"
   echo "  --debug                      writes debug log (default: off)"
   echo "  --debug_DEBUG_CATEGORY       writes DEBUG_CATEGORY to debug log"
   echo "  --debug-start-time TIME      the start time for recording debug log (default: -1)"
   echo "  --debug-end-time TIME        the end time for recording debug log (default: 99999999)"
   echo "  --debug-server-connect       connects to the debug server (default: off)"
   echo "  --debug-server-host HOST     specifies debug server host (default: localhost)"
   echo "  --debug-server-port PORT     specifies debug server port (default: 6032)"
   echo "  --debug-server-logging       writes debug server log (default: off)"
   echo "  --no-auto-gnn-train          disable pre-match gnn_decision model training"
   echo "  --gnn-train-epochs EPOCHS    set pre-match gnn training epochs (default: 8)"
   echo "  --gnn-train-max-samples NUM  set max samples for pre-match gnn training (default: 40000)"
   echo "  --log-dir DIRECTORY          specifies debug log directory (default: /tmp)"
   echo "  --debug-log-ext EXTENSION    specifies debug log file extension (default: .log)"
   echo "  --fullstate FULLSTATE_TYPE   specifies fullstate model handling"
   echo "                               FULLSTATE_TYPE is one of [ignore|reference|override].") 1>&2
}

while [ $# -gt 0 ]
do
  case $1 in

    --help)
      usage
      exit 0
      ;;

    -h|--host)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      host="${2}"
      shift 1
      ;;

    -p|--port)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      port="${2}"
      shift 1
      ;;

    -P|--coach-port)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      coach_port="${2}"
      shift 1
      ;;

    -t|--teamname)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      teamname="${2}"
      shift 1
      ;;

    -n|--number)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      number="${2}"
      shift 1
      ;;

    -u|--unum)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      unum="${2}"
      shift 1
      ;;

    -C|--without-coach)
      usecoach="false"
      ;;

    -f|--formation)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      config_dir="${2}"
      shift 1
      ;;

    --team-graphic)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      team_graphic_file="${2}"
      if [ ! -f "${team_graphic_file}" ]; then
        echo "team graphic file not found: ${team_graphic_file}" 1>&2
        exit 1
      fi
      team_graphic="--use_team_graphic on --team_graphic_file ${team_graphic_file}"
      shift 1
      ;;

    --offline-logging)
      offline_logging="--offline_logging"
      ;;

    --offline-client-mode)
      offline_mode="on"
      ;;

    --debug)
      debugopt="${debugopt} --debug"
      coachdebug="${coachdebug} --debug"
      ;;

    --debug_*)
      debug_opt="${debug_opt} ${1}"
      ;;

    --debug-start-time)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
	  debug_opt="${debug_opt} --debug_start_time ${2}"
	  shift 1
	  ;;

    --debug-end-time)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
	  debug_opt="${debug_opt} --debug_end_time ${2}"
	  shift 1
	  ;;

    --debug-server-connect)
      debugopt="${debugopt} --debug_server_connect"
      ;;

    --debug-server-host)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      debug_server_host="${2}"
      shift 1
      ;;

    --debug-server-port)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      debug_server_port="${2}"
      shift 1
      ;;

    --debug-server-logging)
      debugopt="${debugopt} --debug_server_logging"
      ;;

    --no-auto-gnn-train)
      auto_gnn_train="false"
      ;;

    --gnn-train-epochs)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      gnn_train_epochs="${2}"
      shift 1
      ;;

    --gnn-train-max-samples)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      gnn_train_max_samples="${2}"
      shift 1
      ;;

    --log-dir)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      debugopt="${debugopt} --log_dir ${2}"
      shift 1
      ;;

    --debug-log-ext)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      debugopt="${debugopt} --debug_log_ext ${2}"
      shift 1
      ;;

    --fullstate)
      if [ $# -lt 2 ]; then
        usage
        exit 1
      fi
      fullstate_type="${2}"
      shift 1

      case "${fullstate_type}" in
        ignore)
          fullstateopt="--use_fullstate false --debug_fullstate false"
          ;;

        reference)
          fullstateopt="--use_fullstate false --debug_fullstate true"
          ;;

        override)
          fullstateopt="--use_fullstate true --debug_fullstate true"
          ;;

        *)
          usage
          exit 1
          ;;
      esac
      ;;

    *)
      echo 1>&2
      echo "invalid option \"${1}\"." 1>&2
      echo 1>&2
      usage
      exit 1
      ;;
  esac

  shift 1
done

if  [ X"${offline_logging}" != X'' ]; then
  if  [ X"${offline_mode}" != X'' ]; then
    echo "'--offline-logging' and '--offline-mode' cannot be used simultaneously."
    exit 1
  fi
fi

if [ X"${coach_port}" = X'' ]; then
  coach_port=`expr ${port} + 2`
fi

if [ X"${debug_server_host}" = X'' ]; then
  debug_server_host="${host}"
fi

if [ X"${debug_server_port}" = X'' ]; then
  debug_server_port=`expr ${port} + 32`
fi

find_existing_gnn_runtime_model()
{
  for candidate in \
      "./gnn_decision_weights.txt" \
      "./ml/model/gnn_decision_weights.txt" \
      "../build/bin/gnn_decision_weights.txt" \
      "../build/bin/ml/model/gnn_decision_weights.txt" \
      "${PROJECT_ROOT}/build/bin/gnn_decision_weights.txt" \
      "${PROJECT_ROOT}/build/bin/ml/model/gnn_decision_weights.txt" \
      "./src/gnn_decision_weights.txt" \
      "../src/gnn_decision_weights.txt"
  do
    if [ -f "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

activate_existing_gnn_runtime_model()
{
  existing_gnn_model_path=$(find_existing_gnn_runtime_model 2>/dev/null)
  if [ X"${existing_gnn_model_path}" = X"" ]; then
    return 1
  fi

  export GNN_DECISION_MODEL_PATH="${existing_gnn_model_path}"
  export GNN_DECISION_FORCE_FALLBACK=0
  return 0
}

find_existing_ml_dir()
{
  for candidate in \
      "./ml" \
      "../ml" \
      "${PROJECT_ROOT}/build/bin/ml"
  do
    if [ -d "${candidate}" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

find_dataset_dir_with_ext()
{
  ext_pattern="${1}"
  shift

  for candidate in "$@"
  do
    if [ -d "${candidate}" ] \
       && [ X"$(find "${candidate}" -type f -iname "${ext_pattern}" -print -quit 2>/dev/null)" != X"" ]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done

  return 1
}

find_existing_csv_dataset_dir()
{
  find_dataset_dir_with_ext "*.csv" \
    "./competition_csv" \
    "../competition_csv" \
    "${PROJECT_ROOT}/build/bin/competition_csv" \
    "${PROJECT_ROOT}/competition_csv"
}

find_existing_rcg_dataset_dir()
{
  find_dataset_dir_with_ext "*.rcg" \
    "./competition_rcg" \
    "../competition_rcg" \
    "${PROJECT_ROOT}/build/bin/competition_rcg" \
    "${PROJECT_ROOT}/competition_rcg"
}

prepare_gnn_decision_model()
{
  export GNN_DECISION_FORCE_FALLBACK=0
  export GNN_DECISION_MODEL_PATH="./gnn_decision_weights.txt"
  ml_dir=$(find_existing_ml_dir 2>/dev/null)

  if [ X"${auto_gnn_train}" != X"true" ]; then
    if activate_existing_gnn_runtime_model; then
      echo "[GNN] auto training disabled. use existing runtime model: ${GNN_DECISION_MODEL_PATH}"
    else
      echo "[GNN] auto training disabled and no runtime model found. fallback to rules." 1>&2
      export GNN_DECISION_FORCE_FALLBACK=1
    fi
    return 0
  fi

  if [ X"${ml_dir}" = X"" ]; then
    if activate_existing_gnn_runtime_model; then
      echo "[GNN] ml directory not found. skip training and use existing runtime model: ${GNN_DECISION_MODEL_PATH}"
    else
      echo "[GNN] ml directory not found and no runtime model found. fallback to rules." 1>&2
      export GNN_DECISION_FORCE_FALLBACK=1
    fi
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    if activate_existing_gnn_runtime_model; then
      echo "[GNN] python3 not found. skip training and use existing runtime model: ${GNN_DECISION_MODEL_PATH}"
    else
      echo "[GNN] python3 not found. fallback to rules." 1>&2
      export GNN_DECISION_FORCE_FALLBACK=1
    fi
    return 0
  fi

  if ! python3 - <<'PY' >/dev/null 2>&1
import numpy
import torch
PY
  then
    if activate_existing_gnn_runtime_model; then
      echo "[GNN] numpy/torch not available. skip training and use existing runtime model: ${GNN_DECISION_MODEL_PATH}"
    else
      echo "[GNN] numpy/torch not available. fallback to rules." 1>&2
      export GNN_DECISION_FORCE_FALLBACK=1
    fi
    return 0
  fi

  if [ ! -f "${ml_dir}/train_gnn_decision.py" ]; then
    if activate_existing_gnn_runtime_model; then
      echo "[GNN] train_gnn_decision.py not found. skip training and use existing runtime model: ${GNN_DECISION_MODEL_PATH}"
    else
      echo "[GNN] train_gnn_decision.py not found. fallback to rules." 1>&2
      export GNN_DECISION_FORCE_FALLBACK=1
    fi
    return 0
  fi

  csv_dir=$(find_existing_csv_dataset_dir 2>/dev/null)

  if [ X"${csv_dir}" = X"" ] && [ -f "${ml_dir}/rcg.py" ]; then
    rcg_dir=$(find_existing_rcg_dataset_dir 2>/dev/null)
    if [ X"${rcg_dir}" != X"" ]; then
      echo "[GNN] no csv dataset found, generating csv from competition_rcg ..."
      if ! python3 "${ml_dir}/rcg.py" --input-dir "${rcg_dir}" --output-dir "./competition_csv" --all-teams; then
        if activate_existing_gnn_runtime_model; then
          echo "[GNN] rcg -> csv generation failed. keep existing runtime model: ${GNN_DECISION_MODEL_PATH}"
        else
          echo "[GNN] rcg -> csv generation failed. fallback to rules." 1>&2
          export GNN_DECISION_FORCE_FALLBACK=1
        fi
        return 0
      fi
      csv_dir="./competition_csv"
    fi
  fi

  if [ X"${csv_dir}" = X"" ]; then
    if activate_existing_gnn_runtime_model; then
      echo "[GNN] no csv dataset available for training. use existing runtime model: ${GNN_DECISION_MODEL_PATH}"
    else
      echo "[GNN] no csv dataset available for training. fallback to rules." 1>&2
      export GNN_DECISION_FORCE_FALLBACK=1
    fi
    return 0
  fi

  tmp_runtime_model="./gnn_decision_weights.txt.tmp.$$"
  tmp_mirror_model="./gnn_decision_weights.mirror.tmp.$$"
  mkdir -p "./ml/model"

  echo "[GNN] training gnn_decision runtime model from ${csv_dir} ..."
  if python3 "${ml_dir}/train_gnn_decision.py" \
      --csv-dir "${csv_dir}" \
      --output "${tmp_runtime_model}" \
      --mirror-output "${tmp_mirror_model}" \
      --epochs "${gnn_train_epochs}" \
      --max-samples "${gnn_train_max_samples}"; then
    if mv -f "${tmp_runtime_model}" ./gnn_decision_weights.txt \
      && mv -f "${tmp_mirror_model}" ./ml/model/gnn_decision_weights.txt; then
      export GNN_DECISION_MODEL_PATH="./gnn_decision_weights.txt"
      export GNN_DECISION_FORCE_FALLBACK=0
      echo "[GNN] runtime model ready: ${GNN_DECISION_MODEL_PATH}"
    else
      rm -f "${tmp_runtime_model}" "${tmp_mirror_model}"
      if activate_existing_gnn_runtime_model; then
        echo "[GNN] trained model finalize failed. keep existing runtime model: ${GNN_DECISION_MODEL_PATH}"
      else
        echo "[GNN] trained model finalize failed. fallback to rules." 1>&2
        export GNN_DECISION_FORCE_FALLBACK=1
      fi
    fi
  else
    rm -f "${tmp_runtime_model}" "${tmp_mirror_model}"
    if activate_existing_gnn_runtime_model; then
      echo "[GNN] training failed. keep existing runtime model: ${GNN_DECISION_MODEL_PATH}"
    else
      echo "[GNN] training failed. fallback to rules." 1>&2
      export GNN_DECISION_FORCE_FALLBACK=1
    fi
  fi

  return 0
}

prepare_gnn_decision_model

opt="--player-config ${player_conf} --config_dir ${config_dir}"
opt="${opt} -h ${host} -p ${port} -t ${teamname}"
opt="${opt} ${fullstateopt}"
opt="${opt} --debug_server_host ${debug_server_host}"
opt="${opt} --debug_server_port ${debug_server_port}"
opt="${opt} ${offline_logging}"
opt="${opt} ${debugopt}"

ping -c 1 $host

if [ $number -gt 0 ]; then
  offline_number=""
  if  [ X"${offline_mode}" != X'' ]; then
    offline_number="--offline_client_number 1"
    if [ $unum -eq 0 ]; then
      run_player ${opt} -g ${offline_number} &
      $sleepprog $goaliesleep
    elif [ $unum -eq 1 ]; then
      run_player ${opt} -g ${offline_number} &
      $sleepprog $goaliesleep
    fi
  else
    run_player ${opt} -g &
    $sleepprog $goaliesleep
  fi
fi

i=2
while [ $i -le ${number} ] ; do
  offline_number=""
  if  [ X"${offline_mode}" != X'' ]; then
    offline_number="--offline_client_number ${i}"
    if [ $unum -eq 0 ]; then
      run_player ${opt} ${offline_number} &
      $sleepprog $sleeptime
    elif [ $unum -eq $i ]; then
      run_player ${opt} ${offline_number} &
      $sleepprog $sleeptime
    fi
  else
    run_player ${opt} &
    $sleepprog $sleeptime
  fi

  i=`expr $i + 1`
done

if [ "${usecoach}" = "true" ]; then
  coachopt="--coach-config ${coach_conf}"
  coachopt="${coachopt} -h ${host} -p ${coach_port} -t ${teamname}"
  coachopt="${coachopt} ${team_graphic}"
  coachopt="${coachopt} --debug_server_host ${debug_server_host}"
  coachopt="${coachopt} --debug_server_port ${debug_server_port}"
  coachopt="${coachopt} ${offline_logging}"
  coachopt="${coachopt} ${debugopt}"


  if  [ X"${offline_mode}" != X'' ]; then
    offline_mode="--offline_client_mode"
    if [ $unum -eq 0 ]; then
      run_coach ${coachopt} ${offline_mode} &
    elif [ $unum -eq 12 ]; then
      run_coach ${coachopt} ${offline_mode} &
    fi
  else
    run_coach ${coachopt} &
  fi
fi
