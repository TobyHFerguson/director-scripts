curl -s -u admin:admin  http://localhost:7189/api/v6/environments/Analytic-permanent%20Environment/deployments/Analytic-permanent%20Deployment | 
jq -r '{dns: .managerInstance.properties.publicDnsName, port: .port | tostring } | "http://"+ .dns +":" +.port'

