#!/bin/bash
#set -x
timestamp=$(date +%d-%m-%Y_%H-%M-%S)
GW_IP="10.85.57.53"
USER="admin"
PASS="Scaleio123"
SDC_IP="10.85.57.204"
Script_Repo=/scripts/ScaleIO/Repo
TEST_VOLUME_ID=/scripts/ScaleIO/tmp/VOlumeid_test
Script_Volume=/scripts/ScaleIO/Repo/Volumes
SNAPSHOT_NAME="Cohesity_snap_$(date +%Y%m%d)"
Script_logs=/scripts/ScaleIO/Logs/Pre_Script/
SCALEIO_LOG_FILE=ScaleIO_PreScript_$timestamp.txt


#################################################################################################
FUNCTION_CLEANUP_MNT_DIRECTORY () 
{
echo "Function : Cleanup Mount Directory"
echo "Function : Cleanup Mount Directory" >> $Script_logs/$SCALEIO_LOG_FILE
echo "-----------------------------------------"
echo "-----------------------------------------" >> $Script_logs/$SCALEIO_LOG_FILE
for i in $(cat $Script_Volume/Volumes.txt )
do
if [ -d "/mnt/$i" ]
then
echo "Removing the Mount directory for Volume : $i"
echo "Removing the Mount directory for Volume : $i" >> $Script_logs/$SCALEIO_LOG_FILE
rm -rf /mnt/$i
else
echo "Mount Directory not available for Volume : $i"
echo "Mount Directory not available for Volume : $i" >> $Script_logs/$SCALEIO_LOG_FILE
fi
done
}

#############################################################################################

FUNCTION_CLEANUP_SNAPID_REPO ()

{
echo "Function : Cleanup Snapid Repo"
echo "Function : Cleanup Snapid Repo" >> $Script_logs/$SCALEIO_LOG_FILE
echo "-----------------------------------------"
echo "-----------------------------------------" >> $Script_logs/$SCALEIO_LOG_FILE
sudo rm -rf $Script_Repo/SNAPID.txt
sudo rm -rf $Script_Repo/VolumeID.txt
}

##############################################################################################

FUNCTION_TOKEN ()
{
# 1. Login and extract token
#  -----------------------------------------
Scaleio_token=$(curl -s -u $USER:$PASS https://$GW_IP/api/login -k)
Scaleio_token=$(echo $Scaleio_token | tr -d '"')
echo "Token : $Scaleio_token"

# -----------------------------------------
# 2. Get system ID (sysId)
SYSID=$(curl -s -k -u :$Scaleio_token https://$GW_IP/api/Configuration | sed -n 's/.*"systemId":"\([^"]*\)".*/\1/p')
echo "System ID: $SYSID"
echo "System ID: $SYSID" >> $Script_logs/$SCALEIO_LOG_FILE

# 3. Determine SDC ID
SDC_ID=$(curl -s -k -u :$Scaleio_token https://$GW_IP/api/types/Sdc/instances | \
  sed 's/},{/\n/g' | grep "\"sdcIp\":\"$SDC_IP\"" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

echo "SDC ID for $SDC_IP: $SDC_ID"
echo "SDC ID for $SDC_IP: $SDC_ID"  >> $Script_logs/$SCALEIO_LOG_FILE

}
#############################################################################################

FUNCTION_VOLUMEID ()
{
for VOL in $(cat $Script_Volume/Volumes.txt)
do

VOLUME_ID=$(curl -s -k -u :$Scaleio_token https://10.85.57.53/api/types/Volume/instances | \
  sed 's/},{/\n/g' | grep "\"name\":\"$VOL\"" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

echo "Volume ID for $VOLUME_NAME : $VOLUME_ID"
echo "Volume ID for $VOLUME_NAME : $VOLUME_ID"  >> $Script_logs/$SCALEIO_LOG_FILE
echo "$VOLUME_ID" >> $Script_Repo/VolumeID.txt
done
}

################################################################################
FUNCTION_SNAPSHOT ()
{
for SNAP_VOL in $(cat $Script_Repo/VolumeID.txt)
do
    echo "Working on VOL_ID: $SNAP_VOL"
     echo "Working on VOL_ID: $SNAP_VOL"   >> $Script_logs/$SCALEIO_LOG_FILE
    
    # Get volume name
    VOL_INFO=$(curl -s -k -u ":$Scaleio_token" \
      https://10.85.57.53/api/instances/Volume::$SNAP_VOL)
    
    VOL_NAME=$(echo $VOL_INFO | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
    
    echo "Volume Name: $VOL_NAME"
    echo "Volume Name: $VOL_NAME"  >> $Script_logs/$SCALEIO_LOG_FILE
    
    SNAPSHOT_NAME="Cohesity_${VOL_NAME}"
    
    SNAPSHOT=$(curl -s -k -u ":$Scaleio_token" -X POST -H "Content-Type: application/json" \
      -d "{\"snapshotDefs\":[{\"volumeId\":\"$SNAP_VOL\",\"snapshotName\":\"$SNAPSHOT_NAME\",\"accessMode\":\"ReadOnly\"}]}" \
      https://10.85.57.53/api/instances/System/action/snapshotVolumes)
    
  echo "API Response: $SNAPSHOT" >> $Script_logs/$SCALEIO_LOG_FILE  # ADD THIS LINE FOR THE LOGGING
    
  SNAPSHOT_ID=$(echo $SNAPSHOT | sed -n 's/.*"volumeIdList":\["\([^"]*\)".*/\1/p')
    
    echo "Created Snapshot: $SNAPSHOT_NAME - ID: $SNAPSHOT_ID"
    echo "Created Snapshot: $SNAPSHOT_NAME - ID: $SNAPSHOT_ID"   >> $Script_logs/$SCALEIO_LOG_FILE
    echo "$SNAPSHOT_ID" >>  $Script_Repo/SNAPID.txt
done
}
####################################################################################
FUNCTION_MAPPING ()
{
# Determine the SDC ID 

SDC_ID=$(curl -s -k -u :$Scaleio_token https://10.85.57.53/api/types/Sdc/instances | \
  sed 's/},{/\n/g' | grep "\"sdcIp\":\"$SDC_IP\"" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')

echo "SDC_ID : $SDC_ID"
echo "SDC_ID : $SDC_ID"  >> $Script_logs/$SCALEIO_LOG_FILE

for SNAP_ID in $(cat $Script_Repo/SNAPID.txt)
do

SNAP_INFO=$(curl -s -k -u ":$Scaleio_token" \
  https://10.85.57.53/api/instances/Volume::$SNAP_ID)

VOL_NAME=$(echo $SNAP_INFO | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')

echo "Working on Mapping $VOL_NAME & $SNAP_ID to Cohesity Proxy Host"
echo "Working on Mapping $VOL_NAME & $SNAP_ID to Cohesity Proxy Host" >> $Script_logs/$SCALEIO_LOG_FILE

MAP=$(curl -s -k -u :$Scaleio_token -X POST -H "Content-Type: application/json" \
  -d "{\"sdcId\": \"$SDC_ID\"}" \
  https://10.85.57.53/api/instances/Volume::$SNAP_ID/action/addMappedSdc)

if [ "$MAP" == "{}" ]; then
    echo "Successfully mapped $VOL_NAME to SDC"
      echo "Successfully mapped $VOL_NAME to SDC"  >> $Script_logs/$SCALEIO_LOG_FILE
else
    echo "Mapping failed: $MAP"
     echo "Mapping failed: $MAP"   >> $Script_logs/$SCALEIO_LOG_FILE
fi

done

}

######################################################################################

FUNCTION_MOUNTDIR ()
{
echo "Function : Mount Directory "
echo "Function : Mount Directory " >> $Script_logs/$SCALEIO_LOG_FILE
echo "--------------------------------------------"
echo "--------------------------------------------" >> $Script_logs/$SCALEIO_LOG_FILE
echo "Step 2 : Create Mount directory to mount the ScaleIO Snapshot"
echo "Step 2 : Create Mount directory to mount the ScaleIO Snapshot"  >> $Script_logs/$SCALEIO_LOG_FILE
for i in $(cat $Script_Volume/Volumes.txt )
do
echo "Creating Mount Directory for Volume : $i"
echo "Creating Mount Directory for Volume : $i" >> $Script_logs/$SCALEIO_LOG_FILE
mkdir /mnt/$i
#echo " working on $i name"
done
}

#####################################################################################
FUNCTION_VOLUME_MOUNT ()

{
echo "Function : Volume Mount"
echo "Function : Volume Mount" >> $Script_logs/$SCALEIO_LOG_FILE
echo "-------------------------------------------"
echo "-------------------------------------------"  >> $Script_logs/$SCALEIO_LOG_FILE
sleep 20s
ls -l /dev/disk/by-id/ | grep scini
for MOUNT in $(cat $Script_Repo/SNAPID.txt)
do

# Get snapshot info
SNAP_INFO=$(curl -s -k -u ":$Scaleio_token" \
  https://10.85.57.53/api/instances/Volume::$MOUNT)

# Get parent volume ID
PARENT_VOL_ID=$(echo $SNAP_INFO | sed -n 's/.*"ancestorVolumeId":"\([^"]*\)".*/\1/p')

# Get parent volume info
PARENT_INFO=$(curl -s -k -u ":$Scaleio_token" \
  https://10.85.57.53/api/instances/Volume::$PARENT_VOL_ID)

# Extract parent volume name
PARENT_VOL_NAME=$(echo $PARENT_INFO | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')


echo "Source Volume Name: $PARENT_VOL_NAME"


mount /dev/disk/by-id/emc-vol-$SYSID-$MOUNT /mnt/$PARENT_VOL_NAME
df /mnt/$PARENT_VOL_NAME
echo $MOUNT and $PARENT_VOL_NAME
echo $MOUNT and $PARENT_VOL_NAME  >> $Script_logs/$SCALEIO_LOG_FILE
done

}
######################################################################################
FUNCTION_UMOUNT_PRECHECK ()
{
echo "Function : Volume umount Precheck"
echo "Function : Volume umount Precheck" >> $Script_logs/$SCALEIO_LOG_FILE
echo "----------------------------------------------"
echo "----------------------------------------------"   >> $Script_logs/$SCALEIO_LOG_FILE
echo "Working on Volume Mount Precheck Step"
echo "Working on Volume Mount Precheck Step"   >> $Script_logs/$SCALEIO_LOG_FILE
for i in $(cat $Script_Volume/Volumes.txt )
do
if grep -F " /mnt/$i " /proc/mounts > /dev/null; then
    echo " Volume $i Filesystem is mounted"
    echo " Volume $i Filesystem is mounted" >> $Script_logs/$SCALEIO_LOG_FILE
    echo " Working on unmounting Volume : $i"
    echo " Working on unmounting Volume : $i"  >> $Script_logs/$SCALEIO_LOG_FILE
    umount /mnt/$i
else
    echo " Filesystem not mounted : $i"
    echo " Filesystem not mounted : $i" >> $Script_logs/$SCALEIO_LOG_FILE
fi
done
}
###############################################################################

###########################
FUNCTION_UMOUNT_PRECHECK
FUNCTION_CLEANUP_MNT_DIRECTORY
FUNCTION_CLEANUP_SNAPID_REPO
FUNCTION_TOKEN
FUNCTION_VOLUMEID 
FUNCTION_SNAPSHOT
FUNCTION_MAPPING 
FUNCTION_MOUNTDIR
FUNCTION_VOLUME_MOUNT
