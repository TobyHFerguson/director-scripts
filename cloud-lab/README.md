# Cloud Lab

This directory contains the instructions, scripts and templates necessary to run a cloud lab or workshop

The idea is that many students will each have access to their own director instance and will use director to:
* setup an analytic (permanent) cluster
* configure HUE and Impala to point to an s3 bucket
* run a transient ETL workload to fill the s3 bucket

These scripts are written for AWS, with Director 2.2+ and CDH/CM 5.9+

These scripts assume that you'll be working in the ~us-east-1~ region - you'll have to grub around and do various edits if you want to use a different region


## Workflow
### Overview
* You'll need to install aws-cli and packer if they're not already on your local machine.
* Clone this repository to your local machine and checkout this branch
* Create CDH and Director amis
* modify the scripts/create_director_image to use these amis
* for each student, create a director image and a zip file that gives them access to that image

### Detailed Instructions

* One time, install aws cli. On mac:
```sh
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
```
Then configure your AWS credentials 
```sh
aws configure
```
* pull down this repository to a directory near you and cd to the correct directory and change to this branch:
```sh
git clone https://github.com/TobyHFerguson/director-scripts
cd director-scripts
git checkout cloud-lab
```

* One time, install packer (see ~/director-scripts/faster-bootstrap/README.md for instructions)
* Create the CDH ami using the techniques listed in faster-bootstrap 
* Create a director ami by instantiating an image (we recommend c4.xlarge running centos 7.2 ami-05a75613) and then saving that off as an AMI
* edit the `create_director_image.sh` file to put in the ami ids for the newly-created CDH and Director amis
* For each student, assuming you have their AWS_ACCESS_KEY_ID, their AWS_SECRET_ACCESS_KEY and their name, execute `create_director_image.sh AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY name`



