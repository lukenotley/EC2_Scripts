##Incoming Parameters
Param(
	[parameter(mandatory=$true)][string]$SecGroupName,
	[parameter(mandatory=$true)][string]$SecGroupDescription,
	[parameter(mandatory=$true)][array]$TrustedIPs,
	[parameter(mandatory=$true)][array]$Ports
	)

#Create the Security Group
$ec2securitygrp = New-EC2SecurityGroup -GroupName $SecGroupName -GroupDescription $SecGroupDescription

#Allow Required TCP Ports from Trusted IPs
foreach ($p in $Ports)
	{ 
	foreach ($ip in $TrustedIPs) 	
		{ 
		Grant-EC2SecurityGroupIngress -GroupId $ec2securitygrp -IpProtocol tcp -FromPort $p -ToPort $p -CidrIp $ip
		}
	}