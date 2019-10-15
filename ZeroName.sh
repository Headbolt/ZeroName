#!/bin/bash
#
###############################################################################################################################################
#
# ABOUT THIS PROGRAM
#
#   This Script is designed for use in JAMF
#
#   - This script will ...
#       Grab the Machines name Locally
#       Grab the Machines Target name from the JAMF Extension Attribute
#           Grab the Machines Entry in the Preload Inventory Table if it exists - From V1.1 Onwards
#       Rename if needed
#           Update or create the Machines Entry in the Preload Inventory Table if it needed - From V1.1 Onwards
#
###############################################################################################################################################
#
# HISTORY
#
#   Version: 1.1 - 11/10/2019
#
#   - 13/03/2018 - V1.0 - Created by Headbolt
#
#   - 11/10/2019 - V1.1 - Updated by Headbolt
#                           Support added for Preload Inventory Table
#                           More comprehensive error checking and notation
#
###############################################################################################################################################
#
# DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
# Variables used by this script.
#
# Grab the password for API Login from JAMF variable #4 eg. username
apiUser=$4
#
# Grab the password for API Login from JAMF variable #5 eg. password
apiPass=$5
#
# Grab the first part of the API URL from JAMF variable #6 eg. https://COMPANY-NAME.jamfcloud.com
apiURL=$6
#
# Set the name of the script for later logging
ScriptName="append prefix here as needed - Check and Rename Machine Based On EA Value"
#
###############################################################################################################################################
# 
# SCRIPT CONTENTS - DO NOT MODIFY BELOW THIS LINE
#
###############################################################################################################################################
#
# Defining Functions
#
###############################################################################################################################################
#
# Data Gathering Function
#
GatherData(){
#
## This gets the Mac's current name
macName=$(scutil --get ComputerName)
#
## This gets the Mac's Serial Number
serial=$(system_profiler SPHardwareDataType | grep "Serial Number" | awk '{print $4}')
#
## This gets the Target Computer Name (Extension Attribute) From The JAMF Object Matching the Serial Number of the Machine
TargetComputerName=$(/usr/bin/curl -s -u ${apiUser}:${apiPass} -H "Accept: application/xml" "${apiURL}/JSSResource/computers/serialnumber/${serial}" | /usr/bin/xpath '/computer/extension_attributes/extension_attribute[name="Target Computer Name"]/value/text()' 2>/dev/null)
#
## This Authenticates against the JAMF API with the Provided details and obtains an Authentication Token
rawtoken=$(curl -s -u ${apiUser}:${apiPass} -X POST "${apiURL}/uapi/auth/tokens" | grep token)
rawtoken=${rawtoken%?};
token=$(echo $rawtoken | awk '{print$3}' | cut -d \" -f2)
#
## This Searches the Preload Inventory Table looking for the Serial Number of the machine
#
preloadEntryA=$(curl -s -X GET "https://huntsworth.jamfcloud.com/uapi/v1/inventory-preload?page=0&size=100&sort=id%3Aasc" -H 'Authorization: Bearer '$token'' | grep -B 1 ${serial})
preloadEntryB=$(curl -s -X GET "https://huntsworth.jamfcloud.com/uapi/v1/inventory-preload?page=0&size=100&sort=id%3Aasc" -H 'Authorization: Bearer '$token'' | grep -A 4 ${serial})
#
## This Searches the Preload Inventory Entry for the Machines Entry ID
preloadEntryID=$(echo $preloadEntryA | awk -F ',' '{print $1 FS ""}' | rev | cut -c 2- | rev | cut -c 8-)
#
## This Searches the Preload Inventory Entry for the Machines Serial Number looking for the presence of any Extension Attributes
preloadEAentry=$(echo $preloadEntryB | grep "extensionAttributes")
#
## This Searches the Preload Inventory Entry for the Machines Serial Number looking for the presence of a "Target Computer Name" Extension Attribute
preloadEAentryTCN=$(echo $preloadEntryB | grep "Target Computer Name")
#
## This Searches the Preload Inventory Entry for the Machines Serial Number looking for the Value of a "Target Computer Name" Extension Attribute
preloadEAentryTCNValue=$(echo $preloadEAentryTCN | awk -F 'value' '{print $2 FS ""}' | cut -c 6-  | awk -F '"' '{print $1 FS ""}' | rev | cut -c 2- | rev)
#
## These Loops check the status of the Preload Entries to ensure all parts are present before attempting to process them
#
if [ "$preloadEntryB" == "" ]
    then
        preloadEntryPresent=Not-Present
    else
        preloadEntryPresent=Present
        #        

        if [ "$preloadEntryID" == "" ]
            then
                preloadEntryIDPresent=Not-Present
            else
                preloadEntryIDPresent=Present
                #
                if [ "$preloadEAentry" == "" ]
                    then
                        preloadEAentryPresent=Not-Present
                    else
                        preloadEAentryPresent=Present
                        #
                        if [ "$preloadEAentryTCN" == "" ]
                            then
                                preloadEAentryTCNPresent=Not-Present
                            else
                                preloadEAentryTCNPresent=Present
                                #
                                if [ "$preloadEAentryTCNValue" == "" ]
                                    then
                                        preloadEAentryTCNValuePresent=Not-Present
                                    else
                                        preloadEAentryTCNValuePresent=Present
                                fi
                        fi
                fi
        fi
fi
#
}
#
###############################################################################################################################################
#
# Check Function
#
Check(){
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
## Outputs Current Computer Name
/bin/echo Current Computer Name = $macName
#
## Outputs Computers Serial Number
/bin/echo Computer Serial Number = $serial
#
## Outputs Target Computer Name
/bin/echo Target Computer Name = $TargetComputerName
#
## Outputs Status of Preload Inventory Entry if present
if [ "$preloadEntryB" != "" ]
    then
        /bin/echo Preload Inventory Entry for Serial Number $serial is $preloadEntryPresent
        #
        if [ "$preloadEntryID" != "" ]
            then
                /bin/echo Preload Inventory Entry ID Serial Number $serial is $preloadEntryID
                #
                if [ "$preloadEAentry" != "" ]
                    then
                        ## Outputs Status of Preload Inventory EA Entry if present
                        /bin/echo Preload Inventory EA Entry for Serial Number $serial is $preloadEAentryPresent
                        ## Outputs Status of Preload Inventory EA "Target Computer Name" Entry if present
                        if [ "$preloadEAentryTCN" != "" ]
                            then
                                /bin/echo Preload Inventory EA '"'Target Computer Name'"' Entry for Serial Number $serial is $preloadEAentryTCNPresent
                                ## Outputs Preload Inventory EA "Target Computer Name" Value if present
                                if [ "$preloadEAentryTCNValue" != "" ]
                                    then
                                        /bin/echo Preload Inventory EA '"'Target Computer Name'"' Entry for Serial Number $serial = $preloadEAentryTCNValue
                                    else
                                        /bin/echo Preload Inventory EA '"'Target Computer Name'"' Entry for Serial Number $serial is $preloadEAentryTCNValuePresent
                                fi
                            else
                                /bin/echo Preload Inventory EA '"'Target Computer Name'"' Entry for Serial Number $serial is $preloadEAentryTCNPresent
                        fi
                    else
                        /bin/echo Preload Inventory EA Entry for Serial Number $serial is $preloadEAentryPresent
                fi
        fi
fi
#
}
#
###############################################################################################################################################
#
# Section End Function
#
SectionEnd(){
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
# Outputting a Dotted Line for Reporting Purposes
/bin/echo  -----------------------------------------------
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
}
#
###############################################################################################################################################
#
# Script End Function
#
ScriptEnd(){
#
# Outputting a Blank Line for Reporting Purposes
#/bin/echo
#
/bin/echo Ending Script '"'$ScriptName'"'
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
# Outputting a Dotted Line for Reporting Purposes
/bin/echo  -----------------------------------------------
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
}
#
###############################################################################################################################################
#
# End Of Function Definition
#
###############################################################################################################################################
#
# Beginning Processing
#
###############################################################################################################################################
#
# Outputting a Blank Line for Reporting Purposes
/bin/echo
#
SectionEnd
#
/bin/echo "Grabbing current Values"
GatherData
#
SectionEnd
#
/bin/echo "Checking current Values"
Check
#
SectionEnd
#
## Now compare the Extension Attribute value with the current computer name
if [ ! -z "$TargetComputerName" ]
    then
        if [[ "$macName" != "$TargetComputerName" ]]
            then
                ## Rename the Mac to the assigned name
                /bin/echo Renaming Machine to $TargetComputerName
                /usr/local/bin/jamf setComputerName -name "$TargetComputerName"
                dscacheutil -flushcache
                #
                if [ "$preloadEntryB" != "" ]
                    then
                        if [[ "$preloadEAentryTCNValue" != "$TargetComputerName" ]]
                            then
                                /bin/echo New Machine Name and Preload Inventory EA "Target Computer Name" Entry for Serial Number $serial Do Not Match 
                                /bin/echo Deleting Preload Inventory Record ID $preloadEntryID
                                DeleteOutcome=$(curl -s -X DELETE -H 'Authorization: Bearer '$token'' -H "accept: application/json" -H "Content-Type: application/json" https://huntsworth.jamfcloud.com/uapi/v1/inventory-preload/$preloadEntryID)
                                DeleteOutput=$(/bin/echo $DeleteOutcome | grep error)
                                if [ "$DeleteOutput" != "" ]
                                    then
                                        echo $DeleteOutput
                                fi        
                                #
                                /bin/echo Uploading Preload Inventory Entry
                                UploadOutcome=$(curl -s -X POST "https://huntsworth.jamfcloud.com/uapi/v1/inventory-preload" -H 'Authorization: Bearer '$token'' "accept: application/json" -H "Content-Type: application/json" -d "{ \"id\": 0, \"serialNumber\": \"$serial\", \"deviceType\": \"Computer\", \"extensionAttributes\": [ { \"name\": \"Target Computer Name\", \"value\": \"$TargetComputerName\" } ]}")
                                UploadOutput=$(/bin/echo $UploadOutcome | grep error)
                                if [ "$UploadOutput" != "" ]
                                    then
                                        echo $UploadOutput
                                fi        
                            else
                                /bin/echo New Machine Name and Preload Inventory EA "Target Computer Name" Entry for Serial Number $serial Match
                        fi
                        #
                    else
                        /bin/echo Uploading Preload Inventory Entry
                        UploadOutcome=$(curl -s -X POST "https://huntsworth.jamfcloud.com/uapi/v1/inventory-preload" -H 'Authorization: Bearer '$token'' "accept: application/json" -H "Content-Type: application/json" -d "{ \"id\": 0, \"serialNumber\": \"$serial\", \"deviceType\": \"Computer\", \"extensionAttributes\": [ { \"name\": \"Target Computer Name\", \"value\": \"$TargetComputerName\" } ]}")
                        UploadOutput=$(/bin/echo $UploadOutcome | grep error)
                        if [ "$UploadOutput" != "" ]
                            then
                                echo $UploadOutput
                        fi        
                fi
                #
                SectionEnd
                #
                ## Re-Checking Machine Name
                /bin/echo "Grabbing New Values"
                GatherData
                # 
                SectionEnd
                #
                /bin/echo "Checking New Values"
                Check
                #               
                SectionEnd
                #
                ScriptEnd
                #
                exit 0
                #
            else
                /bin/echo MATCH > /var/JAMF/Name+TargetName-Match.txt
                /bin/echo "Mac name already matches assigned name. Writing Marker File"
                /bin/echo "/var/JAMF/Name+TargetName-Match.txt"
                # 
                ScriptEnd
                #
                exit 0
        fi
    else
        #
        /bin/echo "Could not get assigned name from computer record"
        #
        ScriptEnd
        #
        exit 1
fi
#
ScriptEnd
