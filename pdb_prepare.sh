#!/bin/bash
# Basic outline of what the script should achive.
export PATH=$PATH:/usr/local/gromacs/bin

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <PDB FILE>";
    exit 1
fi


export WATER=tip3p
export FF=charmm27
export POSITIVE_ION=NA
export NEGATIVE_ION=CL


pdb_fetch $1 > $1.pdb
pdb_delhetatm $1.pdb > $1_noHETATM.pdb

# convert to runtime file
gmx pdb2gmx -f $1_noHETATM.pdb -o $1_prepared.pdb -water $WATER -ff $FF

# create periodic box
gmx editconf -f $1_prepared.pdb -o $1_bounding.pdb -c -d 1.2 -bt dodecahedron

# Solvate process, only works with water
gmx solvate -cp $1_bounding.pdb -o $1_solvated.pdb -p topol.top

# Use blank MDP for ion generation and place ions in simulation
gmx grompp -f mdp_runtime/gen_ions.mdp -c $1_solvated.pdb -p topol.top -o ions.tpr
# Replace solvent atoms...
printf "SOL" | gmx genion -s ions.tpr -o $1_charged.gro -p topol.top -pname $POSITIVE_ION -nname $NEGATIVE_ION -neutral 

STEPS=("energy_minimisation" "equil_temp" "equil_pressure")
MDP_FILES=("energy_minimisation.mdp" "nvt.mdp" "npt.mdp")
STAGE_NAME=("$1_charged" "em" "nvt" "npt")
RESTRAINTS_ENABLED=("no" "yes" "yes")
CHECKPOINT_ENABLED=("no" "no" "yes")

for i in "${!STEPS[@]}"; do
    # store runs in folders? to allow for easy hashing of options, its probably going to be a selection of options which isn't specific though
    mkdir -p "${STEPS[$i]}"
    ADDITIONAL_OPTIONS=""

    if [ $i -eq 0 ]; then
        LAST_DIR="./"
    else
        LAST_DIR="${STEPS[$i-1]}"
    fi

    if [ "${RESTRAINTS_ENABLED[$i]}" == "yes" ]; then
    echo "RESTRAINTS ENABLED" 
        ADDITIONAL_OPTIONS="$ADDITIONAL_OPTIONS -r $LAST_DIR/${STAGE_NAME[$i]}.gro"
    fi

    if [ "${CHECKPOINT_ENABLED[$i]}" == "yes" ]; then
    echo "CHECKPOINTS ENABLED" 
        ADDITIONAL_OPTIONS="$ADDITIONAL_OPTIONS -t $LAST_DIR/${STAGE_NAME[$i]}.cpt"
    fi


    gmx grompp -f mdp_runtime/"${MDP_FILES[$i]}" -c "$LAST_DIR/${STAGE_NAME[$i]}.gro" $ADDITIONAL_OPTIONS -p topol.top -o "${STEPS[$i]}"/"${STEPS[$i]}".tpr
    cd ${STEPS[$i]}
    gmx mdrun -deffnm "${STAGE_NAME[$i+1]}" -ntmpi 1 -s "${STEPS[$i]}".tpr

    ls -al 
    
    if [ $i -eq 4 ]; then
        # Copy end result 
        cp ${STAGE_NAME[$i+1]}.gro ../production.gro
        cp ${STAGE_NAME[$i+1]}.cpt ../production.cpt
    fi

    cd ..
done

echo "Setup simulations complete..."



