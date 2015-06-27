---
layout: post
title: "Deploying Amazon ECS on CoreOS"
date: 2015-03-10 16:38:33 -0400
date_formatted: Mar 3, 2015
linkedin_share:
linkedin_share: https://www.linkedin.com/nhome/updates?topic=5981175739561623552
summary: Deploying Amazon ECS on CoreOS
comment: Howto deploy the Amazon ECS agent on CoreOS and enumerate the cluster
comments: true
categories: coreos docker aws ecs
---
Today, I stumbled on the official [CoreOS page on ECS](https://coreos.com/docs/running-coreos/cloud-providers/ecs/).

I've been putting off ECS for a while, it was time to give it a try.

To create the ECS cluster, we will need the aws commandline tool:

    which aws || pip install awscli

Make sure you have your `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` defined in your shell environment.

Create the ECS cluster:

    aws ecs create-cluster --cluster-name Cosmos-Dev
    {
        "cluster": {
            "clusterName": "Cosmos-Dev",
            "status": "ACTIVE",
            "clusterArn": "arn:aws:ecs:us-east-1:123456789012:cluster/My-ECS-Cluster"
        }
    }

Install the global fleet unit for amazon-ecs-agent.service:

    cat <<EOF > amazon-ecs-agent.service
    [Unit]
    Description=Amazon ECS Agent
    After=docker.service
    Requires=docker.service
    [Service]
    Environment=ECS_CLUSTER=My-ECS-Cluster
    Environment=ECS_LOGLEVEL=warn
    Environment=AWS_REGION=us-east-1
    ExecStartPre=-/usr/bin/docker kill ecs-agent
    ExecStartPre=-/usr/bin/docker rm ecs-agent
    ExecStartPre=/usr/bin/docker pull amazon/amazon-ecs-agent
    ExecStart=/usr/bin/docker run --name ecs-agent \
        --env=ECS_CLUSTER=${ECS_CLUSTER}\
        --env=ECS_LOGLEVEL=${ECS_LOGLEVEL} \
        --publish=127.0.0.1:51678:51678 \
        --volume=/var/run/docker.sock:/var/run/docker.sock \
        amazon/amazon-ecs-agent
    ExecStop=/usr/bin/docker stop ecs-agent
    [X-Fleet]
    Global=true
    EOF
    fleetctl start amazon-ecs-agent.service

This registers a ContainerInstance to the `My-ECS-Cluster` in region `us-east-1`.

Note: this is using the EC2 instance's instance profile IAM credentials. You will want to make sure you've assigned an instance profile with a Role that has "ecs:*" access.
For this, you may want to take a look at the [Amazon ECS Quickstart CloudFormation template](https://s3.amazonaws.com/amazon-ecs-cloudformation/Amazon_ECS_Quickstart.template).

Now from a CoreOS host, we can query locally to enumerate the running ContainerInstances in our fleet:

    fleetctl list-machines -fields=ip -no-legend | while read ip ; do \
        echo $ip $(ssh -n $ip curl -s http://169.254.169.254/latest/meta-data/instance-id) \
        $(ssh -n $ip curl -s http://localhost:51678/v1/metadata | \
          docker run -i realguess/jq jq .ContainerInstanceArn) ; \
      done

Which returns something like:

    10.113.0.23 i-12345678 "arn:aws:ecs:us-east-1:123456789012:container-instance/674140ae-1234-4321-1234-4abf7878caba"
    10.113.1.42 i-23456789 "arn:aws:ecs:us-east-1:123456789012:container-instance/c3506771-1234-4321-1234-1f1b1783c924"
    10.113.2.66 i-34567891 "arn:aws:ecs:us-east-1:123456789012:container-instance/75d30c64-1234-4321-1234-8be8edeec9c6"

And we can query ECS and get the same:

    $ aws ecs list-container-instances --cluster My-ECS-Cluster | grep arn | cut -d'"' -f2 | \
      xargs -L1 -I% aws ecs describe-container-instances --cluster My-ECS-Cluster --container-instance % | \
      jq '.containerInstances[] | .ec2InstanceId + " " + .containerInstanceArn'
    "i-12345678 arn:aws:ecs:us-east-1:123456789012:container-instance/674140ae-1234-4321-1234-4abf7878caba"
    "i-23456789 arn:aws:ecs:us-east-1:123456789012:container-instance/c3506771-1234-4321-1234-1f1b1783c924"
    "i-34567891 arn:aws:ecs:us-east-1:123456789012:container-instance/75d30c64-1234-4321-1234-8be8edeec9c6"

This ECS cluster is ready to use.

Unfortunately, there is no scheduler here. ECS is a harness for orchestrating docker containers in a cluster as _tasks_. 

Where these tasks are allocated is left up to the AWS customer.

What we really need is a _scheduler_.

CoreOS has a form of a scheduler in fleet, but that is for fleet units of systemd services, and is not limited to docker containers as ECS is.
Fleet's scheduler is also currently a bit weak in that it schedules new units to the fleet machine with the fewest number of units.

Kubernetes has a random scheduler, which is better in a couple ways, but does not fairly allocate the system resources.

The _best_ scheduler at present is Mesos, which takes into account resource sizing estimates and current utilization.

Normally, Mesos uses Mesos Slaves to run work. Mesos can also use ECS as a backend instead.

My next steps: Deploy Mesos using the [ecs-mesos-scheduler-driver](https://github.com/awslabs/ecs-mesos-scheduler-driver), as [summarized by jpetazzo](http://jpetazzo.github.io/2015/01/14/amazon-docker-ecs-ec2-container-service/)

