'''
BAG Design
==========

Definitions of common attributes and methods for all bag designs to \
guarantee design portability.

'''
import sys
import os
import abc
from abc import *
from shutil import copy2
import re

from bag_ecd import bag_startup 

import bag
from bag.layout import RoutingGrid, TemplateDB
from BAG_technology_definition import BAG_technology_definition 
import pdb
class bag_design(BAG_technology_definition,metaclass=abc.ABCMeta):

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
    
    @property
    def bag_project(self):
        if hasattr(self,'_bag_project'):
            return self._bag_project
        else:
            print('Initializing BagProject')
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
        if (not hasattr(self,'draw_params')): 
            #or (not hasattr(self,'sch_params')):
                raise Exception('Attributes draw_params and sch_params must be defined')
        else:
            return {**self.sch_params, **self.draw_params}

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
        print('Importing netlist from virtuoso\n')
        
        # Path definitions 
        bag_home=bag_startup.BAGHOME
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
            print('Schematic generator exists in %s' %(packagename))
        
        elif os.path.isfile(schematic_generator):
            print('Schematic generator exists at %s. Trying to map that to generated one.' %(schematic_generator))
            print('Copying schematic generator to %s ' %(packagename))
            # This needs to be done, as new_package is now True, meaning that there is file at packagename!
            copy2(schematic_generator, packagename)
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
                        if re.match('from bag.design import Module',line):
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
            os.path.dirname(os.path.realpath(self._classfile)) + "/"+__name__
            print('Copying schematic generator to %s ' %(thispath+'/schematic.py'))
            copy2(packagename,schematic_generator)
      
            # First we generate a template to be transferred to
            # new_lib_path (BAGHOME/BagModules/template_library/cell.py
            inputfile=open(schematic_generator, 'r').readlines()
            tempfile=open(tempgenfile, 'w')
            done = False

            for line in inputfile:
                if re.match('from bag.design import Module',line):
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
        #
        print('Netlist import done\n')

    def generate(self):
        self.import_design()
        dsn = self.bag_project.create_design_module(self.template_library_name, self.name)
        print('Creating template library and cell')
        
        #This is an instance of template database from bag templates
        #Parameters to TemplateDb
        tdb = TemplateDB('template_libs.def', self.routing_grid, self.implementation_library_name, use_cybagoa=True)
        #This is a instance of a template created with template database
        print('Generating layout ...')
        layout_template= tdb.new_template(params=self.layout_params, temp_cls=self.layout, debug=True)
        tdb.instantiate_layout(self.bag_project, layout_template, self.name, debug=True)
        if hasattr(layout_template, 'sch_dummy_info'):
            print('sch_dummy_info should be included in sch_params! Including it now!')
            self.sch_params.update({'sch_dummy_info' : layout_template.sch_dummy_info})
        
        #Update the schematic parameters from the layout
        self.sch_params.update(layout_template.sch_params)

        print('Finished implementing layout')

        ##This implements schematic
        print('Generating schematic ...')
        dsn.design(**self.sch_params)
        dsn.implement_design(self.implementation_library_name, top_cell_name=self.name)
        print('Finished implementing schematic')

