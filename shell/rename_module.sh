#!/usr/bin/env bash
#############################################################################
# This script that renames an existing ecd structured BAG mosule 
# so it can be used to initiate a new design
# 
# Created by Marko Kosunen on 29.4.2020
# Last modification by Marko Kosunen, marko.kosunen@aalto.fi, 29.04.2020 12:50
#############################################################################
#Function to display help with -h argument and to control
#the configuration from the command line
set -e

help_f()
{
SCRIPTNAME="rename_module"
cat << EOF
${SCRIPTNAME} Release 1.0 (29.4.2020)
Generates LEF from Virtuoso layout.
Written by Okko Järvinen.

SYNOPSIS
    $(echo ${SCRIPTNAME} |  tr [:upper:] [:lower:]) [OPTIONS]
DESCRIPTION
    Renames and existing ecd-structured BAG module 

OPTIONS
  -s  
       Source module name
  -t  
       Target module name
  -w 
      Working directory. Default: current directory.
  -h
      Show this help.
EOF
}
THISDIR=`pwd`
WORKDIR=${THISDIR}
SOURCENAME=""
TARGETNAME=""
FORCE="0"

while getopts s:t:h opt
do
  case "$opt" in
    s) SOURCENAME=${OPTARG};; 
    t) TARGETNAME=${OPTARG};;
    w) WORKDIR=${OPTARG};;
    f) FORCE="1";;    
    h) help_f; exit 0;;
    \?) help_f;;
  esac
done
MODULESOURCE=$(basename ${SOURCENAME})
MODULETARGET=$(basename ${TARGETNAME})
echo $MODULETARGET

#1. Copy the hierarchy 
cd ${WORKDIR}
cp -rp ${SOURCENAME} ${TARGETNAME}

#2 replace strings in Python generators
cd ${TARGETNAME}
mv ${MODULESOURCE} ${MODULETARGET}
sed -i "/${MODULESOURCE}_templates/s/${MODULESOURCE}/${MODULETARGET}/g" ${MODULETARGET}/schematic.py
sed -i "/from\s*${MODULESOURCE}/s/${MODULESOURCE}/${MODULETARGET}/g" ${MODULETARGET}/__init__.py
sed -i "/class\s*${MODULESOURCE}/s/${MODULESOURCE}/${MODULETARGET}/g" ${MODULETARGET}/__init__.py
sed -i "/inst\s*=\s*${MODULESOURCE}/s/${MODULESOURCE}/${MODULETARGET}/g" ${MODULETARGET}/__init__.py
sed -i "/class\s*${MODULESOURCE}/s/${MODULESOURCE}/${MODULETARGET}/g" ${MODULETARGET}/layout.py

#3 Copy the Virtuoso templates library on other name
mv ${MODULESOURCE}_templates ${MODULETARGET}_templates
mv ${MODULETARGET}_templates/${MODULESOURCE} ${MODULETARGET}_templates/${MODULETARGET}

# Init the git repo without remote
rm -rf .git
git init
for file in "\
    configure \
    README.md \
    ${MODULETARGET}/__init__.py \
    ${MODULETARGET}/schematic.py \
    ${MODULETARGET}/layout.py \
    ${MODULETARGET}_templates/cdsinfo.tag \
    ${MODULETARGET}_templates/data.dm \
    ${MODULETARGET}_templates/${MODULETARGET}/data.dm \
    ${MODULETARGET}_templates/${MODULETARGET}/schematic/* \
    ${MODULETARGET}_templates/${MODULETARGET}/symbol/*\
    "; do
git add $file
done


exit 0

