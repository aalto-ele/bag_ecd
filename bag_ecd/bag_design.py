'''
BAG Design
==========

Definitions of common attributes and methods for all bag designs to \
guarantee design portability.

'''
import sys
import os
import time
import abc
from abc import *
from shutil import copy2
import re

from bag_ecd import bag_startup 

import json
import bag
from bag.layout import RoutingGrid, TemplateDB
from BAG_technology_definition import BAG_technology_definition 
import pdb
class bag_design(BAG_technology_definition, bag_startup,metaclass=abc.ABCMeta):

    @property
    @abstractmethod
    def _classfile(self):
        return os.path.dirname(os.path.realpath(__file__)) + "/"+__name__
    
    @property
    def package(self):
        '''
        The name of the instance to be generated. ECD naming convention is that the package name is suffixed by _gen.
        Thus generator package of inverter is named inverter_gen.
        '''
        if not hasattr(self, '_package'):
            self._package=os.path.splitext(os.path.basename(self._classfile))[0]
        return self._package
    #No setter, no deleter.

    @property
    def name(self):
        '''
        The name of the instance to be generated. ECD naming convention is that the package name is suffixed by _gen.
        Thus generator package of inverter is named inverter_gen.
        '''
        if not hasattr(self, '_name'):
            #_classfile is an abstract property that must be defined in the class.
            chk=re.compile(r'.*_gen')
            test=chk.match(self.package)
            if test:
                self._name=(self.package).replace('_gen','')
            else:
                self.print_log(type='I', msg='Generator package name does not have _gen suffix, and is not ECD compliant')
                self._name=self.package
        return self._name
    #No setter, no deleter.
    
    @property
    def bag_project(self):
        if hasattr(self,'_bag_project'):
            return self._bag_project
        else:
            self.print_log(msg='Initializing BagProject')
            self._bag_project = bag.BagProject()
            return self._bag_project

    @property
    def template_library_name(self):
        if not hasattr(self, '_template_library_name'):
            self._template_library_name= self.name+'_templates'
        return self._template_library_name

    
    @property
    def implementation_library_name(self):
        if not hasattr(self, '_implementation_library_name'):
            self._implementation_library_name= self.name+'_generated'
        return self._implementation_library_name

    @property
    def testbench_library_name(self):
        if not hasattr(self, '_testbench_library_name'):
            self._testbench_library_name= self.name+'_testbenches'
        return self._testbench_library_name
    
    @property
    def layout_params(self):
        '''
        Dictionary of layout parameters. The keys (e.g. the parameters) are defined in layout generators
        get_params_info() classmethod. The corresponding values should be defined as properties (with setters)
        in the __init__ of each BAG module. This makes it possible to set generator parameters as Python attributes
        in external Python modules such as the SDK.

        Strategy for parsing:
            1. Loop over the layout parameters defined in layout generator (keys)
            2. __init__ of module must have corresponding property
            3. Set property as value for the key
        '''
        if not hasattr(self, '_layout_params'):
            if hasattr(self, 'draw_params') and hasattr(self, 'sch_params'): # Old type generators, for backwards compatibility
                self._layout_params={**self.sch_params, **self.draw_params}
            elif not hasattr(self,'draw_params'): # New type of generator, no dictionaries in __init__.py
                self._layout_params=dict()
                for key in self.layout.get_params_info(): # This classmethod must exist in every layout generator
                    # check if attribute is defined in __init__
                    if hasattr(self, key):
                        self._layout_params[key]=getattr(self, key)
                    # if parameter was not define in __init__, it might have default value in layout.py
                    elif key in self.layout.get_default_param_values().keys(): 
                        self.print_log(msg="Attribute %s not defined in %s/__init__.py, but is given default value in layout generator" \
                                % (key, type(self).__name__))
                        self.print_log(msg="Consider defining it explicitly in __init__.py in order to provide access to paramter")
                    # Parameter was not defined anywhere, raise error
                    else:
                        raise self.print_log(type='F',msg='Parameter %s defined in layout generator not defined in __init__ of %s or as an optional parameter!'\
                                % (key, type(self).__name__))
            return self._layout_params
        else:
            return self._layout_params
    @layout_params.setter
    def layout_params(self, val):
        '''
        Setter for layout_params. Useful for setting parameters in dict form from the SDK.
        '''
        self._layout_params=val

    @property
    def sch_params(self):
        '''
        Dictionary of schematic parameters. These are a subset of layout parameters and are parsed in layout generator.
        Setter is provided for backwards compatibility to older generators, which utilize dictionaries for storing parameters.
        '''
        if not hasattr(self, '_sch_params'):
            self._sch_params={}
        return self._sch_params
    @sch_params.setter
    def sch_params(self, val):
        self._sch_params=val


    @property
    def routing_grid(self):
        ''' Defines the routing grid of this design
        uses grid_opts defined in class BAG_technology_definition.
        This practice garantees the designs to be track-compatible within the process.
        '''
        if (not hasattr(self,'_routing_grid')):
            self._routing_grid= RoutingGrid(self.bag_project.tech_info, self.grid_opts['layers'], 
                self.grid_opts['spaces'], 
                self.grid_opts['widths'], 
                self.grid_opts['bot_dir'], 
                width_override=self.grid_opts['width_override'])
            return self._routing_grid
        else:
            return self._routing_grid

    #Common method to propagate system parameters
    # Copied from thesdk class (https://github.com/TheSystemDevelopmentKit/thesdk)
    def copy_propval(self,*arg):
        ''' Method to copy attributes parent generator. 
        
        Example (use in parent generator __init__.py):

           a=hierarchical_generator(self)

        Attributes listed in proplist attribute of 'hierarchical_generator' are copied from
        self to a. Impemented by including following code at the end of __init__ method 
        of every generator:
        
            if len(arg)>=1:
                parent=arg[0]
                self.copy_propval(parent,self.proplist)
                self.parent =parent;

        Note: self.aliases (defined in generator) provides mapping between top-level parameter names to lower level parameter names.
        This is done in order to allow setting same parameter (e.g. transistor width) using a different name for
        top and lower level generators.

        '''
           
        if len(arg)>=2:
            self.parent=arg[0]
            for i in range(len(self.proplist)):
                # Check first that parameter has corresponding entry in aliases
                if self.proplist[i] in self.aliases.keys():
                    param_key=self.aliases[self.proplist[i]]
                    if param_key=='aliases' or self.proplist[i]=='aliases': # DONT DO THIS!
                        self.print_log(type='F', msg='Cannot set aliases via proplist!')
                    if hasattr(self,param_key):
                    #Its nice to see how things propagate
                        if  hasattr(self.parent,self.proplist[i]):
                            msg="Setting %s: %s to %s" %(self.__class__.__name__, self.proplist[i], getattr(self.parent,self.proplist[i]))
                            self.print_log(type= 'I', msg=msg)
                            setattr(self,param_key,getattr(self.parent,self.proplist[i]))
                        else:
                            self.print_log(type='W', msg='Parent generator %s doesn\'t define parameter %s! Omitting!' \
                                    % (self.parent.__class__.__name__, self.proplist[i]))
                    else:
                        self.print_log(type='W', msg='%s doesn\'t define parameter %s! Omitting!' \
                                % (self.__class__.__name__, param_key))
                else:
                    self.print_log(type='W', msg='Alias for key %s isn\'t defined in %s.aliases! Omitting!' \
                            % (self.proplist[i],self.__class__.__name__))

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

    @property
    def DEBUG(self):
        ''' Global attribute to setup a debug mode True | Falsw '''
        if not hasattr(self,'_DEBUG'):
            return 'False'
        else:
            return self._DEBUG
    @DEBUG.setter
    def DEBUG(self,value):
        self._DEBUG=value

    #Method for logging
    #This is a method because it uses the logfile property
    def print_log(self,**kwargs):
        if not os.path.isfile(bag_design.logfile):
            typestr="INFO at "
            msg="Inited logging in %s" %(bag_design.logfile)
            fid= open(bag_design.logfile, 'a')
            print("%s %s bag_design: %s" %(time.strftime("%H:%M:%S"), typestr , msg))
            fid.write("%s %s bag_design: %s\n" %(time.strftime("%H:%M:%S"), typestr, msg))
            fid.close()
        type=kwargs.get('type', 'I')
        msg=kwargs.get('msg', 'Print this to the log')
        if type== 'D':
            if self.DEBUG:
                typestr="DEBUG at"
                print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , msg)) 
                if hasattr(self,"logfile"):
                    fid= open(bag_design.logfile, 'a')
                    fid.write("%s %s %s: %s\n" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , msg)) 
            return
        elif type== 'I':
           typestr="INFO at "
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , msg)) 
        elif type=='W':
           typestr="WARNING! at"
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , msg)) 
        elif type=='E':
           typestr="ERROR! at"
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , msg)) 

        elif type=='F':
           typestr="FATAL ERROR! at"
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , msg)) 
           print("Quitting due to fatal error in %s" %(self.__class__.__name__))
           if hasattr(self,"logfile"):
               fid= open(bag_design.logfile, 'a')
               fid.write("%s Quitting due to fatal error in %s.\n" %( time.strftime("%H:%M:%S"), self.__class__.__name__))
               fid.close()
               quit()
        else:
           typestr="ERROR! at"
           msg="Incorrect message type. Choose one of 'D', 'I', 'E' or 'F'."
           print("%s %s %s: %s" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , msg)) 

        #If logfile set, print also there 
        if hasattr(self,"logfile"):
            fid= open(bag_design.logfile, 'a')
            fid.write("%s %s %s: %s\n" %(time.strftime("%H:%M:%S"), typestr, self.__class__.__name__ , msg)) 

    def param_dump(self, fname=''):
        '''
        Call this to dump generator parameters to file given by fname.
        If filename was not given, dump to module dir.
        Useful for generating confgurations files for the SDK.
        '''
        if fname=='':
            fname='./%s/%s_params.json' % (self.name, self.name)
        with open(fname, 'w') as f:
            json.dump([self.layout_params], f, indent=4)
        return

    def import_design(self):
        ''' 
        Method to import Virtuoso templates to BAG environment

        If the library do not exist, create it
        When created, check if this package has submodule OR class definition of \
        schematic
        
        If yes:

        1) Add: from import <design>.schematic import schematic to module definition \
            in BagModules/<design>/<templatename>.py
        2) Replace the parent class Module of the created Bag module with schematic \
           class of this package.
        3) In that module, replace the content of the class with "pass"
        
        If no:

        1) Copy generated module to <design>/schematic.py
        2) Change class name to schematic
        3) Relocate the Yaml file. 
        
        The the steps above effectively this moves the schematic definition from \
        BagModules to <design>.schematic submodule. Making your module definition \
        independent of BAG installation location. 

        '''
        #Parameters
        bag_project=self.bag_project
        template_library=self.template_library_name

        cell=self.name

        # Import the templates
        self.print_log(msg='Importing netlist from virtuoso\n')
        
        # Path definitions 
        bag_home=self.BAGHOME
        thispath=os.path.dirname(os.path.realpath(self._classfile))
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
            self.print_log(msg='Schematic generator exists in %s' %(packagename))
        
        elif os.path.isfile(schematic_generator):
            self.print_log(msg='Schematic generator exists at %s. Trying to map that to generated one.' %(schematic_generator))
            # Test is schematic class exists in the schematic generator
            with open(schematic_generator, 'r') as generator_file:
                if not 'class schematic(Module):' in generator_file.read():
                    self.print_log(msg='Existing generator does not contain schematic class')
                    self.print_log(msg='Not compatible with this generator structure.\n Exiting')
                    quit()
                else:
                    self.print_log(msg='Mapping %s to generated class.' %(schematic_generator))
                    #Here, figure out what to do with the generated module AND _new_ generator
                    inputfile=open(packagename, 'r').readlines()
                    tempfile=open(tempgenfile, 'w')
                    done = False
                       
                    for line in inputfile:
                        if re.match('from bag.design.module import Module',line):
                            tempfile.write('from %s.schematic import schematic as %s__%s\n' %(self.package,template_library,cell))
                        else:
                            pass
                            #tempfile.write(line) 
                    tempfile.close()
                    os.rename(tempgenfile, packagename)
                    self.print_log(msg='We need to re-run this to have mapped generators in effect') 
                    quit()

        else:
            # Transfer schematic generator to thispath/schematic.py
            # One cell per directory. Import others from other generators
            os.path.dirname(os.path.realpath(self._classfile)) + "/"+__name__
            self.print_log(msg='Copying schematic generator to %s ' %(thispath+'/schematic.py'))
            copy2(packagename, schematic_generator)
      
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
            self.print_log(msg='You need to re-run this to have mapped generators in effect') 
            quit()
        #
        self.print_log(msg='Netlist import done')

    def generate(self):
        self.import_design()
        dsn = self.bag_project.create_design_module(self.template_library_name, self.name)
        self.print_log(msg='Creating template library and cell')
        
        #This is an instance of template database from bag templates
        #Parameters to TemplateDb
        tdb = TemplateDB('template_libs.def', self.routing_grid, self.implementation_library_name, use_cybagoa=True)
        #This is a instance of a template created with template database
        self.print_log(msg='Generating layout ...')
        layout_template= tdb.new_template(params=self.layout_params, temp_cls=self.layout, debug=True)
        tdb.instantiate_layout(self.bag_project, layout_template, self.name, debug=True)
        if hasattr(layout_template, 'sch_dummy_info'):
            self.print_log(msg='sch_dummy_info should be included in sch_params! Including it now!')
            self.sch_params.update({'sch_dummy_info' : layout_template.sch_dummy_info})
        
        #Update the schematic parameters from the layout
        self.sch_params.update(layout_template.sch_params)

        self.print_log(msg='Finished implementing layout')

        ##This implements schematic
        self.print_log(msg='Generating schematic ...')
        dsn.design(**self.sch_params)
        dsn.implement_design(self.implementation_library_name, top_cell_name=self.name)
        self.print_log(msg='Finished implementing schematic')

