#!/bin/sh
# Exit immediately on error:
set -e

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

OPTIONS
  -c
      git add && commit changes to git repository
      with message "convert generator to new parameter convention"
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

while getopts cm:pt:w:h opt
do
    case "$opt" in
        c) commit="1";;
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

modulepath="${currdir}/${module}/${module}"
genpath="${modulepath}/__init__.py"
echo "$genpath"
if [ -f "$genpath" ]; then
    echo "Found __init__.py in ${modulepath}"
else
    echo "__init__.py not in ${modulepath}"
    echo "exiting!"
    exit 1
fi

#SCH_PARAM_STR="self.sch_params={"
#DRW_PARAM_STR="self.draw_params={"

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
# Print everything from the stop of parameter definitions to the end of file to tmp file
awk "FNR>=(($max+1))"'{print}' ${genpath} >> ${modulepath}/tmp

if [ "${preserve}" == "1" ]; then
    echo "Preserving old generator!"
    mv ${genpath} ${modulepath}/__init__.old
else
    echo "Preserve flag not set, deleting old generator"
    rm -f ${genpath} 
fi
echo "Renaming tmp file to __init__.py"
# Rename tmp file as the new generator
mv ${modulepath}/tmp ${genpath}

if [ "${commit}" == "1" ]; then
    echo "Commiting changes"
    git add ${genpath}
    git commit -m "Convert generator to new parameter convention"
fi
    
