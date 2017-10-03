# rdss-archivematica

Integration repo for the RDSS fork of Archivematica.

## Source management

Currently, it is expected that the user clones the corresponding git
repositories manually. They're expected to be located under the `src/`
directory. You can use `make clone` to clone these.

URL | Branch | Components
--- | ------ | ----------
https://github.com/JiscRDSS/archivematica | qa/jisc | MCPServer, MCPClient, Dashboard
https://github.com/JiscRDSS/archivematica-storage-service | qa/jisc | Storage Service
https://github.com/JiscRDSS/rdss-archivematica-automation-tools | master | Automation Tools
https://github.com/JiscRDSS/rdss-archivematica-channel-adapter | master | Channel Adapter
https://github.com/JiscRDSS/rdss-archivematica-msgcreator | master | Msgcreator
https://github.com/JiscRDSS/rdss-arkivum-nextcloud | master | NextCloud
https://github.com/artefactual/archivematica-sampledata | master | Sample data

## Development environment

Open [the compose folder](compose) to see more details.

## AWS environment

#### Docker Machine + Amazon EC2

Deployment of the development environment in a single EC2 instance supported by Docker Machine.

Open [the aws/machine folder](aws/machine) to see more details.

#### Terraform + Amazon ECS

Using Terraform to create all the necessary infrastructure and Amazon ECS to run the containers in a cluster of EC2 instances.

Open [the aws/ecs folder](aws/ecs) to see more details.
