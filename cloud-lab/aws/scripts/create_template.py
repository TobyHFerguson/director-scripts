#!/usr/bin/python
import os
import time
from cm_api.api_client import ApiResource
# If the exit code is not zero Cloudera Director will fail

# Post creation scripts also have access to the following environment variables:

#    DEPLOYMENT_HOST_PORT
#    ENVIRONMENT_NAME
#    DEPLOYMENT_NAME
#    CLUSTER_NAME
#    CM_USERNAME
#    CM_PASSWORD

def main():
    cmhost = os.environ['DEPLOYMENT_HOST_PORT'].split(":")[0]
    api = ApiResource(cmhost, username='admin', password='admin')
    all_clusters = api.get_all_clusters()
    for cluster in all_clusters:
        if (cluster.name == os.environ['CLUSTER_NAME']):
            break

    template = cluster.create_host_template("cdsw-gateway")
    

    
if __name__ == "__main__":
    main()
