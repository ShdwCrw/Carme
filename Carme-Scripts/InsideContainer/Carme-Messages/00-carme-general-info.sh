#!/bin/bash

# carme banner
echo -e "\033[1mWelcome to -----------------------------------\033[0m"
echo -e "\033[1m _____   ___   _____  __  __  ____ \033[0m"
echo -e "\033[1m/  __ \ / _ \ | ___ \|  \/  ||  __|\033[0m"
echo -e "\033[1m| /  \// /_\ \| |_/ /|      || |__ \033[0m"
echo -e "\033[1m| |    |  _  ||    / | |\/| ||  __|\033[0m"
echo -e "\033[1m| \__/\| | | || |\ \ | |  | || |___\033[0m"
echo -e "\033[1m \____/\_| |_/\_| \_|\_|  |_/\____/\033[0m"
echo ""

# link to documentation
echo -e "\033[1mDocumentation --------------------------------\033[0m"
echo "https://carmeteam.github.io/Carme-Docu/UserDoc"
echo ""

# print job information
echo -e "\033[1mJob Information ------------------------------\033[0m"
echo "Job-ID|-Name: ${SLURM_JOB_ID} | ${SLURM_JOB_NAME}"
echo "Nodes:        ${CARME_NODES}"
if [[ -n "${CARME_GPUS_PER_NODE}" ]];then
  echo "GPUs/Node:    ${CARME_GPUS_PER_NODE}"
fi
if [[ -n "${CARME_GPU_LIST}" ]];then
  echo "GPU-ID(s):    ${CARME_GPU_LIST}"
fi
echo "End-Time:   $(grep "^${CARME_JOBID}[[:space:]]${CARME_JOB_NAME}" .local/share/carme/job-log-dir/job-log.dat | awk '{print $6}')"
echo ""

# print base ennv information
STOREDIR="${HOME}/.local/share/carme/tmp-files-${SLURM_JOB_ID}"

TF_VERSION="$(grep "^tensorflow-gpu " "${STOREDIR}/conda_base.txt" | awk '{ print $2 }')"
PT_VERSION="$(grep "^pytorch " "${STOREDIR}/conda_base.txt" | awk '{ print $2 }')"

if [[ -n "${TF_VERSION}" || -n "${PT_VERSION}" ]];then
  if [[ -f "${STOREDIR}/conda_base.txt" ]];then
    echo -e "\033[1mBase Environment -----------------------------\033[0m"
    if [[ -n "${TF_VERSION}" ]];then
      echo "TensorFlow: ${TF_VERSION}"
    fi
    if [[ -n "${PT_VERSION}" ]];then
      echo "PyTorch:    ${PT_VERSION}"
    fi
    echo ""
  fi
fi

