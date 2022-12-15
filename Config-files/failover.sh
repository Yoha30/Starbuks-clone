EIP=3.28.247.74 # Elastic public IP
INSTANCE_ID=i-010d3d18ec00cd116 # ID of the backup server

/usr/bin/aws ec2 disassociate-address --public-ip $EIP
/usr/bin/aws ec2 associate-address --public-ip $EIP --instance-id $INSTANCE_ID
