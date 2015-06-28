---
layout: post
title: "AWS Docker Walkthrough with ElasticBeanstalk: Part 2"
date_formatted: Jun 28, 2015
date: 2015-06-28 00:57:08 -0400
comments: true
categories: amazon aws elasticbeanstalk docker ecs cloudformation ebextensions
summary: Creating ElasticBeanstalk enviroments
comment: HowTo use the awsebcli package to deploy ElasticBeanstalk enviroments
---
While deploying docker containers for immutable infrastructure on AWS ElasticBeanstalk,
I've learned a number of useful tricks that go beyond the official Amazon documentation.

This series of posts are an attempt to summarize some of the useful bits that may benefit
others facing the same challenges.

---

Previously: [Part 1 : Preparing a VPC for your ElasticBeanstalk environments](/blog/2015/06/27/aws-docker-walkthrough-with-elasticbeanstalk-part-1/)

---

# Part 2 : Creating your ElasticBeanstalk environment

---

### Step 1: Create your Application in AWS

Each AWS account needs to have your ElasticBeanstalk application defined initially.

Operationally, there are few reasons to remove an application from an AWS account, so there's a good bet it's already there.

```bash
aws elasticbeanstalk create-application \
  --profile aws-dev \
  --region us-east-1 \
  --application-name myapp \
  --description 'My Application'
```

You should really only ever have to do this once per AWS account.

There is an example of this in the Makefile as the `make application` target.

### Step 2 : Update your AWS development environment.

During our initial VPC creation, we used the `aws` command from the `awscli` python package.

When deploying ElasticBeanstalk applications, we use the `eb` command from the `awsebcli` python package.

On OS/X, we run:

```bash
brew install awsebcli
```

On Windows, chocolatey doesn't have awsebcli, but we can install python pip:

```bash
choco install pip
```

Again, because `awsebcli` is a python tool, we can install with:

```bash
pip install awscli
```

You may (or may not) need to prefix that pip install with `sudo` on linux/unix flavors, depending. ie:

```bash
sudo pip install awsebcli
```

These tools will detect if they are out of date when you run them. You may eventually get a message like:

```
Alert: An update to this CLI is available.
```

When this happens, you will likely want to either upgrade via homebrew:

```bash
brew update & brew upgrade awsebcli
```

or, more likely, upgrade using pip directly:

```bash
pip install --upgrade awsebcli
```

Again, you may (or may not) need to prefix that pip install with `sudo`, depending. ie:

```bash
sudo pip install --upgrade awsebcli
```

There really should be an awsebcli Docker image, but there presently is not. Add that to the list of images to build.

### Step 3: Create a ssh key pair to use

Typically you will want to generate an ssh key locally and upload the public part:

```bash
ssh-keygen -t rsa -b 2048 -f ~/.ssh/myapp-dev -P ''
aws ec2 import-key-pair --key-name myapp-dev --public-key-material "$(cat ~/.ssh/myapp-dev.pub)"
```

Alternatively, if you are on a development platform without ssh-keygen for some reason, you can have AWS generate it for you:

```bash
aws ec2 create-key-pair --key-name cosmos-dev > ~/.ssh/id_rsa-cosmos-dev
```

The downside to the second method is that AWS has the private key (as they generated it, and you shipped it via https over the network to your local machine), whereas in the first example they do not.

This ssh key can be used to access AWS instances directly.

After creating this ssh key, it is probably a good idea that you add it to your team's password management tool (Keepass, Hashicorp Vault, Trousseau, Ansible Vault, Chef Encrypted Databags, LastPass, 1Password, Dashlane, etc) so that the private key isn't only on your development workstation in your local user account.

Note the naming convention of `~/.ssh/$(PROJECT)-$(ENVIRONMENT)` - this is the default key filename that `eb ssh` will use.

If you do not use the above naming convention, you will have to add the generated ssh private key to your ssh-agent's keychain in order to use it:

```bash
[ -n $SSH_AUTH_SOCK ] || eval $(ssh-agent)
ssh-add ~/.ssh/myapp-dev
```

To list the ssh keys in your keychain, use:

```bash
ssh-add -l
```

So long as you see 4 or fewer keys, including they key you created above, you should be ok.

If you have more than 4 keys listed in your ssh-agent keychain, depending on the order they are tried by your ssh client, that may exceed the default number of ssh key retries allowed on the remote sshd server side, which will prevent you from connecting.

Now we should have an ssh key pair defined in AWS that we can use when spinning up instances.

### Step 4: Initialize your local development directory for the eb cli

Before using the `eb` command, you must `eb init` your project to create a `.elasticbeanstalk/config.yml` file:

```bash
eb init --profile aws-dev
```

The `--profile aws-dev` is optional, if you created profiles in your `~/.aws/config` file. If you are using AWS environment variables your your ACCESS/SECRET keys, or only one default AWS account, you may omit that.

The application must exist in AWS first, which is why this is run _after_ the previous step of creating the Application in AWS.

You may be prompted for some critical bits:

    $ eb init --profile aws-dev
    eb init --profile aws-dev
    
    Select a default region
    1) us-east-1 : US East (N. Virginia)
    2) us-west-1 : US West (N. California)
    3) us-west-2 : US West (Oregon)
    4) eu-west-1 : EU (Ireland)
    5) eu-central-1 : EU (Frankfurt)
    6) ap-southeast-1 : Asia Pacific (Singapore)
    7) ap-southeast-2 : Asia Pacific (Sydney)
    8) ap-northeast-1 : Asia Pacific (Tokyo)
    9) sa-east-1 : South America (Sao Paulo)
    (default is 3): 1
    
    Select an application to use
    1) myapp
    2) [ Create new Application ]
    (default is 2): 1
    
    Select a platform.
    1) PHP
    2) Node.js
    3) IIS
    4) Tomcat
    5) Python
    6) Ruby
    7) Docker
    8) Multi-container Docker
    9) GlassFish
    10) Go
    (default is 1): 7
    
    Select a platform version.
    1) Docker 1.6.2
    2) Docker 1.6.0
    3) Docker 1.5.0
    (default is 1): 1
    Do you want to set up SSH for your instances?
    (y/n): y

    Select a keypair.
    1) myapp-dev
    2) [ Create new KeyPair ]
    (default is 2): 1

Alternatively, to avoid the questions, you can specify the full arguments:

```bash
eb init myapp --profile aws-dev --region us-east-1 -p 'Docker 1.6.2' -k myapp-dev
```

The end result is a `.elasticbeanstalk/config.yml` that will look something like this:

```yaml
branch-defaults:
  master:
    environment: null
global:
  application_name: myapp
  default_ec2_keyname: myapp-dev
  default_platform: Docker 1.6.2
  default_region: us-east-1
  profile: aws-dev
  sc: git
```

Any field appearing as `null` will likely need some manual attention from you after the next step.

### Step 5: Create the ElasticBeanstalk Environment

Previously, in [Part 1 : Preparing a VPC for your ElasticBeanstalk environments](/blog/2015/06/27/aws-docker-walkthrough-with-elasticbeanstalk-part-1/), we generated a VPC using a CloudFormation with an output of the Subnets and Security Group. We will need those things below.

Here is a repeat of that gist:

{% gist 59715079304a6db7182c %}

There are two ways to create a new ElasticBeanstalk environment:

- Using `eb create` with full arguments for the various details of the environment.
- Using `eb create` with a `--cfg` argument of a previous `eb config save` to a YAML file in `.elasticbeanstalk/saved_configs`.

The first way looks something like this:

    eb create myapp-dev --verbose \
      --profile aws-dev \
      --tier WebServer \
      --cname myapp-dev \
      -p '64bit Amazon Linux 2015.03 v1.4.3 running Docker 1.6.2' \
      -k myapp-dev \
      -ip myapp-dev-InstanceProfile-1KCQJP9M5TSVZ \
      --tags Project=myapp,Environment=dev \
      --envvars DEBUG=info \
      --vpc.ec2subnets=subnet-995236b2,subnet-6aa4fd1d,subnet-ad3644f4 \
      --vpc.elbsubnets=subnet-995236b2,subnet-6aa4fd1d,subnet-ad3644f4 \
      --vpc.publicip --vpc.elbpublic --vpc.securitygroups=sg-0c50a56b

The `Makefile` has an `environment` target that removes the need to fill in the fields manually:

    outputs:
        @which jq > /dev/null 2>&1 || ( which brew && brew install jq || which apt-get && apt-get install jq || which yum && yum install jq || which choco && choco install jq)
        @aws cloudformation describe-stacks --stack-name myapp-dev --profile aws-dev --region us-east-1 | jq -r '.Stacks[].Outputs | map({key: .OutputKey, value: .OutputValue}) | from_entries'

    environment:
        eb create $(STACK) --verbose \
          --profile aws-dev \
          --tier WebServer \
          --cname $(shell whoami)-$(STACK) \
          -p '64bit Amazon Linux 2015.03 v1.4.3 running Docker 1.6.2' \
          -k $(STACK) \
          -ip $(shell make outputs | jq -r .InstanceProfile) \
          --tags Project=$(PROJECT),Environment=$(ENVIRONMENT) \
          --envvars DEBUG=info \
          --vpc.ec2subnets=$(shell make outputs | jq -r '[ .VPCSubnet0, .VPCSubnet1, .VPCSubnet2 ] | @csv') \
          --vpc.elbsubnets=$(shell make outputs | jq -r '[ .VPCSubnet0, .VPCSubnet1, .VPCSubnet2 ] | @csv') \
          --vpc.publicip --vpc.elbpublic \
          --vpc.securitygroups=$(shell make outputs | jq -r .VPCSecurityGroup)

On the other hand, after a quick config save:

```bash
eb config save myapp-dev --profile aws-dev --region us-east-1 --cfg myapp-dev-sc
```

We now have the above settings in a YAML file `.elasticbeanstalk/saved_configs/myapp-dev-sc.cfg.yml` which can be committed to our git project.

This leads to the second way to create an ElasticBeanstalk environment:

```bash
eb create myapp-dev --cname myapp-dev --cfg myapp-dev-sc --profile aws-dev
```

The flip side of that is the YAML save config has static values embedded in it for a specific deployed VPC.

More docker goodness to come in Part 3...
