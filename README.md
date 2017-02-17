# ECS cluster provisioning 
ECS service fronted with Application Load Balancer 
Packer / ansible provisioner, and Terraform to create the AWS resources

# What I have done:
This is a terraform script that deploys a a complete AWS ECS cluster, with AutoScaling and Load Balancing, running a Wordpress container, and provisions tasks / services to have a running WordPress container. Initially I did have the deployment using Packer with the Ansible provisioner, to build am AMI with the ECS tasks/services backed into the AMI, however I encountered some bugs wih ANsible ECS module which I will explain later, which changed the scope. I then decided to use TerraForm to handle everything, as this was the simplest and sanest deployment in my opinion. 

# How run your project
deps:

```
# ansible --version
ansible 2.2.1.0
# packer --version
0.10.1
$ terraform --version
Terraform v0.8.7
```

The latest version of TerraForm is needed due to the `data` sources which replaced tempalate file resources in previous versions
first set your AWS env vars:

```
export AWS_ACCESS_KEY=someaccesskeyhas
export AWS_SECRET_KEY=somemuchlongersecretkeyhasgoeshere
```

Then plan:

```
terraform plan -out=/path/to/saved.plan
```
followed by

```
terraform apply -state-out=/path/to/saved.plan
```

# How components interact between each over
The scope of this was to create all components from scratch. 17 resources are created:

`Plan: 17 to add, 0 to change, 0 to destroy.`

#### Networking
* aws_vpc.ecs-vpc
* aws_internet_gateway.ecs-igw
* aws_route_table.ecs-public
* aws_route_table_association.ecs-public
* aws_route_table_association.ecs-public-2
* aws_subnet.ecs-public-1
* aws_subnet.ecs-public-2

#### Application Load Balancer:
* aws_alb.ecs-alb
* aws_alb_listener.front_end
* aws_alb_target_group.ecs

#### Security Groups:
* aws_security_group.ecs-ec2-sg
* aws_security_group.ecs-lb-sg

#### ECS:
* aws_ecs_cluster.wp-ecs
* aws_ecs_service.wordpress
* aws_ecs_task_definition.wordpress

#### AutoScaling / Launch config
* aws_autoscaling_group.ecs
* aws_launch_configuration.ecs

The networking components set the ground work for the rest of the resources. I created a VPC, with an internet gateway, and public subnets to deploy each EC2  instance into. The Application Load Balancer allows me to load balancer the ECS application and route to specific ports. The Security groups control Incoming/Outgoing traffic, by restricting what ports are publically accessible to the world. The ECS resources define the ECS cluster, attach the Application Load Balancer, and keeps the state of the services. We then create EC2 instances by means of defining an AutoScaling group and Launch configuration. This allows me to scale up the cluster when demand requires.


# What problems did you have
The ECS module with Ansible has a bug, which hindered the deployment strategy of using Packer with an Ansible provisioner.

#### (https://github.com/WesleyCharlesBlake/ecs-cluster/tree/v0.0.1)[v0.0.1] is the release with Packer/Ansible/TerraForm

The error:
```
 amazon-ebs: TASK [wordpress : Wordpres ECS | task definition] ******************************
    amazon-ebs: An exception occurred during task execution. To see the full traceback, use -vvv. The error was: Invalid type for parameter taskDefinition, value: None, type: <type 'NoneType'>, valid types: <type 'basestring'>
    amazon-ebs: fatal: [127.0.0.1]: FAILED! => {"changed": false, "failed": true, "module_stderr": "Traceback (most recent call last):\n  File \"/tmp/ansible_kq2NLS/ansible_module_ecs_taskdefinition.py\", line 222, in <module>\n    main()\n  File \"/tmp/ansible_kq2NLS/ansible_module_ecs_taskdefinition.py\", line 185, in main\n    existing = task_mgr.describe_task(task_to_describe)\n  File \"/tmp/ansible_kq2NLS/ansible_module_ecs_taskdefinition.py\", line 131, in describe_task\n    response = self.ecs.describe_task_definition(taskDefinition=task_name)\n  File \"/usr/local/lib/python2.7/site-packages/botocore/client.py\", line 253, in _api_call\n    return self._make_api_call(operation_name, kwargs)\n  File \"/usr/local/lib/python2.7/site-packages/botocore/client.py\", line 517, in _make_api_call\n    api_params, operation_model, context=request_context)\n  File \"/usr/local/lib/python2.7/site-packages/botocore/client.py\", line 572, in _convert_to_request_dict\n    api_params, operation_model)\n  File \"/usr/local/lib/python2.7/site-packages/botocore/validate.py\", line 270, in seriatlize_to_request\n    raise ParamValidationError(report=report.generate_report())\nbotocore.exceptions.ParamValidationError: Parameter validation failed:\nInvalid type for parameter taskDefinition, value: None, type: <type 'NoneType'>, valid types: <type 'basestring'>\n", "module_stdout": "", "msg": "MODULE FAILURE"}
    amazon-ebs: to retry, use: --limit @/tmp/packer-provisioner-ansible-local/wordpress-ecs.retry
    amazon-ebs:
    amazon-ebs: PLAY RECAP *********************************************************************
```
I researched this, and found that this exists in the ECS ansible module, and that the ansible module is still in preview, and there are some on going PR's to try and resolve this. This left me with a situation where I could not complete the task at hand according to the given spec, so I decided to use other methods in order to achieve the same result.


# How you would have done things to have the best HA/automated architecture
Firstly I would have liked to have deployed an RDS instance in order to provide the DB backend for the WordPress container (this is the one aspect of this script that I have catered for). I would have liked to have created cloud watch alarms and autoscaling policies in order to best define how auto scaling should occur, and ensure that the infrastructure scales out when needed, and scales down when utilisation is low.

I would have also liked to have utilised EFS for the persistent data storage for the wordpress application, as well as configure EFS, S3 and Cloud Front distributions for better asset handling. This would be the next steps in terms of this deployment.

# Share with us any ideas you have in mind to improve this kind of infrastructure.
I believe that using Packer/Ansible and Terraform for this use case (WordPress ECS cluster), is a bit over complicated for the deployment setup. Why I say this, as it conflicts with my better judgement to create an over complicated deployment, where as I saw many places where the task could be simplified by elimaniting some tools. EG I found that whilst building an AMI with Packer needs to be demonstrated, in a real world environment, this WordPress ECS cluster deployment would not need to have a Packer build, and could be simplified dramatically.

I understand that this was to show my skills in the various tools, however it challenged me to go against my experience/skills.

# Tomorrow we want to put this project in production. What would be your advices and choices to achieve that.
Regarding the infrastructure itself and also external services like the monitoring?

My first task would be to finalise the DB backend using RDS, and the persitent storage for WordPress using EFS/S3 and CDN using CloudFront. This is to ensure the application confirms to a solid specification that will allow us to deploy it into an autosaling, imutable environment.

I would then define Cloudwatch alarms and AutoScaling policies (up and down), to ensure the infrastructure is elastic enough to meet usage demands.

I would then secure the application by creating an ACM cert, and terminate the entire application with HTTPS/SSL (including CloudFront / S3 urls). I would also deploy the domain to Route53, as this will alow me to conduct A/B testing and split testing on the application with upcoming releases and updates that should be deployed.

I would also advise on the CI/CD strategy, as this is something that has not been touched on. Depending on the tools available, I would go with a simplified deployment here: Local (docker-compose.yml which I have included in the repo), then commit a branch, trigger unit tests, deploy to Staging -> QA -> PA -> UT -> PROD.
