#!/usr/bin/env bash

SED_PATH=/usr/local/Cellar/gnu-sed/4.4/bin/sed
MAKEDOWN_FILE_PATH=/Users/yanshanchen/github/makedown-file
WEB_GIT_PATH=/Users/yanshanchen/github/chenyanshan.github.com
NEW_DIR=`ls -t ${MAKEDOWN_FILE_PATH} | head -n1`
cp -a ${MAKEDOWN_FILE_PATH}/${NEW_DIR} ${WEB_GIT_PATH}/images

for i in `ls ${WEB_GIT_PATH}/images/${NEW_DIR} | grep -v "index.md"`; do
  ${SED_PATH} -i "s@$i@/images/${NEW_DIR}/$i@g" ${WEB_GIT_PATH}/images/${NEW_DIR}/index.md
done

mv ${WEB_GIT_PATH}/images/${NEW_DIR}/index.md ${WEB_GIT_PATH}/_posts/`date +%Y-%m-%d`-${NEW_DIR}.md

/usr/local/bin/git add ${WEB_GIT_PATH}
/usr/local/bin/git commit -m "auto update blog"
/usr/local/bin/git push origin master
