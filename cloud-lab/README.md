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
git clone -b cloud-lab --singlebranch https://github.com/TobyHFerguson/director-scripts
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
#### W




