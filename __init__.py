# bag_startup class
# This could be merged to bag class 
#
# Provides commmon setup method for other classes in bag generator scripts
# Created by Marko Kosunen
#
# Last modification by Marko Kosunen, marko.kosunen@aalto.fi, 07.12.2018 16:14
##############################################################################
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

#Set 'must have methods' with abstractmethod
#@abstractmethod
#Using this decorator requires that the class’s metaclass is ABCMeta or is 
#derived from it. A class that has a metaclass derived from ABCMeta cannot 
#be instantiated unless all of its abstract methods and properties are overridden.

class bag_startup(metaclass=abc.ABCMeta):
    #Define here the common attributes for the system
    #Solve for the BAGHOME
    BAGHOME=os.path.realpath(__file__)
    for i in range(2):
        BAGHOME=os.path.dirname(BAGHOME)
    print("Home of BAG is %s" %(BAGHOME))
    #This is for bag control through shell txtfile if needed
    CONFIGFILE=BAGHOME+'/BAG.config'

    print("Config file  of BAG is %s" %(CONFIGFILE))

    sys.path.append(os.environ['BAG_FRAMEWORK'])
    sys.path.append(os.environ['BAG_TECH_CONFIG_DIR'])
    sys.path.append(os.path.join(os.environ['BAG_WORK_DIR'], 'BAG2_TEMPLATES_EC'))

    #Lets read the BAG config pyhhon dictionary
    # Im quite sure that these can be accessd through bag class
    with open(BAGHOME+'/bag_config.yaml', 'r') as f:
        bag_config = yaml.load(f)


    #Appending all BAG generator python modules to system path 
    # (only ones, with set subtraction)
    
    
    GENERATORS=[(x[1]) for x in os.walk( BAGHOME)][0]
    #Add automatically the files from BAGHOME
    MODULEPATHS=[]
    for i in GENERATORS:
        if os.path.isfile(BAGHOME+"/" + i +"/" + i + "/__init__.py"):
            MODULEPATHS.append(BAGHOME+"/" + i)
    

    for i in list(set(MODULEPATHS)-set(sys.path)):
        print("Adding %s to system path" %(i))
        sys.path.append(i)
    
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

    #Class method for setting the logfile
    @classmethod
    def initlog(cls,*arg):
        if len(arg) > 0:
            __class__.logfile=arg[0]

        if os.path.isfile(__class__.logfile):
            os.remove(__class__.logfile)
        typestr="INFO at "
        msg="Default logfile override. Inited logging in %s" %(__class__.logfile)
        fid= open(__class__.logfile, 'a')
        print("%s %s  %s: %s" %(time.strftime("%H:%M:%S"),typestr, __class__.__name__ , msg))
        fid.write("%s %s %s: %s\n" %(time.strftime("%H:%M:%S"),typestr, __class__.__name__ , msg))
        fid.close()

    #Common properties
    @property
    def DEBUG(self):
        if not hasattr(self,'_DEBUG'):
            return 'False'
        else:
            return self._DEBUG
    @DEBUG.setter
    def DEBUG(self,value):
        self._DEBUG=value

    #Method for logging
    #This is a method because it uses the logfile property
    def print_log(self,argdict={'type': 'I', 'msg': "Print this to log"} ):
        if not os.path.isfile(thesdk.logfile):
            typestr="INFO at "
            msg="Inited logging in %s" %(thesdk.logfile)
            fid= open(thesdk.logfile, 'a')
            print("%s %s thesdk: %s" %(time.strftime("%H:%M:%S"), typestr , msg))
            fid.write("%s %s thesdk: %s\n" %(time.strftime("%H:%M:%S"), typestr, msg))
            fid.close()

        if argdict['type']== 'D':
            if self.DEBUG:
                typestr="DEBUG at"
                print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , argdict['msg'])) 
                if hasattr(self,"logfile"):
                    fid= open(thesdk.logfile, 'a')
                    fid.write("%s %s %s: %s\n" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , argdict['msg'])) 
            return
        elif argdict['type']== 'I':
           typestr="INFO at "
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , argdict['msg'])) 
        elif argdict['type']=='W':
           typestr="WARNING! at"
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , argdict['msg'])) 
        elif argdict['type']=='E':
           typestr="ERROR! at"
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , argdict['msg'])) 

        elif argdict['type']=='F':
           typestr="FATAL ERROR! at"
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , argdict['msg'])) 
           print("Quitting due to fatal error in %s" %(self.__class__.__name__))
           if hasattr(self,"logfile"):
               fid= open(thesdk.logfile, 'a')
               fid.write("%s Quitting due to fatal error in %s.\n" %( time.strftime("%H:%M:%S"), self.__class__.__name__))
               fid.close()
               quit()
        else:
           typestr="ERROR! at"
           msg="Incorrect message type. Choose one of 'D', 'I', 'E' or 'F'."
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , argdict['msg'])) 

        #If logfile set, print also there 
        if hasattr(self,"logfile"):
            fid= open(thesdk.logfile, 'a')
            fid.write("%s %s %s: %s\n" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , argdict['msg'])) 


