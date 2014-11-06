---
layout: post
title: "Self-standing Ceph/deis-store docker containers"
date: 2014-11-05 14:40:59 -0500
comments: true
categories: [docker, boot2docker, ceph, deis, aws, s3, orchestration]
---
A common challenge for cloud orchestration is simulating or providing an S3 service layer, particularly for development environments.

As Docker is meant for immutable infrastructure, this poses somewhat of a challenge for production deployments. Rather than tackle that subject here, we'll revisit persistence on immutable infrastructure in a production capacity in a future blog post.

The first challenge is identifying an S3 implementation to throw into a container.

There are a few feature sparse/dummy solutions that might suit development needs:

- [s3-ninja](http://s3ninja.net/) (github [scireum/s3ninja](https://github.com/scireum/s3ninja))
- [fake-s3](https://github.com/jubos/fake-s3)
- [S3Mockup](http://sourceforge.net/projects/s3mockup/)
(and a number of others which I'd rather not even consider)

There are a number of good functional options for actual S3 implementations:

- [ceph](http://ceph.com) (github [ceph/ceph](https://github.com/ceph/ceph)), specifically the [radosgw](http://ceph.com/docs/master/radosgw/)
- [walrus](https://github.com/eucalyptus/eucalyptus/wiki/Walrus-S3-API) from Eucalyptus
- [riak cs](http://basho.com/riak-cloud-storage/)
- [libres3](http://www.skylable.com/download/#LibreS3), backended by the opensource [Skylable Sx](http://www.skylable.com/download/#SX)
- [cumulus](https://github.com/nimbusproject/nimbus/tree/master/cumulus) is an S3 implementation for [Nimbus](http://www.nimbusproject.org/docs/current/faq.html#cumulus)
- [cloudian](http://www.cloudian.com/community-edition.php) which is a non-opensource commercial product
- [swift3](https://github.com/stackforge/swift3) as an S3 compatibility layer with swift on the backend
- [vblob](https://github.com/cloudfoundry-attic/vblob) a node.js based attic'ed project at CloudFoundry
- [parkplace](https://github.com/mattjamieson/parkplace) backended by bittorrent
- [boardwalk](https://github.com/razerbeans/boardwalk) backended by ruby, sinatra, and mongodb

Of the above, one stands out as the underlying persistence engine used by a larger docker backended project: [Deis](http://deis.io)

Rather than re-invent the wheel, it is possible to use deis-store directly.

As Deis deploys on CoreOS, there is an understandable inherent dependency on [etcd](http://github.com/coreos/etcd/) for service discovery.

If you happen to be targeting CoreOS, you can simply point your etcd --peers option or `ETCD_HOST` environment variable at `$COREOS_PRIVATE_IPV4` and skip this next step.

First, make sure your environment includes the `DOCKER_HOST` and related variables for the boot2docker environment:

    eval $(boot2docker shellinit)

Now, discover the IP of the boot2docker guest VM, as that is what we will bind the etcd to:

    IP="$(boot2docker ip 2>/dev/null)"

Next, we can spawn etcd and publish the ports for the other containers to use:

    docker run --name etcd \
               --publish 4001:4001 \
               --publish 7001:7001 \
               --detach \
               coreos/etcd:latest \
               /go/bin/app -listen-client-urls http://0.0.0.0:4001 \
                           -advertise-client-urls http://$IP:4001 \
                           -listen-peer-urls http://0.0.0.0:7001 \
                           -initial-advertise-peer-urls http://$IP:7001 \
                           -data-dir=/tmp/etcd

Normally, we wouldn't put the etcd persistence in a tmpfs for consistency reasons after a reboot, but for a development container: we love speed!

Now that we have an etcd container running, we can spawn the deis-store daemon container that runs the ceph object-store daemon (OSD) module.

    docker run --name deis-store-daemon \
               --volumes-from=deis-store-daemon-data \
               --env HOST=$IP \
               --publish 6800 \
               --net host \
               --detach \
               deis/store-daemon:latest

It is probably a good idea to mount the /var/lib/deis/store volume for persistence, but this is a developer container, so we'll forego that step.

The ceph-osd will wait in a loop when starting until it can talk to ceph-mon, which is the next component provided by the deis-store monitor container.

In order to prepare the etcd config tree for deis-store monitor, we must first set a key for this new deis-store-daemon component.

While we could do that with a wget/curl PUT to the etcd client port (4001), using etcdctl makes things a bit easier.

It is generally a good idea to match the version of the etcdctl client with the version of etcd you are using.

As the CoreOS team doesn't put out an etcdctl container as of yet, one way to do this is to build/install etcdctl inside a coreos/etcd container:

    docker run --rm \
               coreos/etcd \
               /bin/sh -c "cd /go/src/github.com/coreos/etcd/etcdctl; go install ; /go/bin/etcdctl --peers $IP:4001 set /deis/store/hosts/$IP $IP"

This isn't ideal, of course, as there is a slight delay as etcdctl is built and installed before we use it, but it serves the purpose.

There are also [deis/store-daemon settings](http://docs.deis.io/en/latest/managing_deis/store_daemon_settings/) of etcd keys that customize the behavior of ceph-osd a bit.

Now we can start deis-store-monitor, which will use that key to spin up a ceph-mon that monitors this (and any other) ceph-osd instances likewise registered in the etcd configuration tree.

    docker run --name deis-store-monitor \
               --env HOST=$IP \
               --publish 6789 \
               --net host \
               --detach \
               deis/store-monitor:latest

As before, there are volumes that probably should be mounted for /etc/ceph and /var/lib/ceph/mon, but this is a development image, so we'll skip that.

There are also [deis/store-monitor settings](http://docs.deis.io/en/latest/managing_deis/store_monitor_settings/) of etcd keys that customize the behavior of ceph-mon a bit.

Now that ceph-mon is running, ceph-osd will continue starting up. We now have a single-node self-standing ceph storage platform, but no S3.

The S3 functionality is provided by the ceph-radosgw component, which is provided by the deis-store-gateway container.

    docker run --name deis-store-gateway \
               --hostname deis-store-gateway \
               --env HOST=$IP \
               --env EXTERNAL_PORT=8888 \
               --publish 8888:8888 \
               --detach \
               deis/store-gateway:latest

There is no persistence in ceph-radosgw that warrant a volume mapping, so we can ignore that entirely regardless of environment.

There are also [deis/store-gateway settings](http://docs.deis.io/en/latest/managing_deis/store_gateway_settings/) of etcd keys that customize the behavior of ceph-radosgw a bit.

We now have a functional self-standing S3 gateway, but we don't know the credentials to use it. For that, we can run etcdctl again:

    AWS_ACCESS_KEY_ID=$(docker run --rm coreos/etcd /bin/sh -c "cd /go/src/github.com/coreos/etcd/etcdctl; go install ; /go/bin/etcdctl --peers $IP:4001 get /deis/store/gateway/accessKey")
    AWS_SECRET_ACCESS_KEY=$(docker run --rm coreos/etcd /bin/sh -c "cd /go/src/github.com/coreos/etcd/etcdctl; go install ; /go/bin/etcdctl --peers $IP:4001 get /deis/store/gateway/secretKey")
    AWS_S3_HOST=$(docker run --rm coreos/etcd /bin/sh -c "cd /go/src/github.com/coreos/etcd/etcdctl; go install ; /go/bin/etcdctl --peers $IP:4001 get /deis/store/gateway/host")
    AWS_S3_PORT=$(docker run --rm coreos/etcd /bin/sh -c "cd /go/src/github.com/coreos/etcd/etcdctl; go install ; /go/bin/etcdctl --peers $IP:4001 get /deis/store/gateway/port")

Note that the host here isn't the normal AWS gateway address, so you will need to specify things for your S3 client to access it correctly.

Likewise, you may need to specify an URL scheme of "http", as the above does not expose an HTTPS encrypted port.

There are also S3 client changes that [may be necessary](https://github.com/deis/deis/issues/2326) depending on the "calling format" of the client libraries. You may need to [changes things like paperclip](http://stackoverflow.com/questions/24312350/using-paperclip-fog-and-ceph) to [work with fog](https://github.com/thoughtbot/paperclip/issues/1577). There are numerous tools that work happily with ceph, like [s3_to_ceph](https://github.com/stiller/s3_to_ceph/blob/master/s3_to_ceph.rb) and even gems like [fog-radosgw](https://github.com/fog/fog-radosgw) that try and help make this painless for your apps.

I will update this blog post shortly with an example of a containerized s3 client to show how to prove your ceph radosgw is working.

Have fun!

