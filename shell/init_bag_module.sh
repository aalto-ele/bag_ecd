#!/usr/bin/env bash
#############################################################################
# This script creates a new ECD structured BAG module 
#
# Template by Marko Kosunen
# Created by Santeri Porrasmaa 27.10.2020 
# Last modification by Santeri Porrasmaa, santeri.porrasmaa@aalto.fi, 27.10.2020 
#############################################################################
#Function to display help with -h argument and to control
#the configuration from the command line
help_f()
{
SCRIPTNAME="init_bag_module"
cat << EOF
${SCRIPTNAME} Release 1.0 (27.10.2020)
Initializes a new BAG module.
Written by Santeri Porrasmaa

SYNOPSIS
    $(echo ${SCRIPTNAME} |  tr [:upper:] [:lower:]) [OPTIONS]
DESCRIPTION
   Initializes a new BAG module named by the target argument which follows the ECD structure.
   Run this from the Virtuoso directory. 

OPTIONS
  -t
      Define the name of of the module.
  -c  
      Change template class to AnalogBase. Default: TemplateBase.
  -w
      Working directory. Default: current directory.
  -h
      Show this help.
EOF
}
THISDIR=`pwd`
WORKDIR=${THISDIR}
TARGETNAME=""
BASECLASS="TemplateBase"

while getopts ct:w:h opt
do
  case "$opt" in
    c) BASECLASS="AnalogBase";;
    t) TARGETNAME=${OPTARG};;
    w) WORKDIR=${OPTARG};;
    h) help_f; exit 0;;
    \?) help_f;;
  esac
done

# Check if module name was given
if [ -z "$TARGETNAME" ]; then
    echo "test"
    help_f
    exit 1
fi

MODULENAME=$(basename ${TARGETNAME})

# Construct template import clause 
if [ ${BASECLASS} == "TemplateBase" ]; then
    IMPORTSTR="from bag.layout.template import TemplateBase"
else
    IMPORTSTR="from abs_templates_ec.analog_core import AnalogBase"
fi

echo "Creating module ${MODULENAME}"

# Create module hierarchy:
cd ${WORKDIR}
mkdir BagModules/${MODULENAME}_templates
mkdir ${MODULENAME}
mkdir ${MODULENAME}/${MODULENAME}
mkdir ${MODULENAME}/${MODULENAME}_templates
mkdir ${MODULENAME}/${MODULENAME}_testbenches

cd ${MODULENAME}
echo "Creating configure"

## BEGIN HERE DOCUMENT
cat << 'HERE' > "configure"
#!/bin/sh
MODULENAME=$(basename $(cd $(dirname ${0}) && pwd) ) 
MODULELOCATION=$(cd `dirname ${0}`/.. && pwd )
TECHLIB="$(sed -n '/tech_lib/s/^.*tech_lib:\s*"//gp' \
    ${BAG_WORK_DIR}/bag_config.yaml | sed -n 's/".*$//p' )"

LVS="\${BAG_WORK_DIR}/shell/lvs.sh"

PEX="\${BAG_WORK_DIR}/shell/pex.sh"

if [ -f "${MODULELOCATION}/${MODULENAME}/lvs_box.txt" ]; then
    LVSBOXSTRING="-C ${MODULELOCATION}/${MODULENAME}/lvs_box.txt"
else
    LVSBOXSTRING=""
fi


LVSOPTS="\
    -c ${MODULENAME} \
    ${LVSBOXSTRING} \
    -f \
    -G \"VSS\" \
    -l ${MODULENAME}_generated \
    -v \"VDD VSS\" \
    -S \"VDD\" \
    -t ${TECHLIB} \
"
PEXOPTS="\
    -c ${MODULENAME} \
    ${LVSBOXSTRING} \
    -f \
    -G \"VSS\" \
    -l ${MODULENAME}_generated \
    -R \"0.1 0.01 0.1 0.01\"  \
    -v \"VDD VSS\" \
    -S \"VDD\" \
    -t ${TECHLIB} \
"

DRC="\${BAG_WORK_DIR}/shell/drc.sh" 
DRCOPTS="\
    -c ${MODULENAME} \
    -d \
    -f \
    -l ${MODULENAME}_drc_run \
    -L \
    -g ${BAG_WORK_DIR}/${MODULENAME}_lvs_run/${MODULENAME}.calibre.db \
"

for purpose in templates testbenches; do
    if [ -z "$(grep ${MODULENAME}_${purpose} ${MODULELOCATION}/cds.lib)" ]; then
        echo "Adding ${MODULENAME}_${purpose} to $MODULELOCATION/cds.lib"
        echo "DEFINE  ${MODULENAME}_${purpose} \${BAG_WORK_DIR}/${MODULENAME}/${MODULENAME}_${purpose}" >> ${MODULELOCATION}/cds.lib
    fi
done

CURRENTFILE="${MODULELOCATION}/${MODULENAME}/Makefile"
echo "Generating ${CURRENTFILE}"
cat << EOF > ${CURRENTFILE}
LVS = ${LVS//    }
LVSOPTS =  ${LVSOPTS//    }
PEX = ${PEX//    }
PEXOPTS =  ${PEXOPTS//    }
DRC = ${DRC//    }
DRCOPTS =  ${DRCOPTS//    }

# Runs that are used in mutiple places
define gen-run =
cd \${BAG_WORK_DIR} && \\
\${BAG_PYTHON} ${MODULELOCATION}/${MODULENAME}/${MODULENAME}/__init__.py
endef

define lvs-run =
cd \${BAG_WORK_DIR} && \\
\$(LVS) \$(LVSOPTS)
endef

define pex-run =
cd \${BAG_WORK_DIR} && \\
\$(PEX) \$(PEXOPTS)
endef

.PHONY: all gen lvs drc pex clean

# gen twice for initial mapping
all: gen lvs drc pex

# Yaml file is generated with very first run that requires re-execution
# Therefore the dependency
gen: \${BAG_WORK_DIR}/BagModules/${MODULENAME}_templates/netlist_info/${MODULENAME}.yaml
	\$(gen-run)

lvs: \${BAG_WORK_DIR}/${MODULENAME}_generated/${MODULENAME}/layout/layout.oa
	\$(lvs-run)

pex: \${BAG_WORK_DIR}/${MODULENAME}_generated/${MODULENAME}/layout/layout.oa
	\$(pex-run)

drc: \${BAG_WORK_DIR}/${MODULENAME}_lvs_run/${MODULENAME}.calibre.db
	cd \${BAG_WORK_DIR} && \\
    \$(DRC) \$(DRCOPTS)

# Ensure re-generation if dependency missing
\${BAG_WORK_DIR}/BagModules/${MODULENAME}_templates/netlist_info/${MODULENAME}.yaml:
	\$(gen-run)

\${BAG_WORK_DIR}/${MODULENAME}_generated/${MODULENAME}/layout/layout.oa:
	\$(gen-run)

\${BAG_WORK_DIR}/${MODULENAME}_lvs_run/${MODULENAME}.calibre.db: \${BAG_WORK_DIR}/${MODULENAME}_generated/${MODULENAME}/layout/layout.oa
	\$(lvs-run)

clean: 
	sed -i "/${MODULENAME}_templates/d" \${BAG_WORK_DIR}/bag_libs.def
	sed -i "/test_cell_templates/d" ${BAG_WORK_DIR}/cds.lib 
	sed -i "/test_cell_testbenches/d" ${BAG_WORK_DIR}/cds.lib 
	sed -i "/test_cell_generated/d" ${BAG_WORK_DIR}/cds.lib 
	rm -rf  \${BAG_WORK_DIR}/BagModules/${MODULENAME}_templates
	rm -rf  \${BAG_WORK_DIR}/${MODULENAME}_lvs_run
	rm -rf  \${BAG_WORK_DIR}/${MODULENAME}_drc_run

EOF

exit 0

HERE
## END HERE DOCUMENT
echo "Setting permission of configure to 774"
chmod 774 configure
echo "Creating README.md"
## BEGIN HERE DOCUMENT
cat << EOF > "README.md"
BAG Module: ${MODULENAME}
To run the generator, first ./configure
Then make gen
EOF
## END HERE DOCUMENT
echo "Creating ${MODULENAME}/__init__.py"
## BEGIN HERE DOCUMENT
cat << EOF > "${MODULENAME}/__init__.py"
'''
${MODULENAME}
======

'''
import os
import pdb

from bag_ecd import bag_startup 
from bag_ecd.bag_design import bag_design

import bag
from bag.layout import RoutingGrid, TemplateDB

#This is mandatory
from ${MODULENAME}.layout import layout 

class ${MODULENAME}(bag_design):

    @property
    def _classfile(self):
        return os.path.dirname(os.path.realpath(__file__)) + "/"+__name__

    def __init__(self):
        # Define layout parameters:
        self.draw_params={
        
        }
        # Define schematic parameters:
        self.sch_params={ 
        
        } 
        self.layout=layout

if __name__ == '__main__':
    from ${MODULENAME} import ${MODULENAME}
    inst=${MODULENAME}()
    inst.generate()
 
EOF

## END HERE DOCUMENT

echo "Creating ${MODULENAME}/layout.py"
## BEGIN HERE DOCUMENT
cat << EOF > "${MODULENAME}/layout.py"
'''
${MODULENAME} layout
======

'''
import abc
import pdb

${IMPORTSTR}
## DEFINE YOUR IMPORTS BELOW:


## END IMPORTS

class layout(${BASECLASS}):

    def __init__(self, temp_db, lib_name, params, used_names, **kwargs):
        ${BASECLASS}.__init__(self, temp_db, lib_name, params, used_names, **kwargs)
    
    @classmethod
    def get_default_param_values(cls):
        """Returns a dictionary containing default parameter values.
        Override this method to define default parameter values.  As good practice,
        you should avoid defining default values for technology-dependent parameters
        (such as channel length, transistor width, etc.), but only define default
        values for technology-independent parameters (such as number of tracks).
        Returns
        -------
        default_params : Dict[str, Any]
            dictionary of default parameter values.
        """
        return dict(
        )

    @classmethod
    def get_params_info(cls):
        # type: () -> Dict[str, str]
        """Returns a dictionary containing parameter descriptions.
        Override this method to return a dictionary from parameter names to descriptions.
        Returns
        -------
        param_info : Dict[str, str]
            dictionary from parameter name to description.
        """
        return dict(
            )

    # DEFINE YOUR HELPER FUNCTIONS BELOW:


    # END HELPER FUNCTION DEFS
    
    def draw_layout(self):
        # Define layout drawing procedure below:
         
        # Remember to pass the schematic parameters on to the schematic generator!
        self.sch_params = dict()

class ${MODULENAME}(layout):
    '''
    Class to be used as template in higher level layouts
    '''
    def __init__(self, temp_db, lib_name, params, used_names, **kwargs):
        ${BASECLASS}.__init__(self, temp_db, lib_name, params, used_names, **kwargs)

EOF
## END HERE DOCUMENT
echo "Creating ${MODULENAME}/schematic.py"
## BEGIN HERE DOCUMENT
cat << EOF > "${MODULENAME}/schematic.py"
import os
import pkg_resources
import pdb
from bag.design import Module
yaml_file = os.path.join(f'{os.environ["BAG_WORK_DIR"]}/BagModules/${MODULENAME}_templates', 'netlist_info', '${MODULENAME}.yaml')


# noinspection PyPep8Naming
class schematic(Module):
    """Module for library ${MODULENAME}_templates cell ${MODULENAME}.

    Fill in high level description here.
    """

    def __init__(self, bag_config, parent=None, prj=None, **kwargs):
        Module.__init__(self, bag_config, yaml_file, parent=parent, prj=prj, **kwargs)
       
    @classmethod
    def get_params_info(cls):
        # type: () -> Dict[str, str]
        """Returns a dictionary from parameter names to descriptions.

        Returns
        -------
        param_info : Optional[Dict[str, str]]
            dictionary from parameter names to descriptions.
        """
        return dict(
            )

    def design(self, **kwargs):
        """To be overridden by subclasses to design this module.

        This method should fill in values for all parameters in
        self.parameters.  To design instances of this module, you can
        call their design() method or any other ways you coded.

        To modify schematic structure, call:

        rename_pin()
        delete_instance()
        replace_instance_master()
        reconnect_instance_terminal()
        restore_instance()
        array_instance()
        """
        # Procedure to follow:
        # 1. Extract schematic parameters from kwargs
        # 2. Process the netlist, e.g. reconnect instances or rename pins
        # 3. Call self.instances[inst_name].design(param1=param1, param2=param2, ...)

EOF
## END HERE FILE

# Init the git repo without remote
git init

echo "Creating .gitignore"
## BEGIN HERE FILE
cat << EOF > .gitignore
*.swp
*~
*.cdslck
*.pyc
Makefile
EOF
## END HERE FILE

echo "Done."
echo "IMPORTANT! In order to run the generator, first run ./configure,"
echo "refresh Virtuoso, add schematic and symbol to template library"

exit 0

