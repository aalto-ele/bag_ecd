#!/bin/sh
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
  -c  
      Change template class to AnalogBase. Default: TemplateBase.
  -d
      List of generator dependendencies. Example: -d "generator_1 generator_2 generator_3"
      Used for hierarchical designs.
  -t
      Define the name of of the module.
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

while getopts cd:t:w:h opt
do
  case "$opt" in
    c) BASECLASS="AnalogBase";;
    d) DEPENDENCIES=(${OPTARG});;
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

if [[ $MODULENAME == *_gen ]]; then
    echo "Module named with suffix _gen! Good work!"
else
    echo "Module name didn't end with suffix _gen! Appending _gen to module name!"
    MODULENAME="${MODULENAME}_gen"
fi

MODULE_IMPRTNAME=${MODULENAME::-4} # Remove suffix for layout and schematic generators

# Construct template import clause 
if [ ${BASECLASS} == "TemplateBase" ]; then
    LAYOUT_IMPORTSTR="from bag.layout.template import TemplateBase"$'\n'"from ${MODULENAME}.schematic import schematic"
else
    LAYOUT_IMPORTSTR="from abs_templates_ec.analog_core import AnalogBase"$'\n'"from ${MODULENAME}.schematic import schematic"
fi

if [ ${#DEPENDENCIES[@]} -gt 0 ]; then
    LAYOUT_IMPORTSTR="${LAYOUT_IMPORTSTR}"$'\n'"#Use these to get layout & sch parameters for respective generators:"
    for ((i=0; i<${#DEPENDENCIES[@]}; i++));
    do
        DEP=${DEPENDENCIES[$i]}
        INIT_IMPORTSTR="${INIT_IMPORTSTR}"$'\n'"from ${DEP} import ${DEP}"
        if [[ $DEP == *_gen ]]; then
            LAYOUT_IMPORTSTR="${LAYOUT_IMPORTSTR}"$'\n'"from ${DEP}.layout import ${DEP::-4}"
            LAYOUT_IMPORTSTR="${LAYOUT_IMPORTSTR}"$'\n'"from ${DEP}.schematic import schematic as ${DEP::-4}_sch"
        else
            LAYOUT_IMPORTSTR="${LAYOUT_IMPORTSTR}"$'\n'"from ${DEP}.layout import ${DEP}"
            LAYOUT_IMPORTSTR="${LAYOUT_IMPORTSTR}"$'\n'"from ${DEP}.schematic import schematic as ${DEP}_sch"
        fi
    done
fi


echo "Creating module ${MODULENAME}"

# Create module hierarchy:
cd ${WORKDIR}
mkdir BagModules/${MODULE_IMPRTNAME}_templates
mkdir ${MODULENAME}
mkdir ${MODULENAME}/${MODULENAME}
mkdir ${MODULENAME}/${MODULE_IMPRTNAME}_templates
mkdir ${MODULENAME}/${MODULE_IMPRTNAME}_testbenches

cd ${MODULENAME}

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
${INIT_IMPORTSTR}

class ${MODULENAME}(bag_design):

    @property
    def _classfile(self):
        return os.path.dirname(os.path.realpath(__file__)) + "/"+__name__

EOF

# Echo dependency param properties to file
for i in "${DEPENDENCIES[@]}"; do
    echo "    @property" >> ${MODULENAME}/__init__.py
    echo "    def ${i}_params(self):" >> ${MODULENAME}/__init__.py
    echo "        '''" >> ${MODULENAME}/__init__.py
    echo "        Dictionary of parameters for sub-template ${i}" >> ${MODULENAME}/__init__.py
    echo "        Remeber to add this entry to layout.py get_params_info() function!" >> ${MODULENAME}/__init__.py
    echo "        '''" >> ${MODULENAME}/__init__.py
    echo "        if not hasattr(self, '_${i}_params'):" >> ${MODULENAME}/__init__.py
    echo "            self._${i}_params=self.${i}.layout_params" >> ${MODULENAME}/__init__.py
    echo "        return self._${i}_params" >> ${MODULENAME}/__init__.py
    echo "    @${i}_params.setter" >> ${MODULENAME}/__init__.py
    echo "    def ${i}_params(self,val):" >> ${MODULENAME}/__init__.py
    echo "        self.${i}_params=val" >> ${MODULENAME}/__init__.py
    echo "" >> ${MODULENAME}/__init__.py
done 

# Echo dependency instantiation to file 
if [ ${#DEPENDENCIES[@]} -gt 0 ]; then
    echo "        # Instantiate dependcies with proplist" >> ${MODULENAME}/__init__.py
fi
for i in "${DEPENDENCIES[@]}"; do
    echo "        self.${i}=${i}(self)" >> ${MODULENAME}/__init__.py
done 
cat << EOF >> "${MODULENAME}/__init__.py"
    def __init__(self, *arg):
        if len(arg)==1: # Instantiate with proplist
            parent=arg[0]
            self.copy_propval(parent, self.proplist)
            self.parent=parent
        if len(arg)==2: # Instantiate with proplist, parent also supplied aliases
            parent=arg[0]
            self.aliases=arg[1]
            self.copy_propval(parent, self.proplist)
            self.parent=parent
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

${LAYOUT_IMPORTSTR}
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
        # HINT: You can easily parse schematic parameters from self.params by setting
        # them from schematic.get_params_info().keys()
        self.sch_params = dict()

class ${MODULE_IMPRTNAME}(layout):
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

yaml_file = os.path.join(f'{os.environ["BAG_WORK_DIR"]}/BagModules/${MODULE_IMPRTNAME}_templates', 'netlist_info', '${MODULE_IMPRTNAME}.yaml')


# noinspection PyPep8Naming
class schematic(Module):
    """Module for library ${MODULE_IMPRTNAME}_templates cell ${MODULE_IMPRTNAME}.

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
        # 1. Extract schematic parameters from kwargs (these should be parsed per instance basis in layout generator)
        # 2. Process the netlist, e.g. reconnect instances or rename pins
        # 3. Call self.instances[inst_name].design(**inst_sch_params)

EOF
## END HERE FILE

# Add module to dependencies, needed for makefile
DEPENDENCIES=("${DEPENDENCIES[@]}" "$MODULENAME")
# Generate depencies for Makefile
for ((i=0; i<${#DEPENDENCIES[@]}; i++));
do
    DEP=${DEPENDENCIES[$i]}
    if [[ $DEP == *_gen ]]; then
        DEP_DEF_STR="${DEP_DEF_STR}DEP${i} := \\\${BAG_WORK_DIR}/BagModules/${DEP::-4}_templates/netlist_info/${DEP::-4}.yaml"$'\n'
        DEP_GEN_STR="${DEP_GEN_STR}\\\$(DEP${i}):"$'\n'$'\t'"cd \\\${BAG_WORK_DIR} && \\\${BAG_PYTHON} \\\${BAG_WORK_DIR}/${DEP}/${DEP}/__init__.py"$'\n'
        DEP_STR="${DEP_STR} \\\$(DEP${i})" 
    else
        DEP_DEF_STR="${DEP_DEF_STR}DEP${i} := \\\${BAG_WORK_DIR}/BagModules/${DEP}_templates/netlist_info/${DEP}.yaml"$'\n'
        DEP_GEN_STR="${DEP_GEN_STR}\\\$(DEP${i}):"$'\n'$'\t'"cd \\\${BAG_WORK_DIR} && \\\${BAG_PYTHON} \\\${BAG_WORK_DIR}/${DEP}/${DEP}/__init__.py"$'\n'
        DEP_STR="${DEP_STR} \\\$(DEP${i})" 
    fi
done

echo "Creating configure"
## BEGIN HERE DOCUMENT (split into parts to avoid escaping all dollar signs
cat << 'HERE' > configure
#!/bin/sh
MODULENAME=$(basename $(cd $(dirname ${0}) && pwd) ) 
if [[ $MODULENAME == *_gen ]]; then
    CELLNAME=${MODULENAME::-4}
else
    CELLNAME=$MODULENAME
fi

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
    -c ${CELLNAME} \
    ${LVSBOXSTRING} \
    -f \
    -G \"VSS\" \
    -l ${CELLNAME}_generated \
    -v \"VDD VSS\" \
    -S \"VDD\" \
    -t ${TECHLIB} \
"
PEXOPTS="\
    -c ${CELLNAME} \
    ${LVSBOXSTRING} \
    -f \
    -G \"VSS\" \
    -l ${CELLNAME}_generated \
    -R \"0.1 0.01 0.1 0.01\"  \
    -v \"VDD VSS\" \
    -S \"VDD\" \
    -t ${TECHLIB} \
"

DRC="\${BAG_WORK_DIR}/shell/drc.sh" 
DRCOPTS="\
    -c ${CELLNAME} \
    -d \
    -f \
    -l ${CELLNAME}_drc_run \
    -L \
    -g ${BAG_WORK_DIR}/${CELLNAME}_lvs_run/${CELLNAME}.calibre.db \
"

for purpose in templates testbenches; do
    if [ -z "$(grep ${CELLNAME}_${purpose} ${MODULELOCATION}/cds.lib)" ]; then
        echo "Adding ${CELLNAME}_${purpose} to $MODULELOCATION/cds.lib"
        echo "DEFINE  ${CELLNAME}_${purpose} \${BAG_WORK_DIR}/${MODULENAME}/${CELLNAME}_${purpose}" >> ${MODULELOCATION}/cds.lib
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

HERE

# Split document into parts, since I can't be bothered with escaping all dollar signs..
cat << HERE >> configure
${DEP_DEF_STR}
HERE

cat << 'HERE' >> configure

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

.PHONY: all doc gen lvs drc pex clean

# gen twice for initial mapping
all: doc gen lvs drc pex

# Yaml file is generated with very first run that requires re-execution
# Therefore the dependency
doc:
	cd \${BAG_WORK_DIR}/${MODULENAME}/doc && make html

HERE
cat << HERE >> configure
gen: ${DEP_STR} 
HERE
cat << 'HERE' >> configure
	\$(gen-run)

lvs: \${BAG_WORK_DIR}/${CELLNAME}_generated/${CELLNAME}/layout/layout.oa
	\$(lvs-run)

pex: \${BAG_WORK_DIR}/${CELLNAME}_generated/${CELLNAME}/layout/layout.oa
	\$(pex-run)

drc: \${BAG_WORK_DIR}/${CELLNAME}_lvs_run/${CELLNAME}.calibre.db
	cd \${BAG_WORK_DIR} && \\
    \$(DRC) \$(DRCOPTS)

# Ensure re-generation if dependency missing
HERE

cat << HERE >> configure
${DEP_GEN_STR}
HERE

cat << 'HERE' >> configure
\${BAG_WORK_DIR}/${CELLNAME}_generated/${CELLNAME}/layout/layout.oa:
	\$(gen-run)

\${BAG_WORK_DIR}/${CELLNAME}_lvs_run/${CELLNAME}.calibre.db: \${BAG_WORK_DIR}/${CELLNAME}_generated/${CELLNAME}/layout/layout.oa
	\$(lvs-run)

clean: 
	sed -i "/${CELLNAME}_templates/d" \${BAG_WORK_DIR}/bag_libs.def
	rm -rf  \${BAG_WORK_DIR}/BagModules/${CELLNAME}_templates
	rm -rf  \${BAG_WORK_DIR}/${CELLNAME}_lvs_run
	rm -rf  \${BAG_WORK_DIR}/${CELLNAME}_drc_run

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

# Init documentation
AUTHOR=`git config --global user.name`
CURRDIR=`pwd`

echo "Creating doc directory"
mkdir ${CURRDIR}/doc
cd ${CURRDIR}/doc
echo "Initializing doc"
sphinx-quickstart --sep -p "${MODULENAME}" -a "${AUTHOR}" -r "1.0" -l "en" --ext-autodoc --ext-intersphinx --ext-imgmath --ext-ifconfig --ext-viewcode
cd ${CURRDIR}
# Add napoleon extension for sphinx
sed -i "/extensions = \[/a    'sphinx.ext.napoleon'," ${CURRDIR}/doc/source/conf.py

# Change imports
sed -i "s/# import/import/g" ${CURRDIR}/doc/source/conf.py
sed -i "s/# sys.path/sys.path/g" ${CURRDIR}/doc/source/conf.py
sed -i "s|abspath('.')|abspath('../../')|g" ${CURRDIR}/doc/source/conf.py
# Change themse for sphinx doc
sed -i "s/alabaster/sphinx_rtd_theme/g" ${CURRDIR}/doc/source/conf.py
# Change toctree to include all relevant modules (__init__, layout, schematic)
sed -i "s/:maxdepth: 2/:maxdepth: 3/g" ${CURRDIR}/doc/source/index.rst
sed -i "/:caption: Contents:/a .. automodule:: ${MODULENAME}\n   :members:\n   :undoc-members:\n"\
".. automodule:: ${MODULENAME}.layout\n   :members:\n   :undoc-members:\n"\
".. automodule:: ${MODULENAME}.schematic\n   :members:\n   :undoc-members:\n" ${CURRDIR}/doc/source/index.rst

# Init the git repo without remote
echo "Initializing git project"
echo "Remember to add remote!"
git init

echo "Creating .gitignore"
## BEGIN HERE FILE
cat << EOF > .gitignore
*.swp
*~
*.cdslck
*cdslck*
*.pyc
Makefile
EOF
## END HERE FILE

echo "Done."
echo "IMPORTANT! In order to run the generator, first run ./configure,"
echo "refresh Virtuoso, add schematic and symbol to template library"

exit 0

