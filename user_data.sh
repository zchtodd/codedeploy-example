#!/bin/bash
yum update -y
yum -y install ruby
yum -y install wget
cd /home/ec2-user
wget https://aws-codedeploy-us-east-2.s3.us-east-2.amazonaws.com/latest/install
chmod +x ./install
./install auto

yum install -y amazon-cloudwatch-agent

cat >> /opt/aws/amazon-cloudwatch-agent/bin/config_temp.json <<EOF
{
    "agent": {
            "metrics_collection_interval": 60,
            "run_as_user": "root"
    },
    "metrics": {
            "metrics_collected": {
                    "disk": {
                            "measurement": [
                                    "used_percent"
                            ],
                            "metrics_collection_interval": 60,
                            "resources": [
                                    "*"
                            ]
                    },
                    "mem": {
                            "measurement": [
                                    "mem_used_percent"
                            ],
                            "metrics_collection_interval": 60
                    }
            }
    }
}
EOF

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
