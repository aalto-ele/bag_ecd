#!/bin/sh
# Exit immediately on error:
set -eE -o functrace

failure() {
#    local lineno=$1
#    local msg=$2
    echo "Failed on line $1: $2"
}
trap 'failure ${LINENO} "$BASH_COMMAND"' ERR

help_f()
{
SCRIPTNAME="convert_params"
cat << EOF
${SCRIPTNAME} Release 1.0 (17.09.2019)
$(echo ${SCRIPTNAME} | tr [:upper:] [:lower:])- Convert old generator style to new
Written by Santeri Porrasmaa

SYNOPSIS
$(echo ${SCRIPTNAME} |  tr [:upper:] [:lower:])  [OPTIONS]
DESCRIPTION
    Converts old style BAG generators, where parameters are
    given as dictionaries, to new style. In the new style
    parameters are handled as Python properties

    Note: doesn't work with nested parmeter dicts.

OPTIONS
  -c
      git add && commit changes to git repository
      with message "convert generator to new parameter convention"
  -d
      List of generator dependendencies. Example: -d "generator_1 generator_2 generator_3"
      Used for hierarchical designs.
  -m
      Module name to operate on
  -p
      Preserve old generator __init__ file. If set, old generator
      file will be named __init__.old
  -w
      Working directory, this should be Virtuoso directory.
  -t
      Tabstop. Number of whitespace used for intendation.
      If not set, detects automatically.
      NOTE: doesn't currently affect the whole file!
  -h
      Show this help.
EOF
}

preserve="0"
commit="0"
currdir=`pwd`

while getopts cd:m:pt:w:h opt
do
    case "$opt" in
        c) commit="1";;
        d) dependencies=(${OPTARG});;
        m) module=${OPTARG};;
        p) preserve="1";;
        w) currdir=${OPTARG};;
        h) help_f; exit 0;;
        \?) help_f;;
    esac
done


if [ -z "$module" ]; then
    echo "ERROR: no module to operate on given! See help!"
    exit 1
fi

# Generate imports based on dependcies
if [ ${#dependencies[@]} -gt 0 ]; then
    layout_importstr="#Use these to get layout & sch parameters for respective generators:"$'\\\n'"from ${module}.schematic import schematic"
    init_importstr="${init_importstr}"$'\n'"#Use these to instantiate generators down in hierarchy:"
    for ((i=0; i<${#dependencies[@]}; i++));
    do
        dep=${dependencies[$i]}
        init_importstr="${init_importstr}"$'\n'"from ${dep} import ${dep}"
        layout_importstr="${layout_importstr}"$'\\\n'"from ${dep}.schematic import schematic as ${dep}_sch"
    done
fi

modulepath="${currdir}/${module}/${module}"
moduleroot="${currdir}/${module}"
genpath="${modulepath}/__init__.py"
layoutpath="${modulepath}/layout.py"
schpath="${modulepath}/schematic.py"
if [ -f "$genpath" ]; then
    echo "Found __init__.py in ${modulepath}"
else
    echo "__init__.py not in ${modulepath}"
    echo "exiting!"
    exit 1
fi

# Make sch and draw_params of exact type for below match
sed -i "s/self.draw_params\s*=\s*{/self.draw_params={/g" ${genpath}
sed -i "s/self.sch_params\s*=\s*{/self.sch_params={/g" ${genpath}
# Find line numbers of closing curly brackets for self.sch_params and self.draw_params
pos_sch=( $( sed -n -f - ${genpath} <<END_SED
    /self.sch_params={/,/\s}/{
        /self.sch_params={/=
        /\s}/=
    }
END_SED
) )
pos_draw=( $( sed -n -f - ${genpath} <<END_SED
    /self.draw_params={/,/\s}/{
        /self.draw_params={/=
        /\s}/=
    }
END_SED
) )

# Parameters should be 1 line below and above of start and stop points, respectively
draw_start=$((${pos_draw[0]} + 1))
draw_end=$((${pos_draw[1]} - 1))
sch_start=$((${pos_sch[0]} + 1))
sch_end=$((${pos_sch[1]} - 1))
# Format line numbers as awk conditions 
pattern_draw="NR>=${draw_start}&&NR<=${draw_end}"
pattern_sch="NR>=${sch_start}&&NR<=${sch_end}"

# Print generic properties used for all generators
cat << EOF > ${modulepath}/tmp

'''
=========
${module}
=========
'''
import os
from bag_ecd.bag_design import bag_design

from ${module}.layout import layout
${init_importstr}

class ${module}(bag_design):

    def __getattr__(self, name):
        '''
        Reason for this is given in below link:
        https://stackoverflow.com/questions/4017572/how-can-i-make-an-alias-to-a-non-function-member-attribute-in-a-python-class
        '''
        if name=='aliases':
            raise AttributeError
        return object.__getattribute__(self, name)

    @property
    def _classfile(self):
        return os.path.dirname(os.path.realpath(__file__)) + "/"+__name__

    @property
    def aliases(self):
        '''
        Mapping between top-level generator parameter name and name of parameter defined in this generator.
        This provides a convenient way of controlling same parameter (e.g. 'lch') for each of the generators
        in the hierarchy.

        Key gives top-level parameter name, value gives name for this generator
        '''
        if not hasattr(self, '_aliases'):
            self._aliases={}
        return self._aliases
    @aliases.setter
    def aliases(self, val):
        self._aliases=val

    @property
    def parent(self):
        '''
        Parent generator in hieararchy. Set automatically
        '''
        if not hasattr(self, '_parent'):
            self._parent=None
        return self._parent
    @parent.setter
    def parent(self, val):
        self._parent=val

EOF

# Echo dependency param properties to file
for i in "${dependencies[@]}"; do
    echo "    @property" >> ${modulepath}/tmp
    echo "    def ${i}_params(self):" >> ${modulepath}/tmp
    echo "        '''" >> ${modulepath}/tmp
    echo "        Dictionary of parameters for sub-template ${i}" >> ${modulepath}/tmp
    echo "        Remeber to add this entry to layout.py get_params_info() function!" >> ${modulepath}/tmp
    echo "        '''" >> ${modulepath}/tmp
    echo "        if not hasattr(self, '_${i}_params'):" >> ${modulepath}/tmp
    echo "            self._${i}_params=self.${i}.layout_params" >> ${modulepath}/tmp
    echo "        return self._${i}_params" >> ${modulepath}/tmp
    echo "    @${i}_params.setter" >> ${modulepath}/tmp
    echo "    def ${i}_params(self,val):" >> ${modulepath}/tmp
    echo "        self.${i}_params=val" >> ${modulepath}/tmp
    echo "" >> ${modulepath}/tmp
done 

cat << EOF >> ${modulepath}/tmp
    @property
    def proplist(self):
        '''
        List of property names to be copied from parent . Set from
        keys of self.aliases
        '''
        if not hasattr(self, '_proplist'):
            self._proplist=list(self.aliases.keys())
        return self._proplist
EOF

# For some reason, awk doesn't obey tabstop set by tabs
tabstop=4
# Using awk, write sch_params and draw_params contents as Python properties 
sed -e 's/,*$//g' ${genpath} | awk -v tabstop="$tabstop" -F':' "$pattern_draw"'{gsub(/ /,"");
    gsub(/\047/,"",$1); # Replace single quote with blank from dict key
    printf("\n");
    for(i=1;i<=tabstop;i++) {printf " "};
    printf "@property\n";
    for(i=1;i<=tabstop;i++) {printf " "};
    printf "def %s(self):\n", $1;
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "\047\047\047\n"; 
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "Place documentation for parameter %s here\n", $1;
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "\047\047\047\n"; 
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "if not hasattr(self, \047_%s\047):\n" , $1;
    for(i=1;i<=3*tabstop;i++) {printf " "};
    printf "self._%s=%s\n", $1, $2; 
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "return self._%s\n", $1;
    for(i=1;i<=tabstop;i++) {printf " "};
    printf "@%s.setter\n", $1;
    for(i=1;i<=tabstop;i++) {printf " "};
    printf "def %s(self, val):\n", $1;
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "self._%s=val\n", $1;
}' >> ${modulepath}/tmp


sed -e 's/,*$//g' ${genpath} | awk -v tabstop="$tabstop" -F':' "$pattern_sch"'{gsub(/ /,"");
    gsub(/\047/,"",$1); # Replace single quote with blank from dict key
    printf("\n");
    # This is a hack to create same intendation as in target file
    for(i=1;i<=tabstop;i++) {printf " "};
    printf "@property\n";
    for(i=1;i<=tabstop;i++) {printf " "};
    printf "def %s(self):\n", $1;
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "\047\047\047\n"; 
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "Place documentation for parameter %s here\n", $1;
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "\047\047\047\n"; 
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "if not hasattr(self, \047_%s\047):\n" , $1;
    for(i=1;i<=3*tabstop;i++) {printf " "};
    printf "self._%s=%s\n", $1, $2; 
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "return self._%s\n", $1;
    for(i=1;i<=tabstop;i++) {printf " "};
    printf "@%s.setter\n", $1;
    for(i=1;i<=tabstop;i++) {printf " "};
    printf "def %s(self, val):\n", $1;
    for(i=1;i<=2*tabstop;i++) {printf " "};
    printf "self._%s=val\n", $1;
}' >> ${modulepath}/tmp 

cat << EOF >> ${modulepath}/tmp
    def __init__(self, *arg):
EOF

# Echo dependency instantiation to file 
if [ ${#dependencies[@]} -gt 0 ]; then
    echo "        # Instantiate dependcies with proplist" >> ${modulepath}/tmp
fi
for i in "${dependencies[@]}"; do
    echo "        self.${i}=${i}(self)" >> ${modulepath}/tmp
done 

cat << EOF >> ${modulepath}/tmp
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

if __name__=='__main__':
    from ${module} import ${module}
    inst=${module}()
    inst.generate()

EOF

if [ "${preserve}" == "1" ]; then
    echo "Preserving old generator and configure!"
    mv ${genpath} ${modulepath}/__init__.old
    mv ${moduleroot}/configure ${moduleroot}/configure.old
    cp ${modulepath}/layout.py ${modulepath}/layout.old
    cp ${modulepath}/schematic.py ${modulepath}/schematic.old
else
    echo "Preserve flag not set, deleting old generator and configure"
    rm -f ${genpath} 
    rm -f ${moduleroot}/configure
fi
# Print dependency import into file 
sed -i "/from [a-z\.]* import [A-Z]*[a-z]*Base/a\ ${layout_importstr}" ${modulepath}/layout.py

echo "Renaming tmp file to __init__.py"
# Rename tmp file as the new generator
mv ${modulepath}/tmp ${genpath}


if [ ! -d "${moduleroot}/doc" ]; then
    echo "Documentation directory doesn't exist, creating.."
    mkdir "${moduleroot}/doc"
fi

author=`git config --global user.name`
currdir=`pwd`
cd ${moduleroot}/doc
sphinx-quickstart --sep -p "${module}" -a "${author}" -r "1.0" -l "en" --ext-autodoc --ext-intersphinx --ext-imgmath --ext-ifconfig --ext-viewcode
cd ${currdir}

# Add napoleon extension for sphinx
sed -i "/extensions = \[/a    'sphinx.ext.napoleon'," ${moduleroot}/doc/source/conf.py
# Change imports
sed -i "s/# import/import/g" ${moduleroot}/doc/source/conf.py
sed -i "s/# sys.path/sys.path/g" ${moduleroot}/doc/source/conf.py
sed -i "s|abspath('.')|abspath('../../')|g" ${moduleroot}/doc/source/conf.py
# Change themse for sphinx doc
sed -i "s/alabaster/sphinx_rtd_theme/g" ${moduleroot}/doc/source/conf.py
# Change toctree to include all relevant modules (__init__, layout, schematic)
sed -i "s/:maxdepth: 2/:maxdepth: 3/g" ${moduleroot}/doc/source/index.rst
sed -i "/:caption: Contents:/a .. automodule:: ${module}\n   :members:\n   :undoc-members:\n"\
".. automodule:: ${module}.layout\n   :members:\n   :undoc-members:\n"\
".. automodule:: ${module}.schematic\n   :members:\n   :undoc-members:\n" ${moduleroot}/doc/source/index.rst

# Append module to dependices as well (needed for Makefile)
dependencies=("${dependencies[@]}" "$module")
# Parse strings for defining dependencies, their generation runs and the dependencies them selves
for ((i=0; i<${#dependencies[@]}; i++));
do
    dep=${dependencies[$i]}
    dep_def_str="${dep_def_str}DEP${i} := \\\${BAG_WORK_DIR}/BagModules/${dep}_templates/netlist_info/${dep}.yaml"$'\n'
    dep_gen_str="${dep_gen_str}\\\$(DEP${i}):"$'\n'$'\t'"cd \\\${BAG_WORK_DIR} && \\\${BAG_PYTHON} \\\${BAG_WORK_DIR}/${dep}/${dep}/__init__.py"$'\n'
    dep_str="${dep_str} \\\$(DEP${i})" 
done

# Generate new configure, adding doc target and dependices (if given)
cat << 'HERE' > "${moduleroot}/configure"
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

HERE

# Split document into parts, since I can't be bothered with escaping all dollar signs..
cat << HERE >> ${moduleroot}/configure
${dep_def_str}
HERE

cat << 'HERE' >> ${moduleroot}/configure

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
cat << HERE >> ${moduleroot}/configure
gen: ${dep_str} 
HERE
cat << 'HERE' >> ${moduleroot}/configure
	\$(gen-run)

lvs: \${BAG_WORK_DIR}/${MODULENAME}_generated/${MODULENAME}/layout/layout.oa
	\$(lvs-run)

pex: \${BAG_WORK_DIR}/${MODULENAME}_generated/${MODULENAME}/layout/layout.oa
	\$(pex-run)

drc: \${BAG_WORK_DIR}/${MODULENAME}_lvs_run/${MODULENAME}.calibre.db
	cd \${BAG_WORK_DIR} && \\
    \$(DRC) \$(DRCOPTS)

# Ensure re-generation if dependency missing
HERE

cat << HERE >> ${moduleroot}/configure
${dep_gen_str}
HERE

cat << 'HERE' >> ${moduleroot}/configure
\${BAG_WORK_DIR}/${MODULENAME}_generated/${MODULENAME}/layout/layout.oa:
	\$(gen-run)

\${BAG_WORK_DIR}/${MODULENAME}_lvs_run/${MODULENAME}.calibre.db: \${BAG_WORK_DIR}/${MODULENAME}_generated/${MODULENAME}/layout/layout.oa
	\$(lvs-run)

clean: 
	sed -i "/${MODULENAME}_templates/d" \${BAG_WORK_DIR}/bag_libs.def
	rm -rf  \${BAG_WORK_DIR}/BagModules/${MODULENAME}_templates
	rm -rf  \${BAG_WORK_DIR}/${MODULENAME}_lvs_run
	rm -rf  \${BAG_WORK_DIR}/${MODULENAME}_drc_run

EOF

exit 0

HERE

chmod +x ${moduleroot}/configure
# Git commit, if specified
if [ "${commit}" == "1" ]; then
    echo "Commiting changes"
    git add ${genroot}
    git commit -m "Convert generator to new parameter convention"
fi

exit 0

