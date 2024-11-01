#!/bin/bash

# set -x

HOMEDIR_GIT=/home/erik/adelerhof.eu

APPF_REPO_LIST='git@github.com:ckabalan/visualsubnetcalc.git'

function checkout_code {

[ -d $HOMEDIR_GIT ] || /bin/mkdir -p $HOMEDIR_GIT
pushd ${HOMEDIR_GIT}
# Loop over the repos of appfactory
for I in ${APPF_REPO_LIST}
do
	# Determine the directory of the cloned repo
	DIR=$(echo $I |cut -d\/ -f 2- | sed 's/.git$//')
	echo "${I} ${DIR}"

	# Check or the directory exists and is not a sybolic link
	if [ -d ${DIR} -a  ! -h ${DIR} ]
	then
		# Update the contect of the directory
		pushd ${DIR}
		git checkout ${ENVIRONMENT}
		git pull
		git submodule sync --recursive
		git submodule foreach git checkout master
		git submodule foreach git pull origin master
		popd
	else
		# Delete the symbolid link (when it's there) and make a fresh clone
	    rm -f ${DIR}
		git clone --recursive $I
	fi
	echo
done
popd
}

function build_image {

  TAG=$(date +%Y%m%d%H%M%S)
  # Build the Docker image date
  docker build . --file Dockerfile --tag ghcr.io/adelerhof/subnetcalc-${ENVIRONMENT}:${TAG}
  docker build . --file Dockerfile --tag ghcr.io/adelerhof/subnetcalc-${ENVIRONMENT}:latest
  docker build . --file Dockerfile --tag harbor.adelerhof.eu/subnetcalc/subnetcalc-${ENVIRONMENT}:${TAG}
  docker build . --file Dockerfile --tag harbor.adelerhof.eu/subnetcalc/subnetcalc-${ENVIRONMENT}:latest

}

function push_image {

  # Push the Docker image date
  docker push ghcr.io/adelerhof/subnetcalc-${ENVIRONMENT}:${TAG}
  docker push ghcr.io/adelerhof/subnetcalc-${ENVIRONMENT}:latest
  docker push harbor.adelerhof.eu/subnetcalc/subnetcalc-${ENVIRONMENT}:${TAG}
  docker push harbor.adelerhof.eu/subnetcalc/subnetcalc-${ENVIRONMENT}:latest

}

function cleanup {

  # Remove the Docker images locally
  docker rmi -f ghcr.io/adelerhof/subnetcalc-${ENVIRONMENT}:${TAG}
  docker rmi -f ghcr.io/adelerhof/subnetcalc-${ENVIRONMENT}:latest
  docker rmi -f harbor.adelerhof.eu/subnetcalc/subnetcalc-${ENVIRONMENT}:${TAG}
  docker rmi -f harbor.adelerhof.eu/subnetcalc/subnetcalc-${ENVIRONMENT}:latest

}

function install_npm {
	pushd ${HOMEDIR_GIT}
	for I in ${APPF_REPO_LIST}
	do
		# Determine the directory of the cloned repo
		DIR=$(echo $I |cut -d\/ -f 2- | sed 's/.git$//')
		echo "${I} ${DIR}"

		# Check or the directory exists and is not a sybolic link
		if [ -d ${DIR} -a  ! -h ${DIR} ]
		then
			# Update the contect of the directory
			pushd ${HOMEDIR_GIT}
			pushd ${DIR}

			sudo apt update
			sudo apt install nodejs
			node -v

			sudo apt install npm
			npm i --package-lock-only
			npm audit fix
		fi

	done
}

function deploy_prd {

	ENVIRONMENT=main

	checkout_code
	build_image
	push_image
	install_npm
	cleanup
}

# Script options
case $1 in
        deploy_prd)
        $1
        ;;
        *)
       echo $"Usage : $0 {deploy_prd}"
       exit 1
       ;;
esac
