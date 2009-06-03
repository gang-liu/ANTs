#!/bin/sh

NUMPARAMS=$#

MAXITERATIONS=30x90x20

if [ $NUMPARAMS -lt 3  ]
then
echo " USAGE ::  "
echo "  sh   ants.sh  ImageDimension  fixed.ext  moving.ext  OPTIONAL-OUTPREFIX   OPTIONAL-max-iterations  OPTIONAL-Subject/Moving-DT-To-Deform-To-Fixed-Image  OPTIONAL-Subject/Moving-BZero-To-DistortionCorrect-To-Moving-T1-Image "
echo " be sure to set ANTSPATH environment variable "
echo " Max-Iterations in form :    JxKxL where "
echo "  J = max iterations at coarsest resolution (here, reduce by power of 2^2) "
echo " K = middle resolution iterations ( here, reduce by power of 2 ) "
echo " L = fine resolution iterations ( here, full resolution ) -- this level takes much more time per iteration "
echo " an extra  Ix before JxKxL would add another level "
echo " Default ierations is  $MAXITERATIONS  -- you can often get away with fewer for many apps "
echo " Other parameters are defaults used in the A. Klein evaluation paper in Neuroimage, 2009 "
echo " "
echo " The DT component is distortion corrected to the T1 image either by the B-Zero Image / Average-DWI Image "
echo " or whatever is passed as the last parameter --- Alternatively, we compute the FA from the DTI and then "
echo" distortion correct to it.   One should test the validity of this approach on your data before widely applying ."
echo " We use the cross-correlation to perform the distortion correction. "
echo " Some parameter tuning may be required, depending on the distortions present in your acquisition. "
exit
fi

#initialization, here, is unbiased
DIM=$1

if  [ ${#DIM} -gt 1 ]
then
echo " Problem with specified ImageDimension => User Specified Value = $DIM "
exit
fi

FIXED=$2

if  [ ${#FIXED} -lt 1 -o  ! -f $FIXED ]
then
echo " Problem with specified Fixed Image => User Specified Value = $FIXED "
exit
fi

MOVING=$3

if  [ ${#MOVING} -lt 1 -o  ! -f $MOVING ]
then
echo " Problem with specified Moving Image => User Specified Value = $MOVING "
exit
fi

OUTPUTNAME=${MOVING%.*.*}
if [ ${#OUTPUTNAME} -eq ${#MOVING} ]
then
OUTPUTNAME=${MOVING%.*}
fi

if [ $NUMPARAMS -gt 3  ]
then
  OUTPUTNAME=${4}
fi

if [ $NUMPARAMS -gt 4  ]
then
 MAXITERATIONS=$5
fi

MOVINGDT=0
if [ $NUMPARAMS -gt 5  ]
then
 MOVINGDT=$6
if [ ! -f $MOVINGDT ]
then
echo " THIS DTI DOES NOT EXIST : $MOVINGDT "
MOVINGDT=""
fi
fi

MOVINGBZ=0
if [ $NUMPARAMS -gt 6  ]
then
 MOVINGBZ=$7
if [ ! -f $MOVINGBZ ]
then
echo " THIS BZero DOES NOT EXIST : $MOVINGBZ "
MOVINGBZ=0
fi
fi



if  [ ${#MOVINGDT} -gt 3 ]
then
echo " The BZero DOES NOT EXIST : Using FA Instead!!"
${ANTSPATH}ImageMath 3 ${OUTPUTNAME}_fa.nii TensorFA  $MOVINGDT
MOVINGBZ=${OUTPUTNAME}_fa.nii
fi


# Mapping Parameters
  TRANSFORMATION=SyN[0.5]
  ITERATLEVEL=(`echo $MAXITERATIONS | tr 'x' ' '`)
  NUMLEVELS=${#ITERATLEVEL[@]}
  echo $NUMLEVELS
  REGULARIZATION=Gauss[2,0]
  METRIC=PR[
    METRICPARAMS=1,2]
#echo " $METRICPARAMS  &  $METRIC "
#exit


#ANTSPATH=/mnt/aibs1/avants/bin/ants/
#ANTSPATH=YOURANTSPATH

echo  " ANTSPATH  $ANTSPATH "
echo " Mapping Parameters  :: "
echo  " Transformation is:  $TRANSFORMATION "
echo " MaxIterations :   $MAXITERATIONS "
echo " Number Of MultiResolution Levels   $NUMLEVELS "
echo " Regularization :  $REGULARIZATION "
echo " Metric :  ${METRIC} "
echo " OutputName :  $OUTPUTNAME "
echo " "
echo " if the files and parameters are all ok then uncomment the exit call below this line  "
echo " "
#exit



# first, do distortion correction of MOVINGDT to MOVING
# use the B0 image
${ANTSPATH}ANTS 3 -m PR[${MOVINGBZ},${MOVING},1,2]  -o ${OUTPUTNAME}distcorr  -r Gauss[3,0] -t SyN[0.25]  -i 25x20x0

${ANTSPATH}WarpImageMultiTransform 3 $MOVING   ${OUTPUTNAME}distcorr.nii ${OUTPUTNAME}distcorrWarp.nii ${OUTPUTNAME}distcorrAffine.txt  -R $MOVINGBZ
#exit

exe=" ${ANTSPATH}ANTS $DIM -m  ${METRIC}${FIXED},${MOVING},${METRICPARAMS}  -t $TRANSFORMATION  -r $REGULARIZATION -o ${OUTPUTNAME}   -i $MAXITERATIONS   --use-Histogram-Matching "

 echo " $exe "

  $exe
   ${ANTSPATH}WarpImageMultiTransform $DIM  $MOVING    ${OUTPUTNAME}deformed.nii ${OUTPUTNAME}Warp.nii ${OUTPUTNAME}Affine.txt  -R ${FIXED}

if  [ ${#MOVINGDT} -gt 3 ]
then
    DTDEF=${OUTPUTNAME}DTdeformed.nii
FIXEDSUB=${OUTPUTNAME}fixedsub.nii
ResampleImageBySpacing 3 $FIXED $FIXEDSUB 2 2 2
echo " Warp DT "
    ${ANTSPATH}WarpTensorImageMultiTransform $DIM  $MOVINGDT    $DTDEF ${OUTPUTNAME}Warp.nii ${OUTPUTNAME}Affine.txt  -i  ${OUTPUTNAME}distcorrAffine.txt   ${OUTPUTNAME}distcorrInverseWarp.nii   -R $FIXEDSUB

COMPWARP=${OUTPUTNAME}DTwarp.nii
 ${ANTSPATH}ComposeMultiTransform $DIM $COMPWARP   -R ${FIXEDSUB}  ${OUTPUTNAME}Warp.nii ${OUTPUTNAME}Affine.txt  -i  ${OUTPUTNAME}distcorrAffine.txt   ${OUTPUTNAME}distcorrInverseWarp.nii
${ANTSPATH}ReorientTensorImage 3 $DTDEF  $DTDEF  $COMPWARP

fi



exit
