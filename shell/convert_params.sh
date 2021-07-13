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
        d) dependencies=${OPTARG};;
        m) module=${OPTARG};;
        p) preserve="1";;
        t) tabstop=${OPTARG};;
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
    layout_importstr="#Use these to get layout & sch parameters for respective generators:"$'\n'"from ${module}.schematic import schematic"
    sch_importstr="${sch_importstr}"$'\n'"#Use these to get sch parameters for respective generators:"
    for ((i=0; i<${#dependencies[@]}; i++));
    do
        dep=${dependencies[$i]}
        layout_importstr="${layout_importstr}"$'\n'"from ${dep}.layout import layout as ${dep}_layout"
        sch_importstr="${sch_importstr}"$'\n'"from ${dep}.schematic import schematic as ${dep}_sch"
    done
fi

# Append module to dependices as well (needed for Makefile)
dependencies=("${dependencies[@]}" "$module")
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


# Find linenumber for __init__ definition
init_start=$(awk '/\sdef __init__\(self\):/{print NR;exit}' ${genpath})
if [[ "$init_start" == -1 ]]; then
    echo "__init__.py doesn't declare __init__ function! Exiting!"
    exit 1
else
    echo "__init__ declaration found on line ${init_start}"
fi

if [ -z ${tabstop} ]; then
    # Read number of spaces used for intendation and try match that
    tabstop=$(($(awk "FNR==$init_start"'{print gsub("[[:blank:]]",""); exit}' ${genpath})-1))
    tabs=$(for i in $(seq 1 $tabstop); do echo -n " "; done)
    echo "Tabstop not set, detected as ${tabstop}"
else
    echo "Tabstop is set as ${tabstop}"
fi

init_start=$((${init_start}-1)) # Decrement, since we want to print properties before __init__

# Find min and max from positions. Used to extract remainder of __init__ file
positions=("${pos_draw[@]}" "${pos_sch[@]}")
min=${positions[0]}
max=${positions[0]}
for i in "${positions[@]}";
do
    (( i > max )) && max=$i
    (( i < min )) && min=$i
done

# Print all lines before __init__ declaration
awk "FNR<=$init_start"'{print}' ${genpath} >> ${modulepath}/tmp 

# Print generic properties used for all generators
cat << EOF >> ${modulepath}/tmp

${tabs}def __getattr__(self, name):
${tabs}${tabs}'''
${tabs}${tabs}Reason for this is given in below link:
${tabs}${tabs}https://stackoverflow.com/questions/4017572/how-can-i-make-an-alias-to-a-non-function-member-attribute-in-a-python-class
${tabs}${tabs}'''
${tabs}${tabs}if name=='aliases':
${tabs}${tabs}${tabs}raise AttributeError
${tabs}${tabs}return object.__getattribute__(self, name)

${tabs}@property
${tabs}def aliases(self):
${tabs}${tabs}'''
${tabs}${tabs}Mapping between top-level generator parameter name and name of parameter defined in this generator.
${tabs}${tabs}This provides a convenient way of controlling same parameter (e.g. 'lch') for each of the generators
${tabs}${tabs}in the hierarchy.

${tabs}${tabs}Key gives top-level parameter name, value gives name for this generator
${tabs}${tabs}'''
${tabs}${tabs}if not hasattr(self, '_aliases'):
${tabs}${tabs}${tabs}self._aliases={}
${tabs}${tabs}return self._aliases
${tabs}@aliases.setter
${tabs}def aliases(self, val):
${tabs}${tabs}self._aliases=val

${tabs}@property
${tabs}def parent(self):
${tabs}${tabs}'''
${tabs}${tabs}Parent generator in hieararchy. Set automatically
${tabs}${tabs}'''
${tabs}${tabs}if not hasattr(self, '_parent'):
${tabs}${tabs}${tabs}self._parent=None
${tabs}${tabs}return self._parent
${tabs}@parent.setter
${tabs}def parent(self, val):
${tabs}${tabs}self._parent=val

${tabs}@property
${tabs}def proplist(self):
${tabs}${tabs}'''
${tabs}${tabs}List of property names to be copied from parent . Set from
${tabs}${tabs}keys of self.aliases
${tabs}${tabs}'''
${tabs}${tabs}if not hasattr(self, '_proplist'):
${tabs}${tabs}${tabs}self._proplist=list(self.aliases.keys())
${tabs}${tabs}return self._proplist
EOF

## Find draw and schematic parameters, write to tmp file as Python properties
pattern_draw="NR>=${draw_start}&&NR<=${draw_end}"
pattern_sch="NR>=${sch_start}&&NR<=${sch_end}"

# For some reason, AWK doesn't seem to obey the tabstop set by tabs.
sed -e 's/,*$//g' ${genpath} | awk -v tabstop="$tabstop" -F':' "$pattern_draw"'{gsub(/ /,"");
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
# Print everything from __init__ definition to just before the start of parameter defitions to tmp file
awk "FNR<=(($min-1))&&FNR>$((init_start-1))"'{print}' ${genpath} >> ${modulepath}/tmp


cat << EOF >> ${modulepath}/tmp
${tabs}${tabs}if len(arg) >=1:
${tabs}${tabs}${tabs}parent=arg[0]
${tabs}${tabs}${tabs}self.copy_propval(parent, self.proplist)
${tabs}${tabs}${tabs}self.parent=parent
EOF
# Print everything from the stop of parameter definitions to the end of file to tmp file
awk "FNR>=(($max+1))"'{print}' ${genpath} >> ${modulepath}/tmp

# Add args to init for proplist
sed -i 's/def __init__(self):/def __init__(self, *arg):/g' ${modulepath}/tmp

if [ "${preserve}" == "1" ]; then
    echo "Preserving old generator and configure!"
    mv ${genpath} ${modulepath}/__init__.old
    mv ${moduleroot}/configure ${moduleroot}/configure.old
else
    echo "Preserve flag not set, deleting old generator and configure"
    rm -f ${genpath} 
    rm -f ${moduleroot}/configure
fi
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
all: gen lvs drc pex

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
	sed -i "/test_cell_templates/d" ${BAG_WORK_DIR}/cds.lib 
	sed -i "/test_cell_testbenches/d" ${BAG_WORK_DIR}/cds.lib 
	sed -i "/test_cell_generated/d" ${BAG_WORK_DIR}/cds.lib 
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

