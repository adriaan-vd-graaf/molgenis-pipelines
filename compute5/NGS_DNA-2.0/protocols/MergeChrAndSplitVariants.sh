#MOLGENIS walltime=23:59:00 mem=4gb

#Parameter mapping
#string stage
#string checkStage
#string tempDir
#string intermediateDir
#string projectVariantsMerged
#string projectSNPsMerged
#string projectIndelsMerged
#string projectVariantsMergedSorted
#list chr
#list projectChrVariantCalls
#string projectPrefix
#string tmpDataDir
#string project
#string sortVCFpl 
#string indexFileFastaIndex
#list externalSampleID

#Echo parameter values
echo "stage: ${stage}"
echo "checkStage: ${checkStage}"
echo "tempDir: ${tempDir}"
echo "intermediateDir: ${intermediateDir}"
echo "projectVariantCallsMerged: ${projectVariantsMerged}"                                           
echo "projectSNPsMerged: ${projectSNPsMerged}" 
echo "projectIndelsMerged: ${projectIndelsMerged}"
echo "projectVariantsMergedSorted: ${projectVariantsMergedSorted}"

#Load module BWA
${stage} tabix/0.2.6
${checkStage}

makeTmpDir ${projectVariantsMerged}
tmpProjectVariantsMerged=${MC_tmpFile}

makeTmpDir ${projectSNPsMerged}
tmpProjectSNPsMerged=${MC_tmpFile}

makeTmpDir ${projectIndelsMerged}
tmpProjectIndelsMerged=${MC_tmpFile}

makeTmpDir ${projectVariantsMergedSorted}
tmpProjectVariantsMergedSorted=${MC_tmpFile}

#Function to check if array contains value
array_contains () { 
    local array="$1[@]"
    local seeking=$2
    local in=1
    for element in "${!array-}"; do
        if [[ $element == $seeking ]]; then
            in=0
            break
        fi
    done
    return $in
}

#load vcftools
module load vcftools/0.1.12a
module list

EXTSAMPLES=()
for externalID in "${externalSampleID[@]}"
do
	array_contains EXTSAMPLES "$externalID" || EXTSAMPLES+=("$externalID")    # If bamFile does not exist in array add it
done


INPUTS=()

for c in "${chr[@]}"
do
        MERG=()

        for externalID in "${EXTSAMPLES[@]}"
        do
                if [ $c == "Y" ]
                then
                        count=`grep -v '^#' ${intermediateDir}/${externalID}.chr${c}.variant.calls.vcf  | wc -l`
                        if [ count == 0  ]
                        then
                                echo "Chromosome Y has no variant calls"
                        else
                                bgzip -c ${intermediateDir}/${externalID}.chr${c}.variant.calls.vcf > ${intermediateDir}/${externalID}.chr${c}.variant.calls.vcf.gz
                                tabix -p vcf ${intermediateDir}/${externalID}.chr${c}.variant.calls.vcf.gz
                                MERG+=(${intermediateDir}/${externalID}.chr${c}.variant.calls.vcf.gz)
                        fi
		else
        	        bgzip -c /gcc//groups/gaf/tmp01/tmp//5GPM_1502/test01//${externalID}.chr${c}.variant.calls.vcf > /gcc//groups/gaf/tmp01/tmp//5GPM_1502/test01//${externalID}.chr${c}.variant.calls.vcf.gz
                	tabix -p vcf /gcc//groups/gaf/tmp01/tmp//5GPM_1502/test01//${externalID}.chr${c}.variant.calls.vcf.gz
                	MERG+=(/gcc//groups/gaf/tmp01/tmp//5GPM_1502/test01//${externalID}.chr${c}.variant.calls.vcf.gz)
                fi
        done

        vcf-merge "${MERG[@]}" > ${projectPrefix}.variant.calls.vcf
        INPUTS+=(${projectPrefix}.variant.calls.vcf)

done

	
#Concatenate projectChrVariantCalls to one file

echo "INFO: Concatenate projectChrVariantCalls to one file"
vcf-concat "${INPUTS[@]}" > ${tmpProjectVariantsMerged}

#sort VCF file
echo "INFO: Sort variants"
cat ${tmpProjectVariantsMerged} | vcf-sort --chromosomal-order > ${projectVariantsMergedSorted}

#split variant in SNPS and indels
echo "INFO: split vatiant into SNPs and indels"
vcftools --vcf ${projectVariantsMergedSorted} --keep-only-indels --out ${tmpProjectIndelsMerged} --recode --recode-INFO-all
vcftools --vcf ${projectVariantsMergedSorted} --remove-indels --out ${tmpProjectSNPsMerged} --recode --recode-INFO-all

#move tmpFiles to Intermediatefolder
echo -e "\nMergeChrAndSplitVariants finished succesfull. Moving temp files to final.\n\n"

#sort and rename VCF file 
${sortVCFpl} \
-fastaIndexFile ${indexFileFastaIndex} \
-inputVCF ${tmpProjectIndelsMerged}.recode.vcf \
-outputVCF ${tmpProjectIndelsMerged}

#sort and rename VCF file
${sortVCFpl} \
-fastaIndexFile ${indexFileFastaIndex} \
-inputVCF ${tmpProjectSNPsMerged}.recode.vcf \
-outputVCF ${tmpProjectSNPsMerged}


mv ${tmpProjectSNPsMerged} ${projectSNPsMerged}
mv ${tmpProjectIndelsMerged} ${projectIndelsMerged}
putFile "${projectSNPsMerged}"
putFile "${projectIndelsMerged}"

#prepare the created vcfs for bcftools: bgzip + tabix to set the correct indexes and make correct format
bgzip -c ${projectIndelsMerged} > ${projectIndelsMerged}.gz
tabix -p vcf ${projectIndelsMerged}.gz
