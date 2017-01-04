# ETL Transient Jobs on AWS with Cloudera

These scripts can be used as an example end-to-end transient demo for a Hive query with Cloudera Hadoop (v5.8) running on AWS.

## Instructions

- One time, install aws cli. On mac:
```sh
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
unzip awscli-bundle.zip
sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
```
Then configure your AWS credentials 
```sh
aws configure
```

- pull down this repository to a directory near you and cd to the correct directory and change to this branch:
```sh
git clone https://github.com/TobyHFerguson/director-scripts
cd director-scripts/transient-aws
git checkout make_director_ami
```

- edit the `create_director_image.sh` file to put in your values

- run the `create_director_image.sh` file

This will:
- Create a new instance from a known working AMI
- Configure all the security settings
- Install director
- Provide an ssh config file to make logging into the instance easy

### Run transient job
```sh
ssh -tF CONFIG_FILE director "./run_all.sh"
```
