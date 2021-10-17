''' 
BAG ECD package
===============

Provides commmon setup method for Berkeley Analog Generator designs and \
desing envireonments. Objective of this package is to abstract away the \
BAG environment setup and design configuration overhead, and to make BAG \
setups and designs:
    1) Modular
    2) Portable
    3) Process independent
    4) Agnostic to Python installation methods used

Created by Marko Kosunen.

 Last modification by Marko Kosunen, marko.kosunen@aalto.fi, 14.12.2019 10:40
'''
import sys
import os
import time
import tempfile
import getpass
import re
import abc
import yaml
from abc import *
from functools import reduce
from shutil import copy2


class bag_startup(metaclass=abc.ABCMeta):
    '''Defines the common attributes of the system environment

    '''
    #Solve for the BAGHOME
    BAGHOME=os.path.realpath(__file__)
    for i in range(3):
        BAGHOME=os.path.dirname(BAGHOME)
    print("Home of BAG is %s" %(BAGHOME))
    #This is for bag control through shell txtfile if needed
    CONFIGFILE=BAGHOME+'/BAG.config'

    print("Config file  of BAG is %s" %(CONFIGFILE))

    sys.path.append(os.environ['BAG_FRAMEWORK'])
    sys.path.append(os.environ['BAG_TECH_CONFIG_DIR'])
    sys.path.append(os.path.join(os.environ['BAG_TECH_CONFIG_DIR'], 'BAG_prim/layouts'))
    sys.path.append(os.path.join(os.environ['BAG_WORK_DIR'], 'BAG2_TEMPLATES_EC'))

    # Lets read the BAG config pyhhon dictionary
    # Im quite sure that these can be accessed through bag class
    with open(BAGHOME+'/bag_config.yaml', 'r') as content:
        bag_config = yaml.load(content, Loader=yaml.FullLoader)


    #Appending all BAG generator python modules to system path 
    # Strategy: Find all files with path "$BAG_WORK_DIR/module_name/module_name/__init__.py",
    # append to list, set substract sys.path from GENERATORS to ensure that nothing is added
    # twice and to ensure uniqueness
    root=BAGHOME
    GENERATORS=[]
    for item in os.listdir(root):
        if not os.path.isfile(os.path.join(root, item)):
            if os.path.isfile(os.path.join(root, item, item, '__init__.py')):
                GENERATORS.append(os.path.join(BAGHOME,item)) 
    GENERATORS=list(set(GENERATORS) - set(sys.path))
    
    # To make BAG work from SyDeKick: do not add gen to path if there is an entity with same name (this shouldn't be the case anyway)
    # If CMPATH is not BAGHOME, then we are running from SDK.
    currdir=os.getcwd()
    CMPATH=os.path.commonpath([currdir, BAGHOME])
    MODULELIST=[path.split('/')[-1] for path in sys.path] # List modules already in path
    for path in GENERATORS:
        if not path.endswith('_gen'):
            generatorname=path.split('/')[-1]
            warning="WARN: Thou shalt name thy generator python package %s_gen or eventually it must be merged to TheSyDeKick Entity!" %(generatorname) 
            print(warning)

        if CMPATH==BAGHOME: # We are running generators from BAG side
            print("Adding %s to system path\n" %(path))
            sys.path.append(path)
        else: # We are running generators from SDK side
            if path not in MODULELIST:
                print("Adding %s to system path\n" %(path))
                sys.path.append(path)
            else:
                print("WARN: module %s already in path! Omitting!" % (path.split('/')[-1]))

    #Default logfile. Override with initlog if you want something else
    #/tmp/TheSDK_randomstr_uname_YYYYMMDDHHMM.log
    logfile="/tmp/BAG_" + os.path.basename(tempfile.mkstemp()[1])+"_"+getpass.getuser()+"_"+time.strftime("%Y%m%d%H%M")+".log"
    if os.path.isfile(logfile):
        os.remove(logfile)
    print("Setting default logfile %s" %(logfile))

    #Do not create the logfile here
    #----logfile stuff ends here

    # Parse the global parameters from a BAG.config to a dict
    # Delete parameter list as not needed any more
    #global_parameters=[]
    #GLOBALS={}
    #with  open(CONFIGFILE,'r') as fid:
    #    for name in global_parameters:
    #        global match
    #        match='('+name+'=)(.*)'
    #        func_list=(
    #            lambda s: re.sub(match,r'\2',s),
    #            lambda s: re.sub(r'"','',s),
    #            lambda s: re.sub(r'\n','',s)
    #        )
    #        GLOBALS[name]=''
    #        for line in fid:
    #            if re.match(match,line):
    #                GLOBALS[name]=reduce(lambda s, func: func(s), func_list, line)
    #        print("GLOBALS[%s]='%s'"%(name,GLOBALS[name]))
    #del match
    #del global_parameters
    #----Global parameter stuff ends here

