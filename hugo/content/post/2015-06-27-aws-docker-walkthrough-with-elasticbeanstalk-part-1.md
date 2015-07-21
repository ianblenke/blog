+++
date = "2015-06-27T13:14:08-04:00"
draft = false
title = "AWS Docker Walkthrough with ElasticBeanstalk: Part 1"
description = "Preparing a VPC for your ElasticBeanstalk environments"
#date_formatted = "Jun 27, 2015"
#comments = true
#comment = "HowTo use a CloudFormation to create a VPC"
categories = ["amazon","aws","elasticbeanstalk","docker","ecs","cloudformation ebextensions"]
+++
While deploying docker containers for immutable infrastructure on AWS ElasticBeanstalk,
I've learned a number of useful tricks that go beyond the official Amazon documentation.

This series of posts are an attempt to summarize some of the useful bits that may benefit
others facing the same challenges.

---

# Part 1 : Preparing a VPC for your ElasticBeanstalk environments

---

### Step 1 : Prepare your AWS development environment.

On OS/X, I install [homebrew](http://brew.sh), and then:

```bash
brew install awscli
```

On Windows, I install [chocolatey](https://chocolatey.org/) and then:

```bash
choco install awscli
```

Because `awscli` is a python tool, on either of these, or on the various Linux distribution flavors, we can also avoid native package management and alternatively use python `easyinstall` or `pip` directly:

```bash
pip install awscli
```

You may (or may not) need to prefix that pip install with `sudo`, depending. ie:

```bash
sudo pip install awscli
```

These tools will detect if they are out of date when you run them. You may eventually get a message like:

```
Alert: An update to this CLI is available.
```

When this happens, you will likely want to either upgrade via homebrew:

```bash
brew update & brew upgrade awscli
```

or, more likely, upgrade using pip directly:

```bash
pip install --upgrade awscli
```

Again, you may (or may not) need to prefix that pip install with `sudo`, depending. ie:

```bash
sudo pip install --upgrade awscli
```

For the hardcore Docker fans out there, this is pretty trivial to run as a container as well. See [CenturyLinkLabs/docker-aws-cli](https://github.com/CenturyLinkLabs/docker-aws-cli) for a good example of that. Managing an aws config file requires volume mapping, or passing `-e AWS_ACCESS_KEY_ID={redacted} -e AWS_SECRET_ACCESS_KEY={redacted}`. There are various guides to doing this out there. This will not be one of them ;)

### Step 2: Prepare your AWS environment variables

If you haven't already, [prepare for AWS cli access](http://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html#config-settings-and-precedence).

You can now configure your `~/.aws/config` by running:

    aws configure

This will create a default configuration.

I've yet to work with any company with only one AWS account though. You will likely find that you need to support managing multiple AWS configuration profiles.

Here's an example `~/.aws/config` file with multiple profiles:

```
[default]
output = json
region = us-east-1

[profile aws-dev]
AWS_ACCESS_KEY_ID={REDACTED}
AWS_SECRET_ACCESS_KEY={REDACTED}

[profile aws-prod]
AWS_ACCESS_KEY_ID={REDACTED}
AWS_SECRET_ACCESS_KEY={REDACTED}
```

You can create this by running:

```bash
$ aws configure --profile aws-dev
AWS Access Key ID [REDACTED]: YOURACCESSKEY
AWS Secret Access Key [REDACTED]: YOURSECRETKEY
Default region name [None]: us-east-1
Default output format [None]: json
```

Getting in the habit of specifying `--profile aws-dev` is a bit of a reassurance that you're provisioning resources into the correct AWS account, and not sullying AWS cloud resources between VPC environments.

### Step 3: Preparing a VPC

Deploying anything to AWS EC2 Classic instances these days is to continue down the path of legacy maintenance.

For new ElasticBeanstalk deployments, a VPC should be used.

The easiest/best way to deploy a VPC is to use a [CloudFormation template](http://aws.amazon.com/cloudformation/aws-cloudformation-templates/). 

Below is a VPC CloudFormation that I use for deployment:

```json
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "MyApp VPC",
  "Parameters" : {
    "Project" : {
      "Description" : "Project name to tag resources with",
      "Type" : "String",
      "MinLength": "1",
      "MaxLength": "16",
      "AllowedPattern" : "[a-z]*",
      "ConstraintDescription" : "any alphabetic string (1-16) characters in length"
    },
    "Environment" : {
      "Description" : "Environment name to tag resources with",
      "Type" : "String",
      "AllowedValues" : [ "dev", "qa", "prod" ],
      "ConstraintDescription" : "must be one of dev, qa, or prod"
    },
    "SSHFrom": {
      "Description" : "Lockdown SSH access (default: can be accessed from anywhere)",
      "Type" : "String",
      "MinLength": "9",
      "MaxLength": "18",
      "Default" : "0.0.0.0/0",
      "AllowedPattern" : "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
      "ConstraintDescription" : "must be a valid CIDR range of the form x.x.x.x/x."
    },
    "VPCNetworkCIDR" : {
      "Description": "The CIDR block for the entire VPC network",
      "Type": "String",
      "AllowedPattern" : "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
      "Default": "10.114.0.0/16",
      "ConstraintDescription" : "must be an IPv4 dotted quad plus slash plus network bit length in CIDR format"
    },
    "VPCSubnet0CIDR" : {
      "Description": "The CIDR block for VPC subnet0 segment",
      "Type": "String",
      "AllowedPattern" : "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
      "Default": "10.114.0.0/24",
      "ConstraintDescription" : "must be an IPv4 dotted quad plus slash plus network bit length in CIDR format"
    },
    "VPCSubnet1CIDR" : {
      "Description": "The CIDR block for VPC subnet1 segment",
      "Type": "String",
      "AllowedPattern" : "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
      "Default": "10.114.1.0/24",
      "ConstraintDescription" : "must be an IPv4 dotted quad plus slash plus network bit length in CIDR format"
    },
    "VPCSubnet2CIDR" : {
      "Description": "The CIDR block for VPC subnet2 segment",
      "Type": "String",
      "AllowedPattern" : "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})",
      "Default": "10.114.2.0/24",
      "ConstraintDescription" : "must be an IPv4 dotted quad plus slash plus network bit length in CIDR format"
    }
  },
  "Resources" : {
    "VPC" : {
      "Type" : "AWS::EC2::VPC",
      "Properties" : {
        "EnableDnsSupport" : "true",
        "EnableDnsHostnames" : "true",
        "CidrBlock" : { "Ref": "VPCNetworkCIDR" },
        "Tags" : [
          { "Key" : "Name", "Value" : { "Fn::Join": [ "-", [ "vpc", { "Ref": "Project" }, { "Ref" : "Environment" } ] ] } },
          { "Key" : "Project", "Value" : { "Ref": "Project" } },
          { "Key" : "Environment", "Value" : { "Ref": "Environment" } }
        ]
      }
    },
    "VPCSubnet0" : {
      "Type" : "AWS::EC2::Subnet",
      "Properties" : {
        "VpcId" : { "Ref" : "VPC" },
        "AvailabilityZone": { "Fn::Select" : [ 0, { "Fn::GetAZs" : "" } ] },
        "CidrBlock" : { "Ref": "VPCSubnet0CIDR" },
        "Tags" : [
          { "Key" : "Name", "Value" : { "Fn::Join": [ "-", [ "subnet", { "Ref": "Project" }, { "Ref": "Environment" } ] ] } },
          { "Key" : "AZ", "Value" : { "Fn::Select" : [ 0, { "Fn::GetAZs" : "" } ] } },
          { "Key" : "Project", "Value" : { "Ref": "Project" } },
          { "Key" : "Environment", "Value" : { "Ref": "Environment" } }
        ]
      }
    },
    "VPCSubnet1" : {
      "Type" : "AWS::EC2::Subnet",
      "Properties" : {
        "VpcId" : { "Ref" : "VPC" },
        "AvailabilityZone": { "Fn::Select" : [ 1, { "Fn::GetAZs" : "" } ] },
        "CidrBlock" : { "Ref": "VPCSubnet1CIDR" },
        "Tags" : [
          { "Key" : "Name", "Value" : { "Fn::Join": [ "-", [ "subnet", { "Ref": "Project" }, { "Ref": "Environment" } ] ] } },
          { "Key" : "AZ", "Value" : { "Fn::Select" : [ 1, { "Fn::GetAZs" : "" } ] } },
          { "Key" : "Project", "Value" : { "Ref": "Project" } },
          { "Key" : "Environment", "Value" : { "Ref": "Environment" } }
        ]
      }
    },
    "VPCSubnet2" : {
      "Type" : "AWS::EC2::Subnet",
      "Properties" : {
        "VpcId" : { "Ref" : "VPC" },
        "AvailabilityZone": { "Fn::Select" : [ 2, { "Fn::GetAZs" : "" } ] },
        "CidrBlock" : { "Ref": "VPCSubnet2CIDR" },
        "Tags" : [
          { "Key" : "Name", "Value" : { "Fn::Join": [ "-", [ "subnet", { "Ref": "Project" }, { "Ref": "Environment" } ] ] } },
          { "Key" : "AZ", "Value" : { "Fn::Select" : [ 2, { "Fn::GetAZs" : "" } ] } },
          { "Key" : "Project", "Value" : { "Ref": "Project" } },
          { "Key" : "Environment", "Value" : { "Ref": "Environment" } }
        ]
      }
    },
    "InternetGateway" : {
      "Type" : "AWS::EC2::InternetGateway",
      "Properties" : {
        "Tags" : [
          { "Key" : "Name", "Value" : { "Fn::Join": [ "-", [ "igw", { "Ref": "Project" }, { "Ref": "Environment" } ] ] } },
          { "Key" : "Project", "Value" : { "Ref": "Project" } },
          { "Key" : "Environment", "Value" : { "Ref": "Environment" } }
        ]
      }
    },
    "GatewayToInternet" : {
       "Type" : "AWS::EC2::VPCGatewayAttachment",
       "Properties" : {
         "VpcId" : { "Ref" : "VPC" },
         "InternetGatewayId" : { "Ref" : "InternetGateway" }
       }
    },
    "PublicRouteTable" : {
      "Type" : "AWS::EC2::RouteTable",
      "DependsOn" : "GatewayToInternet",
      "Properties" : {
        "VpcId" : { "Ref" : "VPC" },
        "Tags" : [
          { "Key" : "Name", "Value" : { "Fn::Join": [ "-", [ "route", { "Ref": "Project" }, { "Ref" : "Environment" } ] ] } },
          { "Key" : "Project", "Value" : { "Ref": "Project" } },
          { "Key" : "Environment", "Value" : { "Ref": "Environment" } }
        ]
      }
    },
    "PublicRoute" : {
      "Type" : "AWS::EC2::Route",
      "DependsOn" : "GatewayToInternet",
      "Properties" : {
        "RouteTableId" : { "Ref" : "PublicRouteTable" },
        "DestinationCidrBlock" : "0.0.0.0/0",
        "GatewayId" : { "Ref" : "InternetGateway" }
      }
    },
    "VPCSubnet0RouteTableAssociation" : {
      "Type" : "AWS::EC2::SubnetRouteTableAssociation",
      "Properties" : {
        "SubnetId" : { "Ref" : "VPCSubnet0" },
        "RouteTableId" : { "Ref" : "PublicRouteTable" }
      }
    },
    "VPCSubnet1RouteTableAssociation" : {
      "Type" : "AWS::EC2::SubnetRouteTableAssociation",
      "Properties" : {
        "SubnetId" : { "Ref" : "VPCSubnet1" },
        "RouteTableId" : { "Ref" : "PublicRouteTable" }
      }
    },
    "VPCSubnet2RouteTableAssociation" : {
      "Type" : "AWS::EC2::SubnetRouteTableAssociation",
      "Properties" : {
        "SubnetId" : { "Ref" : "VPCSubnet2" },
        "RouteTableId" : { "Ref" : "PublicRouteTable" }
      }
    },
    "InstanceRole": {
      "Type": "AWS::IAM::Role",
      "Properties": {
        "AssumeRolePolicyDocument": {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Principal": {
                "Service": [ "ec2.amazonaws.com" ]
              },
              "Action": [ "sts:AssumeRole" ]
            }
          ]
        },
        "Path": "/",
        "Policies": [
          {
            "PolicyName": "ApplicationPolicy",
            "PolicyDocument": {
              "Version": "2012-10-17",
              "Statement": [
                {
                  "Effect": "Allow",
                  "Action": [
                    "elasticbeanstalk:*",
                    "elastiCache:*",
                    "ec2:*",
                    "elasticloadbalancing:*",
                    "autoscaling:*",
                    "cloudwatch:*",
                    "dynamodb:*",
                    "s3:*",
                    "sns:*",
                    "sqs:*",
                    "cloudformation:*",
                    "rds:*",
                    "iam:AddRoleToInstanceProfile",
                    "iam:CreateInstanceProfile",
                    "iam:CreateRole",
                    "iam:PassRole",
                    "iam:ListInstanceProfiles"
                  ],
                  "Resource": "*"
                }
              ]
            }
          }
        ]
      }
    },
    "InstanceProfile": {
       "Type": "AWS::IAM::InstanceProfile",
       "Properties": {
          "Path": "/",
          "Roles": [ { "Ref": "InstanceRole" } ]
       }
    },
    "VPCSecurityGroup" : {
      "Type" : "AWS::EC2::SecurityGroup",
      "Properties" : {
        "GroupDescription" : { "Fn::Join": [ "", [ "VPC Security Group for ", { "Fn::Join": [ "-", [ { "Ref": "Project" }, { "Ref": "Environment" } ] ] } ] ] },
        "SecurityGroupIngress" : [
          {"IpProtocol": "tcp", "FromPort" : "22",  "ToPort" : "22",  "CidrIp" : { "Ref" : "SSHFrom" }},
          {"IpProtocol": "tcp", "FromPort": "80", "ToPort": "80", "CidrIp": "0.0.0.0/0" },
          {"IpProtocol": "tcp", "FromPort": "443", "ToPort": "443", "CidrIp": "0.0.0.0/0" }
        ],
        "VpcId" : { "Ref" : "VPC" },
        "Tags" : [
          { "Key" : "Name", "Value" : { "Fn::Join": [ "-", [ "sg", { "Ref": "Project" }, { "Ref" : "Environment" } ] ] } },
          { "Key" : "Project", "Value" : { "Ref": "Project" } },
          { "Key" : "Environment", "Value" : { "Ref": "Environment" } }
        ]
      }
    },
    "VPCSGIngress": {
      "Type": "AWS::EC2::SecurityGroupIngress",
      "Properties": {
        "GroupId": { "Ref" : "VPCSecurityGroup" },
        "IpProtocol": "-1",
        "FromPort": "0",
        "ToPort": "65535",
        "SourceSecurityGroupId": { "Ref": "VPCSecurityGroup" }
      }
    }
  },
  "Outputs" : {
    "VpcId" : {
      "Description" : "VPC Id",
      "Value" :  { "Ref" : "VPC" }
    },
    "VPCDefaultNetworkAcl" : {
      "Description" : "VPC",
      "Value" :  { "Fn::GetAtt" : ["VPC", "DefaultNetworkAcl"] }
    },
    "VPCDefaultSecurityGroup" : {
      "Description" : "VPC Default Security Group that we blissfully ignore thanks to self-referencing bugs",
      "Value" :  { "Fn::GetAtt" : ["VPC", "DefaultSecurityGroup"] }
    },
    "VPCSecurityGroup" : {
      "Description" : "VPC Security Group created by this stack",
      "Value" :  { "Ref": "VPCSecurityGroup" }
    },
    "VPCSubnet0": {
      "Description": "The subnet id for VPCSubnet0",
      "Value": {
        "Ref": "VPCSubnet0"
      }
    },
    "VPCSubnet1": {
      "Description": "The subnet id for VPCSubnet1",
      "Value": {
        "Ref": "VPCSubnet1"
      }
    },
    "VPCSubnet2": {
      "Description": "The subnet id for VPCSubnet2",
      "Value": {
        "Ref": "VPCSubnet2"
      }
    }
  }
}
```

Here is an example CloudFormation parameters file for this template:

```json
[
  { "ParameterKey": "Project", "ParameterValue": "myapp" },
  { "ParameterKey": "Environment", "ParameterValue": "dev" },
  { "ParameterKey": "VPCNetworkCIDR", "ParameterValue": "10.0.0.0/16" },
  { "ParameterKey": "VPCSubnet0CIDR", "ParameterValue": "10.0.0.0/24" },
  { "ParameterKey": "VPCSubnet1CIDR", "ParameterValue": "10.0.1.0/24" },
  { "ParameterKey": "VPCSubnet2CIDR", "ParameterValue": "10.0.2.0/24" }
]
```

To script the creation, updating, watching, and deleting of the CloudFormation VPC, I have this Makefile as well:

```
STACK:=myapp-dev
TEMPLATE:=cloudformation-template_vpc-iam.json
PARAMETERS:=cloudformation-parameters_myapp-dev.json
AWS_REGION:=us-east-1
AWS_PROFILE:=aws-dev

all:
    @which aws || pip install awscli
    aws cloudformation create-stack --stack-name $(STACK) --template-body file://`pwd`/$(TEMPLATE) --parameters file://`pwd`/$(PARAMETERS) --capabilities CAPABILITY_IAM --profile $(AWS_PROFILE) --region $(AWS_REGION)

update:
    aws cloudformation update-stack --stack-name $(STACK) --template-body file://`pwd`/$(TEMPLATE) --parameters file://`pwd`/$(PARAMETERS) --capabilities CAPABILITY_IAM --profile $(AWS_PROFILE) --region $(AWS_REGION)

events:
    aws cloudformation describe-stack-events --stack-name $(STACK) --profile $(AWS_PROFILE) --region $(AWS_REGION)

watch:
    watch --interval 10 "bash -c 'make events | head -25'"
    
output:
    @which jq || ( which brew && brew install jq || which apt-get && apt-get install jq || which yum && yum install jq || which choco && choco install jq)
    aws cloudformation describe-stacks --stack-name $(STACK) --profile $(AWS_PROFILE) --region $(AWS_REGION) | jq -r '.Stacks[].Outputs'

delete:
    aws cloudformation delete-stack --stack-name $(STACK) --profile $(AWS_PROFILE) --region $(AWS_REGION) 
```

You can get these same files by cloning my github project, and ssuming you have a profile named `aws-dev` as mentioned above, you can even run `make` and have it create the `myapp-dev` VPC via CloudFormation:

    git clone https://github.com/ianblenke/aws-docker-walkthrough
    cd aws-docker-walkthrough
    make

You can run `make watch` to watch the CloudFormation events and wait for a `CREATE_COMPLETE` state.

When this is complete, you can see the CloudFormation outputs by running:

    make output

The output will look something like this:

```
aws cloudformation describe-stacks --stack-name myapp-dev --profile aws-dev --region us-east-1 | jq -r '.Stacks[].Outputs'
[
  {
    "Description": "VPC Id",
    "OutputKey": "VpcId",
    "OutputValue": "vpc-b7d1d8d2"
  },
  {
    "Description": "VPC",
    "OutputKey": "VPCDefaultNetworkAcl",
    "OutputValue": "acl-b3cfc7d6"
  },
  {
    "Description": "VPC Default Security Group that we blissfully ignore thanks to self-referencing bugs",
    "OutputKey": "VPCDefaultSecurityGroup",
    "OutputValue": "sg-3e50a559"
  },
  {
    "Description": "VPC Security Group created by this stack",
    "OutputKey": "VPCSecurityGroup",
    "OutputValue": "sg-0c50a56b"
  },
  {
    "Description": "The subnet id for VPCSubnet0",
    "OutputKey": "VPCSubnet0",
    "OutputValue": "subnet-995236b2"
  },
  {
    "Description": "The subnet id for VPCSubnet1",
    "OutputKey": "VPCSubnet1",
    "OutputValue": "subnet-6aa4fd1d"
  },
  {
    "Description": "The subnet id for VPCSubnet2",
    "OutputKey": "VPCSubnet2",
    "OutputValue": "subnet-ad3644f4"
  },
    {
    "Description": "The IAM instance profile for EC2 instances",
    "OutputKey": "InstanceProfile",
    "OutputValue": "myapp-dev-InstanceProfile-1KCQJP9M5TSVZ"
  }
]
```


These CloudFormation Outputs list parameters that we will need to pass to the ElasticBeanstalk Environment creation during the next part of this walkthrough. 

# One final VPC note: IAM permissions for EC2 instance profiles

As a general rule of thumb, each AWS ElasticBanstalk Application Environment should be given its own IAM Instance Profile to use.

Each AWS EC2 instance should be allowed to assume an IAM role for an IAM instance profile that gives it access to the AWS cloud resources it must interface with.

This is accomplished by [introspecting on AWS instance metadata](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-instance-metadata.html). If you haven't been exposed to this yet, I strongly recommend poking around at `http://169.254.169.254` from your EC2 instances:

```bash
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/role-myapp-dev
```

The JSON returned from that command allows an AWS library call with no credentials automatically obtain time-limited IAM STS credentials when run on AWS EC2 instances.

This avoids having to embed "permanent" IAM access/secret keys as environment variables that may "leak" over time to parties that shouldn't have access.

Early on, we tried to do this as an ebextension in `.ebextensions/00_iam.config`, but this only works if the admin running the `eb create` has IAM permissions for the AWS account, and it appears impossible to change the launch InstanceProfile by defining option settings or overriding cloud resources in an ebextensions config file.

Instead, the VPC above generates an `InstanceProfile` that can be referenced later. More on that later in Part 2.

Stay tuned...

