#!/bin/bash
#
###############################################################################################################################################
#
# ABOUT THIS PROGRAM
#
#	ZeroName.sh
#	https://github.com/Headbolt/ZeroName
#
#   This Script is designed for use in JAMF
#
#   - This script will ...
#		Grab the Machines name Locally
#		Grab the Machines Target name from the JAMF Extension Attribute
#			Grab the Machines Entry in the Preload Inventory Table if it exists - From V1.1 Onwards
#		Rename if needed
#			Update or create the Machines Entry in the Preload Inventory Table if it needed - From V1.1 Onwards
#
###############################################################################################################################################
#
# HISTORY
#
#	Version: 1.6 - 02/08/2021
#
#	- 13/03/2018 - V1.0 - Created by Headbolt
#
#	- 11/10/2019 - V1.1 - Updated by Headbolt
#							Support added for Preload Inventory Table
#							More comprehensive error checking and notation
#	- 17/10/2019 - V1.2 - Updated by Headbolt
#							Further Updates to allow for both standard and Preload Building Entries
#							Also a few Diagnostic Lines idded that can be uncommented for troubleshooting
#	- 18/10/2019 - V1.3 - Updated by Headbolt
#							Few Tweaks to Logic loops to fix a bug or 2 and also to improve a few bits
#	- 15/05/2020 - V1.4 - Updated by Headbolt
#							Few Tweaks cope with recent Updates in JAMF that change what is Returned by the Preload Invetory Query
#	- 13/11/2020 - V1.5 - Updated by Headbolt
#							Minor Tweak to cope Big Sur and Above requiring different arguments for XPATH
#	- 02/08/2021 - V1.6 - Updated by Headbolt
#							Minor Tweak to cope with extended numbers of Inventory Preload records being returned
#							Also an issue with 1 of the Variables
#
###############################################################################################################################################
#
# DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
# Variables used by this script.
#
# Grab the username for API Login from JAMF variable #4 eg. username
apiUser=$4
#
# Grab the password for API Login from JAMF variable #5 eg. password
apiPass=$5
#
# Grab the first part of the API URL from JAMF variable #6 eg. https://COMPANY-NAME.jamfcloud.com
apiURL=$6
#
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
## This gets the Mac's MAJOR OS Version
OS=$(sw_vers | grep ProductVersion | cut -c 17- | cut -c -2)
#
if [ "$OS" == "10" ] # Checks OS, Big Sur and Above XPATH needs a -e, Pre Big Sur it cant have it
	then
		XP="/usr/bin/xpath"
	else
		XP="/usr/bin/xpath -e"
fi
#
## This gets the Mac's current name
macName=$(scutil --get ComputerName)
#
## This gets the Mac's Serial Number
serial=$(system_profiler SPHardwareDataType | grep "Serial Number" | awk '{print $4}')
#
## This gets the Target Computer Name (Extension Attribute) From The JAMF Object Matching the Serial Number of the Machine
TargetComputerName=$(/usr/bin/curl -s -u ${apiUser}:${apiPass} -H "Accept: application/xml" "${apiURL}/JSSResource/computers/serialnumber/${serial}" | ${XP} '/computer/extension_attributes/extension_attribute[name="Target Computer Name"]/value/text()' 2>/dev/null)
#
## This gets the Building Name From The JAMF Object Matching the Serial Number of the Machine
Building=$(/usr/bin/curl -s -u ${apiUser}:${apiPass} -H "Accept: application/xml" "${apiURL}/JSSResource/computers/serialnumber/${serial}" | ${XP} '/computer/location/building/text()' 2>/dev/null)
#
## This Authenticates against the JAMF API with the Provided details and obtains an Authentication Token
rawtoken=$(curl -s -u ${apiUser}:${apiPass} -X POST "${apiURL}/uapi/auth/tokens" | grep token)
rawtoken=${rawtoken%?};
token=$(echo $rawtoken | awk '{print$3}' | cut -d \" -f2)
#
## This Searches the Preload Inventory Table looking for the Serial Number of the machine
preloadEntryA=$(curl -s -X GET "${apiURL}/uapi/v1/inventory-preload?page=0&size=10000&sort=id%3Aasc" -H 'Authorization: Bearer '$token'' | grep -B 1 ${serial})
preloadEntryB=$(curl -s -X GET "${apiURL}/uapi/v1/inventory-preload?page=0&size=10000&sort=id%3Aasc" -H 'Authorization: Bearer '$token'' | grep -A 24 ${serial})
#
## This Searches the Preload Inventory Entry for the Machines Entry ID
preloadEntryID=$(echo $preloadEntryA | awk -F ',' '{print $1 FS ""}' | rev | cut -c 2- | rev | cut -c 8-)
#
## This Searches the Preload Inventory Entry for the Building Entry
PreloadBuildingEntry=$(echo $preloadEntryB | awk -F ',' '{print $8 FS ""}' | rev | cut -c 3- | rev | cut -c 16-)
#
# This Searches the Preload Inventory Entry for the Machines Serial Number looking for the presence of any Extension Attributes
preloadEAentry=$(echo $preloadEntryB | grep "extensionAttributes")
#
## This Searches the Preload Inventory Entry for the Machines Serial Number looking for the presence of a "Target Computer Name" Extension Attribute
preloadEAentryTCN=$(echo $preloadEntryB | grep "Target Computer Name")
#
## This Searches the Preload Inventory Entry for the Machines Serial Number looking for the Value of a "Target Computer Name" Extension Attribute
preloadEAentryTCNValue=$(echo $preloadEAentryTCN | awk -F 'value' '{print $2 FS ""}' | cut -c 6-  | awk -F '"' '{print $1 FS ""}' | rev | cut -c 2- | rev)
#
## These Loops check the status of the Preload Entries to ensure all parts are present before attempting to process them
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
				if [ "$PreloadBuildingEntry" == "" ]
					then
						PreloadBuildingEntryPresent=Not-Present
					else
						PreloadBuildingEntryPresent=Present
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
## Outputs Current Building
/bin/echo Building this Machine is currently assigned to = $Building
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
# DIAG	/bin/echo Preload Inventory Entry for Serial Number $serial is $preloadEntryPresent
		#
		if [ "$preloadEntryID" != "" ]
			then
				/bin/echo Preload Inventory Entry ID Serial Number $serial is $preloadEntryID
				#
				if [ "$PreloadBuildingEntry" != "" ]
					then
						/bin/echo Preload Inventory '"'Building'"' Entry for Serial Number $serial = $PreloadBuildingEntry
						#
						if [ "$preloadEAentry" != "" ]
							then
								## Outputs Status of Preload Inventory EA Entry if present
# DIAG							/bin/echo Preload Inventory EA Entry for Serial Number $serial is $preloadEAentryPresent
								## Outputs Status of Preload Inventory EA "Target Computer Name" Entry if present
								if [ "$preloadEAentryTCN" != "" ]
									then
# DIAG							    	/bin/echo Preload Inventory EA '"'Target Computer Name'"' Entry for Serial Number $serial is $preloadEAentryTCNPresent
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
fi
#
}
#
###############################################################################################################################################
#
# Write To Preload Inventory Table Function
#
PreLoadWrite(){
#
if [ "$preloadEntryB" != "" ]
	then
		# Set a default flags to Upload a Preload Inventory entry
		PreloadUploadName="YES"
		PreloadUploadBuilding="YES"
        # Set a default flag to Delete exiting Preload Inventory entry 
		PreloadDelete="NO"
		#
		if [[ "$preloadEAentryTCNValue" != "$TargetComputerName" ]]
			then
# DIAG			/bin/echo New Machine Name and Preload Inventory EA "Target Computer Name" Entry for Serial Number $serial Do Not Match 
				# A Preload Inventory entry clearly exists, these cannot be update
				# so we set a flag to delete the existing record before uploading an updated one
				PreloadDelete="YES"
			else
                PreloadUploadName="NO"
# DIAG			/bin/echo New Machine Name and Preload Inventory EA "Target Computer Name" Entry for Serial Number $serial Match
		fi
		#
        
        echo Building = $Building
		echo PreloadBuildingEntry = $PreloadBuildingEntry

        
		if [[ "$Building" != "$PreloadBuildingEntry" ]]
			then
# DIAG			/bin/echo '"'Building'"' Entry and Preload Inventory '"'Building'"' Entry for Serial Number $serial Do Not Match 
				# A Preload Inventory entry clearly exists, these cannot be update
				# so we set a flag to delete the existing record before uploading an updated one
				PreloadDelete="YES"
			else
				PreloadUploadBuilding="NO"
# DIAG			/bin/echo '"'Building'"' Entry and Preload Inventory '"'Building'"' Entry for Serial Number $serial Match
		fi
		#
		if [ "$PreloadDelete" == "YES" ]
			then
				/bin/echo Deleting Preload Inventory Record ID $preloadEntryID
				DeleteOutcome=$(curl -s -X DELETE -H 'Authorization: Bearer '$token'' -H "accept: application/json" -H "Content-Type: application/json" https://huntsworth.jamfcloud.com/uapi/v1/inventory-preload/$preloadEntryID)
				DeleteOutput=$(/bin/echo $DeleteOutcome | grep error)
				if [ "$DeleteOutput" != "" ]
					then
						echo $DeleteOutput
				fi
		fi
	else
    	Upload="YES"
fi
#
if [ "$PreloadUploadName" == "YES" ]
	then
		Upload="YES"
fi
#
if [ "$PreloadUploadBuilding" == "YES" ]
	then
		Upload="YES"
fi
#
if [ "$Upload" == "YES" ]
	then
        /bin/echo Uploading Preload Inventory Entry
		UploadOutcome=$(curl -s -X POST "https://huntsworth.jamfcloud.com/uapi/v1/inventory-preload" -H 'Authorization: Bearer '$token'' "accept: application/json" -H "Content-Type: application/json" -d "{ \"id\": 0, \"serialNumber\": \"$serial\", \"building\": \"$Building\", \"deviceType\": \"Computer\", \"extensionAttributes\": [ { \"name\": \"Target Computer Name\", \"value\": \"$TargetComputerName\" } ]}")
		UploadOutput=$(/bin/echo $UploadOutcome | grep error)
		if [ "$UploadOutput" != "" ]
			then
				/bin/echo $UploadOutput
		fi  
fi
#
SectionEnd
#
## Re-Checking Machine Name
/bin/echo "Grabbing New Values"
GatherData
SectionEnd
#
/bin/echo "Checking New Values"
Check
SectionEnd
#
ScriptEnd
exit 0
#
}
#
###############################################################################################################################################
#
# Section End Function
#
SectionEnd(){
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
/bin/echo  ----------------------------------------------- # Outputting a Dotted Line for Reporting Purposes
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
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
/bin/echo # Outputting a Blank Line for Reporting Purposes
#
/bin/echo  ----------------------------------------------- # Outputting a Dotted Line for Reporting Purposes
#
/bin/echo # Outputting a Blank Line for Reporting Purposes
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
/bin/echo # Outputting a Blank Line for Reporting Purposes
SectionEnd
#
/bin/echo "Grabbing current Values"
GatherData
SectionEnd
#
/bin/echo "Checking current Values"
Check
#
# Set The Preload Update Flag to No, it will be set to yes later if required
PreloadUpdate=NO
#
# Check Preload Inventory Target ComputerName Entry
if [ ! -z "$TargetComputerName" ]
	then
		# Check if Machine Name and Preload Inventory Target Computer Name Entry match
    	if [[ "$macName" != "$TargetComputerName" ]]
        	then
        		## Rename the Mac to the assigned name
				/bin/echo Renaming Machine to $TargetComputerName
           		/usr/local/bin/jamf setComputerName -name "$TargetComputerName"
                dscacheutil -flushcache
                #
				# A change has been made, or a difference between actual and Preload Inventory values is detected
				# Setting a flag to update the Preload Inventory Entry to match
				PreloadUpdate=YES
			else
				SectionEnd
	   		    /bin/echo MATCH > /var/JAMF/Name+TargetName-Match.txt
				/bin/echo "Mac name already matches assigned name."
				/bin/echo "Writing Marker File"
				/bin/echo "/var/JAMF/Name+TargetName-Match.txt"
		fi
	else
		#
		/bin/echo "Could not get assigned name from computer record"
		ScriptEnd
		exit 1
fi
#
# Check Preload Inventory Building Entry
if [ "$PreloadBuildingEntryPresent" == "Present" ]
	then
		# Check if Building Entry and Preload Inventory Building Entry match
    	if [[ "$Building" != "$PreloadBuildingEntry" ]]
        	then
				/bin/echo "A difference between the Building value, and the Preload Inventory Building value is detected"
				/bin/echo "Triggering an update the Preload Inventory Entry so Values match"
				# A change has been made, or a difference between actual and Preload Inventory values is detected
				# Setting a flag to update the Preload Inventory Entry to match
				PreloadUpdate=YES
			else
				SectionEnd
	   		    /bin/echo MATCH > /var/JAMF/buildingName+PIbuildingName-Match.txt
				/bin/echo "Building value, and the Preload Inventory Building value already matches assigned name."
				/bin/echo "Writing Marker File"
				/bin/echo "/var/JAMF/buildingName+PIbuildingName-Match.txt"
		fi
	else
	    #
		/bin/echo "PreloadBuildingEntry not present, triggering its creation/update"
		PreloadUpdate=YES
fi
#
if [[ "$PreloadUpdate" == "YES" ]]
	then
		SectionEnd
		PreLoadWrite
fi
#
SectionEnd
ScriptEnd
