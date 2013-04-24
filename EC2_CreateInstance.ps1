<#
.DESCRIPTION
	Creates an Instance from an AMI Description in user specified region where it exists.
	Useful to keep track of Amazon AMI ID's since they change every time updates occur.

.NOTES
    PREREQUISITES:
	1) Download the SDK library from http://aws.amazon.com/sdkfornet/
	2) Have the AccessKey and SecretKey handy
	7) Know the name of the  appropriate keyname for Region to $RunInstancesRequest.KeyName

	API Reference:http://&domain;/AWSEC2/latest/APIReference/query-apis.html

.EXAMPLE
	.\EC2_CreateInstance.ps1 -EC2AccessKey ThisIsMyAccessKey -EC2SecretKey ThisIsMySecretKey -matchDescription 'Windows_Server-2008-R2-English-64Bit-2012' -RegionName us-east-1 -InstanceType t1.micro -InstancesToLaunch 1 -SecurityGroup Default -KeyPairName MyRegionalCertificateName -NameToTagCreatedInstance "This is my tag"

	.\EC2_CreateInstance.ps1 -EC2AccessKey ThisIsMyAccessKey -EC2SecretKey ThisIsMySecretKey -matchDescription 'Windows_Server-2008-R2-English-64Bit-2012' -RegionName us-east-1 -InstanceType t1.micro
#>

##Incoming Parameters
Param(
	[parameter(mandatory=$true)][string]$EC2AccessKey,
	[parameter(mandatory=$true)][string]$EC2SecretKey,
	[parameter(mandatory=$true)][string]$matchDescription,
	[parameter(mandatory=$true)][string]$RegionName,
	[parameter(mandatory=$true)][string]$Placement_AvailabilityZone,
	[parameter(mandatory=$true)][string]$InstanceType,
	[parameter(mandatory=$false)][string]$InstancesToLaunch = 1,
	[parameter(mandatory=$false)][string]$SecurityGroup = "Default",
	[parameter(mandatory=$true)][string]$KeyPairName,
	[parameter(mandatory=$false)][string]$NameToTagCreatedInstance = ""
	)
##Creates and defines the objects for the Account
$AccountInfo = New-Object PSObject -Property @{
	EC2AccessKey = $EC2AccessKey
	EC2SecretKey = $EC2SecretKey
}

##Creates and defines the objects for the Instance Request
$Instance = New-Object PSObject -Property @{
	RegionName = $RegionName
	matchDescription = $matchDescription
	SecurityGroup = $SecurityGroup
	InstancesToLaunch = $InstancesToLaunch
	InstanceType = $InstanceType
	KeyPairName = $KeyPairName
	NameToTagCreatedInstance = $NameToTagCreatedInstance
}

##Defines Variables
$TagKey = "Name"	#To add a custom tag, change this value
$ListOfQueriedAMIs = @()	#Creates an array to store all the found AMI details
$ListOfCreatedInstances = @()	#Creates an array to store all the created Instance details


##Removes unused variables
Remove-Variable EC2AccessKey
Remove-Variable EC2SecretKey
Remove-Variable RegionName
Remove-Variable matchDescription
Remove-Variable SecurityGroup
Remove-Variable InstancesToLaunch
Remove-Variable InstanceType
Remove-Variable KeyPairName

##Loads the SDK information into memory
$SDKLibraryLocation = dir C:\Windows\Assembly -Recurse -Filter "AWSSDK.dll"
$SDKLibraryLocation = $SDKLibraryLocation.FullName
Add-Type -Path $SDKLibraryLocation

#Sets the end-point to the specified region
$config = New-Object Amazon.EC2.AmazonEC2Config
$config.set_ServiceURL("https://ec2."+$Instance.RegionName+".amazonaws.com")	#Sets the region

#Sets the Client property for making calls -- queries across all regions (uses default end-point)
$EC2Client=[Amazon.AWSClientFactory]::CreateAmazonEC2Client($AccountInfo.EC2AccessKey,$AccountInfo.EC2SecretKey,$config)


########################
###### FUNCTIONS #######

#Launches an Instance from an AMI
function createInstance
{	param([string]$amiid,[string]$instancetype,[string]$count,[string]$keypair,[string]$securitygroup)

	#Required Information
	$RunInstancesRequest = New-Object Amazon.EC2.Model.RunInstancesRequest
	$RunInstancesRequest.ImageId = $amiid
	$RunInstancesRequest.MaxCount = $count
	$RunInstancesRequest.MinCount = $count
	$RunInstancesRequest.Placement.AvailabilityZone = $Placement_AvailabilityZone
	$RunInstancesRequest.SecurityGroup.Add($securitygroup)
	if ($keypair -ne ""){$RunInstancesRequest.KeyName=$keypair} #If there is a keypair value, uses it
	$RunInstancesRequest.InstanceType = $instancetype

	#Submits the request
	$RunInstancesResponse = $EC2Client.RunInstances($RunInstancesRequest)

	#Declares Array for return values
	$runninginstances = @()

	Foreach ($instance in $RunInstancesResponse.RunInstancesResult.Reservation.RunningInstance)
	{
			##Adds each created instance to an Array to return
			$object = New-Object psObject $instance.instanceID
			$runninginstances +=$object	#Adds item to array with Region information
	}
	return $runninginstances
}

#Adds tag to the instance, which is visible via the AWS Console
function addTag
{	param([string]$instanceid,[string]$key,[string]$value)
	#Creates the tag objects
	$Tag = new-object amazon.EC2.Model.Tag
	$Tag.Key = $key	#Tags the instance with a Name, which is visible in the AWS EC2 Console, or via API query
	$Tag.Value = $value	#Records the AMI Name into the Tag Name value

	#Prepares the tag request
	$CreateTagRequest = new-object amazon.EC2.Model.CreateTagsRequest
	$CreateTagRequest.Tag.Add($Tag)	#Bundles the Tag(s) into a single Tag Request
	$CreateTagRequest.ResourceId.Add($instanceid)

	#Submits the request
	$tagRequest = $EC2Client.CreateTags($CreateTagRequest)	#Adds the Tag to the earlier created instance

	return $tagRequest
}

##################################
#START OF SCRIPT
##################################

Write-Output $Region.RegionName	#Displays the Region name

#Creates filter to limit the return of objects
$filter = New-Object Amazon.EC2.Model.Filter
$filter.Name = "name"
$filter.Value.Add("*"+ $Instance.matchDescription+"*")	#Wildcard search for Description

#Creates object for requesting list of AMIs
$DescribeImagesRequest = New-Object Amazon.EC2.Model.DescribeImagesRequest
$DescribeImagesRequest.Filter.Add($filter)
$DescribeImagesRequest.Owner.add("amazon")	#Gets all AMI's that were created by Amazon

#Submits the request to obtain list of AMIs
$DescribeImagesResult = $EC2Client.DescribeImages($DescribeImagesRequest)

#Checks to see if any AMIs were returned
If ($DescribeImagesResult.DescribeImagesResult.Image.Count -lt 1){return " No results found for " + $Instance.matchDescription}

#Loops through all the AMIs and copies information into $ListOfALLAMIs array
#Foreach ($item in $DescribeImagesResult.DescribeImagesResult.Image | Where {$_.Name -match $Instance.matchDescription -and $_.Visibility -like "Public"})

Foreach ($item in $DescribeImagesResult.DescribeImagesResult.Image)
{
		##Adds each AMI found to an Array for later retrieval for launching instances
		$object = New-Object psObject $item
		Add-Member -InputObject $object -MemberType noteproperty -Name Region -Value $Instance.RegionName
		$ListOfQueriedAMIs +=$object	#Adds item to array with Region information
}

##Outputs details to console
Write-Host "Search Results for *"$Instance.matchDescription "*"
$ListOfQueriedAMIs | Format-Table -Property Region,name,ImageId,Architecture -AutoSize	#Displays the found AMIs in a table

#Calculates total number of instances that will be launched
$count = [int]$Instance.InstancesToLaunch * [int]$DescribeImagesResult.DescribeImagesResult.Image.Count

#Prompts user to create instance(s)
Write-Host "Total instance(s) to create " $count
$input = Read-Host "Enter 'y' to launch Instance(s) from the above AMI(s):"
if ($input -eq "y")
{
	Foreach ($AMI in $ListOfQueriedAMIs)
	{
		Write-Host "Creating Instance from AMI " $AMI.ImageId
		$ListOfCreatedInstances += $InstanceID = createInstance $AMI.ImageId $Instance.InstanceType $Instance.InstancesToLaunch $Instance.KeyPairName $Instance.SecurityGroup
			
		#Loops through all the instances that were created and adds the Name Tag information; this is visible in the AWS EC2 Console
		Foreach ($createdInstance in $ListOfCreatedInstances)
		{
			#Runs if the optional tag value exists
			if ($Instance.NameToTagCreatedInstance -ne ""){$result = addTag $createdInstance $TagKey $Instance.NameToTagCreatedInstance}
		}
	}
	##Exports to table for display
	Write-Host
	Write-Host "Instances Created"
	$ListOfCreatedInstances.SyncRoot | Format-Table
}