#!/bin/bash

MAKEDOWN_FILE_PATH=/Users/yanshanchen/github/makedown-file
WEB_GIT_PATH=/Users/yanshanchen/github/chenyanshan.github.com
NEW_DIR=`ls -t ${MAKEDOWN_FILE_PATH} | head -n1`

cp -a ${MAKEDOWN_FILE_PATH}/${NEW_DIR} ${WEB_GIT_PATH}/images

sed "s///g" ${WEB_GIT_PATH}/images/${NEW_DIR}/index.md
