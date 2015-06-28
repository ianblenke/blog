---
layout: post
title: "AWS Docker Walkthrough with ElasticBeanstalk: Part 1"
date_formatted: Jun 27, 2015
date: 2015-06-27 13:14:08 -0400
comments: true
categories: amazon aws elasticbeanstalk docker ecs cloudformation ebextensions
summary: Preparing a VPC for your ElasticBeanstalk environments
comment: HowTo use a CloudFormation to create a VPC
---
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

Below is a public gist of a VPC CloudFormation that I use for deployment:

{% gist 0a6a6f26d1ecaa0d81eb %}

Here is an example CloudFormation parameters file for this template:

{% gist 9f4b8dd2b39c7d1c31ef %}

To script the creation, updating, watching, and deleting of the CloudFormation VPC, I have this Makefile as well:

{% gist 55b740ff19825d621ef4 %}

You can get these same files by cloning my github project, and ssuming you have a profile named `aws-dev` as mentioned above, you can even run `make` and have it create the `myapp-dev` VPC via CloudFormation:

    git clone https://github.com/ianblenke/aws-docker-walkthrough
    cd aws-docker-walkthrough
    make

You can run `make watch` to watch the CloudFormation events and wait for a `CREATE_COMPLETE` state.

When this is complete, you can see the CloudFormation outputs by running:

    make output

The output will look something like this:

{% gist 59715079304a6db7182c %}

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

