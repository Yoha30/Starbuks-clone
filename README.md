# Our Project Front-end Architecture
https://alexmis4iti78.me https://www.alexmis4iti78.me



# Our Project Back-end Architecture
<img src="https://user-images.githubusercontent.com/73319030/207847962-ec0e1ccd-7eba-4a1d-b289-e1a40b86cfc0.png" width="1950" height="580">

## _*Introduction*_
This project is for our ITI class as frontend with backend website.

After doing this project I recommend, instead of learning each technology by watching or reading 
way, just combine them all and gets your hands dirty in a
 a project like that, collaborating with your team as in any
work-based projects.

you don't need to wait until you complete all the knowledge for 
project stack technologies, just start and learn each technology based on your use case in the project

the main purpose is learning, as most of the components of this project are new to us and we have not much experience to get it done even without thinking so we put a lot of time to get it done.
now we are a group of 5 members and in the next versions of this kind of project, we will be more than that.

The architecture was designed to achieve a [fault tolerant](https://avinetworks.com/glossary/fault-tolerance/) and [high availability](https://www.suse.com/suse-defines/definition/high-availability/), which I will get it in more detail later on
## Open Source tools I use to build this architecture
+ **[Linux](https://www.linux.com/what-is-linux/)** Of course as an operating system
+ **[HA Proxy](http://www.haproxy.org/)** as a load balancer and reverse proxy
+ **[Nginx](https://nginx.org/en/)** as a web server
+ **[Keepalived](https://keepalived.readthedocs.io/en/latest/introduction.html)** to achieve a high availability between the two load balancer
+ **[Prometheus](https://github.com/prometheus/prometheus)** as a monitoring server for our nodes
+ **[Grafana](https://github.com/grafana/grafana)** as an interactive visualization web server peer with Prometheus
+ **[Let's Encrypt](https://letsencrypt.org/)** as a free SSL provider 

 ## Our Computing provider is AWS
Creating two VPCs in different regions to avoid the vCPU limit, using VPC peering
to connect them and enable a private network 
routing between them.

adding an IAM role to some EC2 instances to be able to do its role.

Allocate an Elastic Public IP to assign it to LBs servers instead of the auto-assign public IP.

Security_Group, one with public configuration for LBs and one with private configuration for web servers and monitoring server with opening the appropriate port (3000,443,9090,9100,80)

_all virtual machine is t[2,3]-micro using available free trial only_

<img src="https://user-images.githubusercontent.com/73319030/207845031-76e655a0-4814-46d4-ade6-ebea85044591.png" width="950" height="280">

<img src="https://user-images.githubusercontent.com/73319030/207844459-b8dad885-821b-4e4c-8d02-51d374afa536.png" width="950" height="280">

## Domain name provider
Make an A record for alexmis4iti78 , wwww.alexmis4iti78.me

It's crucial to make a valid SSL certificate via Let's Encrypt that you need a working domain name 

_Namecheap, useing a coupon from the GitHub student package to get it free_
__________________
### Linux
all VMs running on Centos distro as **Amazon Linux** default one with only command line interface  

### HA Proxy  
It is the best open-source load balancer written in C, and is also very popular in DevOps environments.

With minimal configuration I set 4 web servers at the backend section **haproxy.cfg** , using the default algorithm to load balance the requests

Work as a server to load balance incoming traffic from the internet to web servers, the main purpose is SSL-Termination for all web servers, HA proxy server handles all HTTPS requests and communicates with web servers on private IPs only at port 80.

it's running on layer 7.

At the highly available concept, we have a backup HA Proxy server to the master one to prevent downtime

obtaining a free certificate from Let's encrypt and enable 
auto-renew script

__The configuration of HAProxy server__
```yml
#location /etc/haproxy/haproxy.cfg
# Configure it as a load balancer and SSL-termination
# only open port is 443

frontend http_front
   bind *:443 ssl crt /etc/haproxy/key/alexmis4iti78.me.pem # combined a private key with certificate in one .pem file
   reqadd X-Forwarded-Proto:\ https # only https connection is allowed
   default_backend http_back

backend http_back
   balance roundrobin  # as the default algorithm
   # nginx web servers, balance the requests between them
   server server_name1 10.0.0.6:80  check
   server server_name2 10.0.0.7:80  check
   server server_name3 10.0.0.9:80  check
   server server_name4 10.0.0.19:80 check

backend letsencrypt-backend   # open it for let's encrypt service
   server letsencrypt 127.0.0.1:54321
```
### Nginx
It is the faster webserver to serve static content (html,css,js) so I choose it rather than apache web server, although, apache is more straightforward than Nginx.

setting a 4 web-server have the same content is the best 
for a fault-tolerance environment. 

all 4 Nginx servers are in a private network.

__The configuration of Nginx server__
  ```ini
# It's not the default Nginx configuration file, but only that is what I need
http{

include mime.types; // To be able to excute an [html/css/js] and more
        server {

                listen 80; // only listen on port 80, it's a private network
                server_name 172.31.0.186; 
                root /usr/share/nginx/html;  // site's files location

        }

}

events{}  # nginx will not run without it 
```
 

### KeepAlived
Instead of using an ELB to manage the Active-Passive Architecture,
I preferred to use "KeepAlived" to do that 

To run **keepalived** in the AWS environment you need to allocate an  
Elastic public IP to assign it to the active load balance with a script to detect a failure of the master to reassign the Elastic IP to the backup load balance, keep in mind that you need to add ec2 role   
to associate and disassociate the Elastic IP

__The configuration of KeepAlived__
```ini
vrrp_script check_haproxy 
{
    script "pidof haproxy"
    interval 5
    fall 2
    rise 2
}

vrrp_instance VI_1
{
    debug 2
    interface eth0
    state MASTER
    virtual_router_id 41 
    priority 110  # higher priority for master server
    unicast_src_ip 172.31.0.68 # IP of Active machine

    unicast_peer # IP of the backup machine
    {
       172.31.15.233

    }

    track_script
    {
        check_haproxy
    }

    notify_master /etc/keepalived/failover.sh ## bash script run if the state of haproxy fail
                                              ## to reassign an Elastic IP
}
```
__Script that runs when a Master server fails__
```bash
EIP=3.28.247.74 # Elastic public IP
INSTANCE_ID=i-010d3d18ec00cd116 # ID of the backup server

/usr/bin/aws ec2 disassociate-address --public-ip $EIP
/usr/bin/aws ec2 associate-address --public-ip $EIP --instance-id $INSTANCE_ID
```

### Prometheus
It's idea containing of two parts which are __Prometheus__ and __Node_Exporter__ 
Prometheus is the central server that the all data metrics of all other servers pulled to it
Node_Exporter is like an agent, you need to install it in each server you want to collect its metrics

I put it in my Architecture to detect any kind of failer

also, keep in mind that if you are in an AWS environment you need
to attach an IAM role for the Prometheus server to be able 
to do its job


__The configuration of Prometheus__
```yml
#yaml configuration on server site to pull data from my target servers
global:
  scrape_interval: 15s
  external_labels:
    monitor: 'prometheus'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      # to monitor the Prometheus server itself 
      - targets: ['localhost:9090']
  - job_name: 'node_exporter'

    static_configs:
      # backend servers need to be monitor
      - targets: ['10.0.0.7:9100']
      - targets: ['10.0.0.9:9100']
      - targets: ['10.0.0.19:9100']
      - targets: ['10.0.0.6:9100']
      - targets: ['172.31.0.68:9100']
      - targets: ['172.31.15.233:9100']
 ``` 
  __The configuration of Prometheus demon__
 ```ini
# locatetion /etc/systemd/system/prometheus.Service
# to run Prometheus demon

[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target
[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries
[Install]
WantedBy=multi-user.target
```
 __The configuration of Node_Exporter demon__
```ini
# location /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target
[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter
[Install]
WantedBy=multi-user.target
```

### Grafana
One of the trending tools in monitoring also in DevOps environment

Useing it to make a very detailed dashboard for the backend
infrastructure, it's like an enhancement for Prometheus to get
all the metrics in a visualized way

<img src="https://user-images.githubusercontent.com/73319030/207846732-69b196cd-4bd3-4266-9382-bfa34d17f1fc.png" width="1550" height="580">


# Pentest Demo On Our Back-end Architecture



### Credits  

[Hussein Nasser Youtube Channel](https://www.youtube.com/@hnasr/videos)    
Subscribe to his Channel is a **must**    


**[Courses]**  

[Fundamentals of Backend](https://www.udemy.com/course/fundamentals-of-backend-communications-and-protocols/)
[HAProxy](https://acloudguru.com/course/hands-on-with-haproxy-load-balancer)  
[Nginx](https://www.udemy.com/course/nginx-crash-course/)

[AWS بالعربي](https://www.youtube.com/playlist?list=PLOoZRfEtk6kWSM_l9xMjDh-_MJXl03-pf)  
_Father of AWS in Arabic_

**[Good Articles]** 

[Loadbalancing with haproxy](https://www.digitalocean.com/community/tutorial_series/load-balancing-wordpress-with-haproxy)  
[L4 vs L7 Load Balancing](https://levelup.gitconnected.com/l4-vs-l7-load-balancing-d2012e271f56)  
[HAProxy SSL Termination](https://www.haproxy.com/blog/haproxy-ssl-termination/) 
[Prometheus Node Exporter and Grafana on EC2](https://setkyar.medium.com/setup-server-monitoring-with-prometheus-node-exporter-and-grafana-on-ec2-d477733bf641)[[
[keepalived_Nginx-Docs](https://docs.nginx.com/nginx/deployment-guides/amazon-web-services/high-availability-keepalived/)  
[Keepalived](https://www.peternijssen.nl/high-availability-haproxy-keepalived-aws/)
[How to secure haproxy](https://www.digitalocean.com/community/tutorials/how-to-secure-haproxy-with-let-s-encrypt-on-centos-7)
[prometheus and grafana](https://devops4solutions.com/monitoring-using-prometheus-and-grafana-on-aws-ec2/)
