''' Bag_startup
===========

Provides commmon setup method for other classes in bag generator scripts
Created by Marko Kosunen

 Last modification by Marko Kosunen, marko.kosunen@aalto.fi, 07.12.2018 16:14
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


#Set 'must have methods' with abstractmethod
#@abstractmethod
#Using this decorator requires that the class’s metaclass is ABCMeta or is 
#derived from it. A class that has a metaclass derived from ABCMeta cannot 
#be instantiated unless all of its abstract methods and properties are overridden.

class bag_startup(metaclass=abc.ABCMeta):
    #Define here the common attributes for the system
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
    sys.path.append(os.path.join(os.environ['BAG_WORK_DIR'], 'BAG2_TEMPLATES_EC'))

    #Lets read the BAG config pyhhon dictionary
    # Im quite sure that these can be accessd through bag class
    with open(BAGHOME+'/bag_config.yaml', 'r') as content:
        bag_config = yaml.load(content, Loader=yaml.FullLoader)


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


class bag_ecd_design(metaclass=abc.ABCMeta):

    @property
    @abstractmethod
    def _classfile(self):
        return os.path.dirname(os.path.realpath(__file__)) + "/"+__name__
    
    @property
    def name(self):
        if not hasattr(self, '_name'):
            #_classfile is an abstract property that must be defined in the class.
            self._name=os.path.splitext(os.path.basename(self._classfile))[0]
        return self._name
    #No setter, no deleter.
    
    #@property
    #def bprj(self):
    #    if hasattr(self,'_bprj'):
    #        print('Using existing BagProject')
    #        return self._bprj
    #    else:
    #        print('Initializing BagProject')
    #        print(sys.path)
    #        self._bprj = bag.BagProject()

    #@property
    #def template_library_name(self):
    #    if not hasattr(self, '_template_library_name'):
    #        self._template_library_name= self.name+'_templates'
    #    return self._template_library_name
    #
    #@property
    #def implementation_library_name(self):
    #    return self.name+'_generated'

    #@property
    #def implementation_library_name(self):
    #    if not hasattr(self, '_implementation_library_name'):
    #        self._implementation_library_name= self.name+'_generated'
    #    return self._implementation_library_name

    #@property
    #def testbench_library_name(self):
    #    if not hasattr(self, '_testbench_library_name'):
    #        self._testbench_library_name= self.name+'_testbenches'
    #    return self._testbench_library_name
    

def import_design(bag_project,template_library,cell):
    ''' Method to import Virtuoso templates to BAG environment

     If the library do not exist, create it
     When created, check if this package has submodule OR class definition of schematic
     If yes,
        1) Add: from import <design>.schematic import schematic to module definition
                in BagModules/<design>/<templatename>.py
        2) Replace the parent class Module of the created Bag module with schematic 
         class of this package.
        3) In that module, replace the content of the class with "pass"
    
        If no
        1) Copy generated module to <design>/schematic.py
        2) change class name to schematic
        3) Relocate the Yaml file
        The the steps above
    
        Effectively this moves the schematic definition from BagModules 
        to <design>.schematic submodule. Making your module definition independent 
        of BAG installation location. 
    '''
    # Import the templates
    print('Importing netlist from virtuoso\n')
    # BAG configuration
    #template_library_name=self.template_library_name
    #cell=self.name
    
    # Path definitions 
    bag_home=bag_startup.BAGHOME
    thispath=os.path.dirname(os.path.realpath(__file__))
    new_lib_path=bag_project.bag_config['new_lib_path']
    schematic_generator=thispath+'/'+'schematic.py'
    tempgenfile=thispath+'/'+'schematic_temp.py'

    #Check if schematic generator already exists
    packagename=bag_home+'/'+new_lib_path+'/'+template_library+ '/'+cell+'.py'
    if os.path.isfile(packagename):
        newpackage = False
    else:
        newpackage = True

    #Importing template library
    bag_project.import_design_library(template_library)


    # Schematic generator should be a submodule in THIS directory
    if not newpackage:
        # Schematic generator already existed
        print('Schematic generator exists in %s' %(packagename))
    
    elif os.path.isfile(schematic_generator):
        print('Schematic generator exists at %s. Trying to map that to generated one.' %(schematic_generator))
        
        # Test is schematic class exists in the schematic generator
        with open(schematic_generator, 'r') as generator_file:
            if not 'class schematic(Module):' in generator_file.read():
                print('Existing generator does not contain schematic class')
                print('Not compatible with this generator structure.\n Exiting')
                quit()
            else:
                print('Mapping %s to generated class.' %(schematic_generator))
                #Here, figure out what to do with the generated module AND _new_ generator
                inputfile=open(packagename, 'r').readlines()
                tempfile=open(tempgenfile, 'w')
                done = False
                  
                for line in inputfile:
                    if re.match('from bag.design.module import Module',line):
                        tempfile.write('from %s.schematic import schematic as %s__%s\n' %(cell,template_library,cell))
                    else:
                        pass
                        #tempfile.write(line) 
                tempfile.close()
                os.rename(tempgenfile, packagename)
                print('We need to re-run this to have mapped generators in effect') 
                quit()

    else:
        # Transfer schematic generator to thispath/schematic.py
        # One cell per directory. Import others from other generators
        os.path.dirname(os.path.realpath(__file__)) + "/"+__name__
        print('Copying schematic generator to %s ' %(thispath+'/schematic.py'))
        copy2(packagename,schematic_generator)
  
        # First we generate a template to be transferred to
        # new_lib_path (BAGHOME/BagModules/template_library/cell.py
        inputfile=open(schematic_generator, 'r').readlines()
        tempfile=open(tempgenfile, 'w')
        done = False

        for line in inputfile:
            if re.match('from bag.design.module import Module',line):
                tempfile.write('from %s.schematic import schematic as %s__%s\n' 
                        %(cell,template_library,cell))
            else:
                pass
        tempfile.close()
        #Move this to BagModules 
        os.rename(tempgenfile, packagename)

        tempfile=open(tempgenfile, 'w')
        #Then rename the actual generator to class schematic        
        for line in inputfile:
            if re.match('class '+ template_library+ '__' + cell+'\(Module\):',line ):
                tempfile.write('class schematic(Module):\n')
            else:
               tempfile.write(line)
        tempfile.close()
        os.rename(tempgenfile, schematic_generator)
        os.rename(tempgenfile, packagename)
        #bag_startup.print_log({'type':'I','msg':'You need to re-run this to have mapped generators in effect'}) 
        print('We need to re-run this to have mapped generators in effect') 
        quit()
    print('Netlist import done\n')

