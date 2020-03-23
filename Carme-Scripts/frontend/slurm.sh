#!/bin/bash
# ----------------------------------------------------------------------------------------------------------------------------------
# Carme
# ----------------------------------------------------------------------------------------------------------------------------------
# slurm.sh
#
# see Carme development guide for documentation:
# * Carme/Carme-Doc/DevelDoc/CarmeDevelopmentDocu.md
# * Carme/Carme-Doc/DevelDoc/BackendDocu.md
#
# Copyright 2019 by Fraunhofer ITWM
# License: http://open-carme.org/LICENSE.md
# Contact: info@open-carme.org
# ----------------------------------------------------------------------------------------------------------------------------------


#bash set buildins -----------------------------------------------------------------------------------------------------------------
set -e
set -o pipefail
#-----------------------------------------------------------------------------------------------------------------------------------


# define function to print time and date -------------------------------------------------------------------------------------------
function currenttime () {
  date +"[%F %T.%3N]"
}
#-----------------------------------------------------------------------------------------------------------------------------------


# define function die that is called if a command fails ----------------------------------------------------------------------------
function die () {
  echo "$(currenttime) $(hostname): ERROR: ${1}"
  exit 200
}
#-----------------------------------------------------------------------------------------------------------------------------------


# external variables ---------------------------------------------------------------------------------------------------------------
IMAGE=$1
[[ -z ${IMAGE} ]] && die "no singularity image defined"

MOUNTSTR=$2
[[ -z ${MOUNTSTR} ]] && die "no mounts defined"
#-----------------------------------------------------------------------------------------------------------------------------------


# check if this is not the first slurm task on a node ------------------------------------------------------------------------------
[[ "${SLURM_LOCALID}" != "0" ]] && exit 0
#-----------------------------------------------------------------------------------------------------------------------------------


# define function for regular node output ------------------------------------------------------------------------------------------
function log () {
  echo "$(currenttime) $(hostname): ${1}"
}
#-----------------------------------------------------------------------------------------------------------------------------------


#source job bashrc -----------------------------------------------------------------------------------------------------------------
source "${HOME}/.local/share/carme/job/${SLURM_JOB_ID}/bashrc" || die "cannot source job bashrc"
#-----------------------------------------------------------------------------------------------------------------------------------


#compute ports: base port + first GPU id -------------------------------------------------------------------------------------------
JOB_OFFSET=$(echo -n "$SLURM_JOB_ID" | tail -c 3)
PORT_OFFSET="1000"

NB_PORT=$((6000 + 10#$JOB_OFFSET))
TB_PORT=$((NB_PORT + PORT_OFFSET))
TA_PORT=$((NB_PORT + PORT_OFFSET + PORT_OFFSET))

LISTEN_NB=$(ss -tln -4 | grep ${NB_PORT})
LISTEN_TB=$(ss -tln -4 | grep ${TB_PORT})
LISTEN_TA=$(ss -tln -4 | grep ${TA_PORT})

if [[ -n "${LISTEN_NB}" || -n "${LISTEN_TB}" || -n "${LISTEN_TA}" ]];then
  echo "ERROR: No free port for entrypoints found!"
  echo "NB_PORT: ${NB_PORT}"
  echo "TB_PORT: ${TB_PORT}"
  echo "TA_PORT: ${TA_PORT}"
  exit 137
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# things that should only be done on master node -----------------------------------------------------------------------------------
if [[ "$(hostname)" == "${CARME_MASTER}" ]];then

  # check if hash is set
  [[ -z ${CARME_HASH} ]] && die "hash not set"


  # check if IP is set
  [[ -z ${CARME_MASTER_IP} ]] && die "master ip not set"


  # get start- and estimated end-time
  STARTTIME=$(squeue -h -j "${SLURM_JOB_ID}" -o "%.20S")
  ENDTIME=$(squeue -h -j "${SLURM_JOB_ID}" -o "%.20e")


  # write debug to logfile
  log "carme version: ${CARME_VERSION}"
  log "job id: ${SLURM_JOB_ID}"
  log "job name: ${SLURM_JOB_NAME}"
  log "nodelist: ${CARME_NODES}"
  log "start-time: ${STARTTIME}"
  log "end-time:   ${ENDTIME} (estimated)"
  log "hash: ${CARME_HASH}"
  log "master ip: ${CARME_MASTER_IP}"
  log "image: ${IMAGE}"
  log "mount points: ${MOUNTSTR}"


  # add job to global job-log-file
  [[ -z ${CARME_LOGDIR} ]] && die "CARME_LOGDIR not set"
  echo -e "${SLURM_JOB_ID}\t${SLURM_JOB_NAME}\t$(hostname)\t${CARME_NODES}\t${STARTTIME}\t${ENDTIME}" >> "${CARME_LOGDIR}/job-log.dat"
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# check GPU stuff if job has gpus---------------------------------------------------------------------------------------------------
if [[ -n "${SLURM_JOB_GPUS}" ]];then
  log "number of gpus: $(echo "${SLURM_JOB_GPUS}" | tr ',' '\n' | wc -l)"
  log "gpu devices: ${SLURM_JOB_GPUS}"

  mapfile -t GPU_TYPES < <(nvidia-smi --query-gpu=index,gpu_name --format=csv,noheader | awk -F', ' '{ print "GPU"$1": " $2 }')

  for GPU_TYPE in "${GPU_TYPES[@]}"; do
    log "${GPU_TYPE}"
  done
fi
#-----------------------------------------------------------------------------------------------------------------------------------


# write node specific env variables to file so that they can be made available via ssh ---------------------------------------------
if [[ "${CARME_START_SSHD}" == "always" || ("${CARME_START_SSHD}" == "multi" && "${NUMBER_OF_NODES}" -gt "1") ]];then

  [[ -z ${CARME_SSHDIR} ]] && die "CARME_SSHDIR not set"

  log "create ssh env file ${CARME_SSHDIR}/envs/$(hostname)"
  echo "#!/bin/bash
export SLURM_CHECKPOINT_IMAGE_DIR=\"${SLURM_CHECKPOINT_IMAGE_DIR}\"
export SLURM_CLUSTER_NAME=\"${SLURM_CLUSTER_NAME}\"
export SLURM_CPUS_ON_NODE=\"${SLURM_CPUS_ON_NODE}\"
export SLURM_CPUS_PER_TASK=\"${SLURM_CPUS_PER_TASK}\"
export SLURM_DISTRIBUTION=\"${SLURM_DISTRIBUTION}\"
export SLURMD_NODENAME=\"${SLURMD_NODENAME}\"
export SLURM_GTIDS=\"${SLURM_GTIDS}\"
export SLURM_JOB_ACCOUNT=\"${SLURM_JOB_ACCOUNT}\"
export SLURM_JOB_CPUS_PER_NODE=\"${SLURM_JOB_CPUS_PER_NODE}\"
export SLURM_JOB_GID=\"${SLURM_JOB_GID}\"
export SLURM_JOB_GPUS=\"${SLURM_JOB_GPUS}\"
export SLURM_JOB_ID=\"${SLURM_JOB_ID}\"
export SLURM_JOBID=\"${SLURM_JOBID}\"
export SLURM_JOB_NAME=\"${SLURM_JOB_NAME}\"
export SLURM_JOB_NODELIST=\"${SLURM_JOB_NODELIST}\"
export SLURM_JOB_NUM_NODES=\"${SLURM_JOB_NUM_NODES}\"
export SLURM_JOB_PARTITION=\"${SLURM_JOB_PARTITION}\"
export SLURM_JOB_QOS=\"${SLURM_JOB_QOS}\"
export SLURM_JOB_UID=\"${SLURM_JOB_UID}\"
export SLURM_JOB_USER=\"${SLURM_JOB_USER}\"
export SLURM_LAUNCH_NODE_IPADDR=\"${SLURM_LAUNCH_NODE_IPADDR}\"
export SLURM_LOCALID=\"${SLURM_LOCALID}\"
export SLURM_MEM_PER_NODE=\"${SLURM_MEM_PER_NODE}\"
export SLURM_NNODES=\"${SLURM_NNODES}\"
export SLURM_NODEID=\"${SLURM_NODEID}\"
export SLURM_NODELIST=\"${SLURM_NODELIST}\"
export SLURM_NPROCS=\"${SLURM_NPROCS}\"
export SLURM_NTASKS=\"${SLURM_NTASKS}\"
export SLURM_NTASKS_PER_NODE=\"${SLURM_NTASKS_PER_NODE}\"
export SLURM_PRIO_PROCESS=\"${SLURM_PRIO_PROCESS}\"
export SLURM_PROCID=\"${SLURM_PROCID}\"
export SLURM_SRUN_COMM_HOST=\"${SLURM_SRUN_COMM_HOST}\"
export SLURM_SRUN_COMM_PORT=\"${SLURM_SRUN_COMM_PORT}\"
export SLURM_STEP_GPUS=\"${SLURM_STEP_GPUS}\"
export SLURM_STEP_ID=\"${SLURM_STEP_ID}\"
export SLURM_STEPID=\"${SLURM_STEPID}\"
export SLURM_STEP_LAUNCHER_PORT=\"${SLURM_STEP_LAUNCHER_PORT}\"
export SLURM_STEP_NODELIST=\"${SLURM_STEP_NODELIST}\"
export SLURM_STEP_NUM_NODES=\"${SLURM_STEP_NUM_NODES}\"
export SLURM_STEP_NUM_TASKS=\"${SLURM_STEP_NUM_TASKS}\"
export SLURM_STEP_TASKS_PER_NODE=\"${SLURM_STEP_TASKS_PER_NODE}\"
export SLURM_SUBMIT_DIR=\"${SLURM_SUBMIT_DIR}\"
export SLURM_SUBMIT_HOST=\"${SLURM_SUBMIT_HOST}\"
export SLURM_TASK_PID=\"${SLURM_TASK_PID}\"
export SLURM_TASKS_PER_NODE=\"${SLURM_TASKS_PER_NODE}\"
export SLURM_TOPOLOGY_ADDR=\"${SLURM_TOPOLOGY_ADDR}\"
export SLURM_TOPOLOGY_ADDR_PATTERN=\"${SLURM_TOPOLOGY_ADDR_PATTERN}\"
export SLURM_UMASK=\"${SLURM_UMASK}\"
export SLURM_WORKING_CLUSTER=\"${SLURM_WORKING_CLUSTER}\"
export CUDA_VISIBLE_DEVICES=\"${CUDA_VISIBLE_DEVICES}\"
export GPU_DEVICE_ORDINAL=\"${GPU_DEVICE_ORDINAL}\"" > "${CARME_SSHDIR}/envs/$(hostname)"

fi
#-----------------------------------------------------------------------------------------------------------------------------------


#change dir to user home -----------------------------------------------------------------------------------------------------------
cd "${HOME}" || die "cannot change directory to ${HOME}"
#-----------------------------------------------------------------------------------------------------------------------------------


#start singularity -----------------------------------------------------------------------------------------------------------------
export XDG_RUNTIME_DIR=""
if [[ ${IMAGE} = *"scratch_image_build"* ]];then #sandbox image - add own start script
  echo "Sandox Mode" ${IMAGE} ${MOUNTS}
  newpid sudo singularity exec -B /etc/libibverbs.d ${MOUNTS} --writable ${IMAGE} /bin/bash /home/.CarmeScripts/start_build_job.sh ${IPADDR} ${NB_PORT} ${TB_PORT} ${TA_PORT} ${USER} ${HASH} ${GPU_DEVICES}
else
		if [ ${IPADDR} != "${CARME_BUILDNODE_1_IP}" ];then
    newpid singularity exec --nv -B /opt/Carme/Carme-Scripts/InsideContainer/base_bashrc.sh:/etc/bash.bashrc -B /etc/libibverbs.d ${MOUNTS} -B /scratch_local/${SLURM_JOB_ID}:/home/SSD ${IMAGE} /bin/bash /home/.CarmeScripts/start_master.sh ${IPADDR} ${NB_PORT} ${TB_PORT} ${TA_PORT} ${USER} ${HASH} ${GPU_DEVICES} ${MEM} ${GPUS}
		else
		  newpid singularity exec --nv -B /opt/Carme/Carme-Scripts/InsideContainer/base_bashrc.sh:/etc/bash.bashrc -B /etc/libibverbs.d ${MOUNTS} ${IMAGE} /bin/bash /home/.CarmeScripts/start_master.sh ${IPADDR} ${NB_PORT} ${TB_PORT} ${TA_PORT} ${USER} ${HASH} ${GPU_DEVICES} ${MEM} ${GPUS}
		fi
fi

log "start container"
newpid singularity exec --nv -B /opt/Carme/Carme-Scripts/InsideContainer/base_bashrc.sh:/etc/bash.bashrc -B /etc/libibverbs.d ${MOUNTS} "${IMAGE}" /bin/bash /home/.CarmeScripts/start_apps.sh
#-----------------------------------------------------------------------------------------------------------------------------------
