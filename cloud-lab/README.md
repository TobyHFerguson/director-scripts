# Cloud Lab

This directory contains the instructions, scripts and templates necessary to run a cloud lab or workshop

The idea is that many students will each have access to their own director instance and will use director to:
* setup an analytic (permanent) cluster
* configure HUE and Impala to point to an s3 bucket
* run a transient ETL workload to fill the s3 bucket

These scripts are written for AWS, with Director 2.2+ and CDH/CM 5.9+

These scripts assume that you'll be working in the `us-east-1` region - you'll have to grub around and do various edits if you want to use a different region


## Workflows
### Instructor
#### One time:
Clone this repository with this specific branch: then run the `cloud-lab/scripts/create_director_image.sh` script:
```sh
git clone -b cloud-lab https://github.com/TobyHFerguson/director-scripts
```

#### For each user:
Assuming you've got specific AWS credentials and a name for your user (`USR_ACCESS_KEY_ID`, `USR_SECRET_KEY` and `USR`, respectively), you can now create a running directory instance and a zip file with the necessary details for that user:
```sh
cd director-scripts/cloud-lab/scripts
./create_director_image.sh ${AWS_ACCESS_KEY_ID} ${AWS_SECRET_KEY} $USR
```
This will create a zip file containing:
* a readme (`README`) with the basic instructions the user needs to execute the lab
* an SSH private key file
* an SSH config file (`ssh_config`) setup so that the user can easily get to their running director instance via SSH

You're expected to email this zip file to the user.

### User
It is assumed that each user has access to `ssh` (Linux/Mac OSX) or, if they have a Windows machine,  that they can configure `putty` or similar given the `ssh_config`

* Linux/Mac OSX - The user is expected to unpack the zip file into some directory, then cd into that directory, cat the README and follow the instru
* Windows - Use the contents of the `ssh_config` file and some internet searching to figure out how to configure your ssh client

Here's an example session for a Linux/Mac OSX user (`toby`) on machine `toby-MBP` where the user gets as far as unpacking the zip file and reviewing the contents of the readme file:
```sh
toby-MBP:~ toby$ mkdir -p /tmp/cloud-lab
toby-MBP:~ toby$ cd /tmp/cloud-lab
toby-MBP:cloud-lab toby$ ls
toby-MBP:cloud-lab toby$ unzip /tmp/toby.42510.zip 
Archive:  /tmp/toby.42510.zip
  inflating: README                  
  inflating: cloud-lab-toby-keypair-6656490afbccb2313cbadd792ea70bd9  
  inflating: ssh_config              
toby-MBP:cloud-lab toby$ cat README
ssh
   ssh configuration to access your director instance is in ssh_config
   The private keyfile for your director instance is in cloud-lab-toby-keypair-6656490afbccb2313cbadd792ea70bd9

Creating an Analytic Cluster
   Create an analytic cluster by executing the following (in this directory):

   ssh -qtF ssh_config director 'cloudera-director bootstrap-remote analytic_cluster.conf --lp.remote.username=admin --lp.remote.password=admin'

Making the output table
   Locate the Cloudera Manager URL by executing:

   ssh -qtF ssh_config director ./get_cm_url.sh

   In a browser access Hue via Cloudera Manager and create the etl output table by executing the following sql in the Impala Query Editor: 

   CREATE EXTERNAL TABLE etl_table (d_year string,brand_id int,brand string,sum_agg float)  LOCATION 's3a://cloud-lab-toby-bucket-16989fece81db91828976dcba88340f3/output'

Executing the ETL Job
   Execute the ETL job to fill the output table by executing the following:
   
   ssh -qtF ssh_config director './run_all.sh' 

toby-MBP:cloud-lab toby$ 


