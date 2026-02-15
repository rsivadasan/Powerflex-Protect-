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
Script_logs=/scripts/ScaleIO/Logs/Post_Script/
SCALEIO_LOG_FILE=ScaleIO_PostScript_$timestamp.txt

###########################################
Function_Umount ()
{
echo "Function : Umount all Drives"
echo "Function : Umount all Drives" >> $Script_logs/$SCALEIO_LOG_FILE
echo "---------------------------------" 
echo "---------------------------------"  >>  $Script_logs/$SCALEIO_LOG_FILE
echo "Step 1 : Unmounting all the Snap Volumes from Proxyhost/SDC Client"
echo "Step 1 : Unmounting all the Snap Volumes from Proxyhost/SDC Client" >> $Script_logs/$SCALEIO_LOG_FILE
for i in $(cat $Script_Volume/Volumes.txt )
do 
umount /mnt/$i
echo $i
echo $i >> $Script_logs/$SCALEIO_LOG_FILE
done
}
###########################################
Function_RemoveDir ()
{
echo "Function : Removing all mount Drives from /mnt"
echo "Function : Removing all mount Drives from /mnt"  >>  $Script_logs/$SCALEIO_LOG_FILE
echo "Step2 : Removing all the Mount Directory in Proxyhost/SDC Client"
echo "Step2 : Removing all the Mount Directory in Proxyhost/SDC Client"  >> $Script_logs/$SCALEIO_LOG_FILE
for i in $(cat $Script_Volume/Volumes.txt )
do 
rm -rf /mnt/$i
done
}
###########################################

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
#############################################################
Function_Unmap ()
{
echo "Function : Unmap all Mapped Volumes from ScaleIO"
echo "Function : Unmap all Mapped Volumes from ScaleIO"   >>  $Script_logs/$SCALEIO_LOG_FILE
echo "------------------------------------------------"
echo "------------------------------------------------"   >>  $Script_logs/$SCALEIO_LOG_FILE
echo ""

for SNAP_ID in $(cat $Script_Repo/SNAPID.txt)
do
    echo "Working on Snapshot ID: $SNAP_ID"
    echo "Working on Snapshot ID: $SNAP_ID"   >>  $Script_logs/$SCALEIO_LOG_FILE
    
    UNMAP=$(curl -s -k -u ":$Scaleio_token" -X POST -H "Content-Type: application/json" \
      -d "{\"sdcId\": \"$SDC_ID\"}" \
      https://10.85.57.53/api/instances/Volume::$SNAP_ID/action/removeMappedSdc)
    
    if [ "$UNMAP" == "{}" ]; then
        echo "✓ Successfully unmapped: $SNAP_ID" 
        echo "✓ Successfully unmapped: $SNAP_ID"  >>  $Script_logs/$SCALEIO_LOG_FILE 
    else
        echo "✗ Failed to unmap: $SNAP_ID - Error: $UNMAP"
        echo "✗ Failed to unmap: $SNAP_ID - Error: $UNMAP"  >>  $Script_logs/$SCALEIO_LOG_FILE
    fi
    echo ""
done

echo "Unmapping completed!" 
echo "Unmapping completed!"   >>  $Script_logs/$SCALEIO_LOG_FILE
}
###############################################################
Function_Delete_Snapshot ()
{
echo "Function : Delete Snapshots from ScaleIO"
echo "Function : Delete Snapshots from ScaleIO"  >>  $Script_logs/$SCALEIO_LOG_FILE
echo "------------------------------------------------" 
echo "------------------------------------------------"   >>  $Script_logs/$SCALEIO_LOG_FILE
echo "Step 4 : Deleting all snapshots"
echo "Step 4 : Deleting all snapshots"   >>  $Script_logs/$SCALEIO_LOG_FILE
echo ""

for SNAP_ID in $(cat $Script_Repo/SNAPID.txt)
do
    echo "Deleting Snapshot ID: $SNAP_ID" 
     echo "Deleting Snapshot ID: $SNAP_ID"  >>  $Script_logs/$SCALEIO_LOG_FILE
    
    DELETE=$(curl -s -k -u ":$Scaleio_token" -X POST -H "Content-Type: application/json" \
      -d "{\"removeMode\": \"ONLY_ME\"}" \
      https://10.85.57.53/api/instances/Volume::$SNAP_ID/action/removeVolume)
    
    if [ "$DELETE" == "{}" ]; then
        echo "✓ Successfully deleted: $SNAP_ID"
        echo "✓ Successfully deleted: $SNAP_ID"  >>  $Script_logs/$SCALEIO_LOG_FILE
    else
        echo "✗ Failed to delete: $SNAP_ID - Error: $DELETE"
        echo "✗ Failed to delete: $SNAP_ID - Error: $DELETE"  >>  $Script_logs/$SCALEIO_LOG_FILE
    fi
    echo ""
done

echo "Snapshot deletion completed!" 

}

###########################################
Function_Umount
Function_RemoveDir
FUNCTION_TOKEN
Function_Unmap
Function_Delete_Snapshot

