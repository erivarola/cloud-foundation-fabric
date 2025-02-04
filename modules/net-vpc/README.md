# Minimalistic VPC module

This module allows creation and management of VPC networks including subnetworks and subnetwork IAM bindings, Shared VPC activation and service project registration, and one-to-one peering.

## Examples

The module allows for several different VPC configurations, some of the most common are shown below.

### Simple VPC

```hcl
module "vpc" {
  source     = "./modules/net-vpc"
  project_id = "my-project"
  name       = "my-network"
  subnets = [
    {
      ip_cidr_range = "10.0.0.0/24"
      name          = "production"
      region        = "europe-west1"
      secondary_ip_range = {
        pods     = "172.16.0.0/20"
        services = "192.168.0.0/24"
      }
    },
    {
      ip_cidr_range = "10.0.16.0/24"
      name          = "production"
      region        = "europe-west2"
      secondary_ip_range = {}
    }
  ]
}
# tftest:modules=1:resources=3
```

### Peering

A single peering can be configured for the VPC, so as to allow management of simple scenarios, and more complex configurations like hub and spoke by defining the peering configuration on the spoke VPCs. Care must be taken so as a single peering is created/changed/destroyed at a time, due to the specific behaviour of the peering API calls.

If you only want to create the "local" side of the peering, use `peering_create_remote_end` to `false`. This is useful if you don't have permissions on the remote project/VPC to create peerings.

```hcl
module "vpc-hub" {
  source     = "./modules/net-vpc"
  project_id = "hub"
  name       = "vpc-hub"
  subnets = [{
    ip_cidr_range      = "10.0.0.0/24"
    name               = "subnet-1"
    region             = "europe-west1"
    secondary_ip_range = null
  }]
}

module "vpc-spoke-1" {
  source     = "./modules/net-vpc"
  project_id = "spoke1"
  name       = "vpc-spoke1"
  subnets = [{
    ip_cidr_range      = "10.0.1.0/24"
    name               = "subnet-2"
    region             = "europe-west1"
    secondary_ip_range = null
  }]
  peering_config = {
    peer_vpc_self_link = module.vpc-hub.self_link
    export_routes      = false
    import_routes      = true
  }
}
# tftest:modules=2:resources=6
```

### Shared VPC

[Shared VPC](https://cloud.google.com/vpc/docs/shared-vpc) is a project-level functionality which enables a project to share its VPCs with other projects. The `shared_vpc_host` variable is here to help with rapid prototyping, we recommend leveraging the project module for production usage.

```hcl
locals {
  service_project_1 = {
    project_id = "project1"
    gke_service_account = "gke"
    cloud_services_service_account = "cloudsvc"
  }
  service_project_2 = {
    project_id = "project2"
  }
}

module "vpc-host" {
  source     = "./modules/net-vpc"
  project_id = "my-project"
  name       = "my-host-network"
  subnets = [
    {
      ip_cidr_range = "10.0.0.0/24"
      name          = "subnet-1"
      region        = "europe-west1"
      secondary_ip_range = {
        pods     = "172.16.0.0/20"
        services = "192.168.0.0/24"
      }
    }
  ]
  shared_vpc_host = true
  shared_vpc_service_projects = [
    local.service_project_1.project_id,
    local.service_project_2.project_id
  ]
  iam = {
    "europe-west1/subnet-1" = {
      "roles/compute.networkUser" = [
        local.service_project_1.cloud_services_service_account,
        local.service_project_1.gke_service_account
      ]
      "roles/compute.securityAdmin" = [
        local.service_project_1.gke_service_account
      ]
    }
  }
}
# tftest:modules=1:resources=7
```

### Private Service Networking

```hcl
module "vpc" {
  source     = "./modules/net-vpc"
  project_id = "my-project"
  name       = "my-network"
  subnets = [
    {
      ip_cidr_range      = "10.0.0.0/24"
      name               = "production"
      region             = "europe-west1"
      secondary_ip_range = null
    }
  ]
  psn_ranges = ["10.10.0.0/16"]
}
# tftest:modules=1:resources=4
```

### DNS Policies

```hcl
module "vpc" {
  source     = "./modules/net-vpc"
  project_id = "my-project"
  name       = "my-network"
  dns_policy = {
    inbound  = true
    logging  = false
    outbound = {
      private_ns = ["10.0.0.1"]
      public_ns  = ["8.8.8.8"]
    }
  }
  subnets = [
    {
      ip_cidr_range      = "10.0.0.0/24"
      name               = "production"
      region             = "europe-west1"
      secondary_ip_range = {}
    }
  ]
}
# tftest:modules=1:resources=3
```

### Subnet Factory
The `net-vpc` module includes a subnet factory (see [Resource Factories](../../examples/factories/)) for the massive creation of subnets leveraging one configuration file per subnet.


```hcl
module "vpc" {
  source      = "./modules/net-vpc"
  project_id  = "my-project"
  name        = "my-network"
  data_folder = "config/subnets"
}
# tftest:skip
```

```yaml
# ./config/subnets/subnet-name.yaml
region: europe-west1
description: Sample description
ip_cidr_range: 10.0.0.0/24
# optional attributes
private_ip_google_access: false   # defaults to true
iam_users: ["foobar@example.com"] # grant compute/networkUser to users
iam_groups: ["lorem@example.com"] # grant compute/networkUser to groups
iam_service_accounts: ["fbz@prj.iam.gserviceaccount.com"]
secondary_ip_ranges:              # map of secondary ip ranges
  - secondary-range-a: 192.168.0.0/24
flow_logs:                        # enable, set to empty map to use defaults
  - aggregation_interval: "INTERVAL_5_SEC"
  - flow_sampling: 0.5
  - metadata: "INCLUDE_ALL_METADATA"
```


<!-- BEGIN TFDOC -->

## Variables

| name | description | type | required | default |
|---|---|:---:|:---:|:---:|
| name | The name of the network being created | <code>string</code> | ✓ |  |
| project_id | The ID of the project where this VPC will be created | <code>string</code> | ✓ |  |
| auto_create_subnetworks | Set to true to create an auto mode subnet, defaults to custom mode. | <code>bool</code> |  | <code>false</code> |
| data_folder | An optional folder containing the subnet configurations in YaML format. | <code>string</code> |  | <code>null</code> |
| delete_default_routes_on_create | Set to true to delete the default routes at creation time. | <code>bool</code> |  | <code>false</code> |
| description | An optional description of this resource (triggers recreation on change). | <code>string</code> |  | <code>&#34;Terraform-managed.&#34;</code> |
| dns_policy | DNS policy setup for the VPC. | <code title="object&#40;&#123;&#10;  inbound &#61; bool&#10;  logging &#61; bool&#10;  outbound &#61; object&#40;&#123;&#10;    private_ns &#61; list&#40;string&#41;&#10;    public_ns  &#61; list&#40;string&#41;&#10;  &#125;&#41;&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code>null</code> |
| iam | Subnet IAM bindings in {REGION/NAME => {ROLE => [MEMBERS]} format. | <code>map&#40;map&#40;list&#40;string&#41;&#41;&#41;</code> |  | <code>&#123;&#125;</code> |
| log_config_defaults | Default configuration for flow logs when enabled. | <code title="object&#40;&#123;&#10;  aggregation_interval &#61; string&#10;  flow_sampling        &#61; number&#10;  metadata             &#61; string&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code title="&#123;&#10;  aggregation_interval &#61; &#34;INTERVAL_5_SEC&#34;&#10;  flow_sampling        &#61; 0.5&#10;  metadata             &#61; &#34;INCLUDE_ALL_METADATA&#34;&#10;&#125;">&#123;&#8230;&#125;</code> |
| log_configs | Map keyed by subnet 'region/name' of optional configurations for flow logs when enabled. | <code>map&#40;map&#40;string&#41;&#41;</code> |  | <code>&#123;&#125;</code> |
| mtu | Maximum Transmission Unit in bytes. The minimum value for this field is 1460 and the maximum value is 1500 bytes. | <code></code> |  | <code>null</code> |
| peering_config | VPC peering configuration. | <code title="object&#40;&#123;&#10;  peer_vpc_self_link &#61; string&#10;  export_routes      &#61; bool&#10;  import_routes      &#61; bool&#10;&#125;&#41;">object&#40;&#123;&#8230;&#125;&#41;</code> |  | <code>null</code> |
| peering_create_remote_end | Skip creation of peering on the remote end when using peering_config | <code>bool</code> |  | <code>true</code> |
| psn_ranges | CIDR ranges used for Google services that support Private Service Networking. | <code>list&#40;string&#41;</code> |  | <code>null</code> |
| routes | Network routes, keyed by name. | <code title="map&#40;object&#40;&#123;&#10;  dest_range    &#61; string&#10;  priority      &#61; number&#10;  tags          &#61; list&#40;string&#41;&#10;  next_hop_type &#61; string &#35; gateway, instance, ip, vpn_tunnel, ilb&#10;  next_hop      &#61; string&#10;&#125;&#41;&#41;">map&#40;object&#40;&#123;&#8230;&#125;&#41;&#41;</code> |  | <code>&#123;&#125;</code> |
| routing_mode | The network routing mode (default 'GLOBAL') | <code>string</code> |  | <code>&#34;GLOBAL&#34;</code> |
| shared_vpc_host | Enable shared VPC for this project. | <code>bool</code> |  | <code>false</code> |
| shared_vpc_service_projects | Shared VPC service projects to register with this host | <code>list&#40;string&#41;</code> |  | <code>&#91;&#93;</code> |
| subnet_descriptions | Optional map of subnet descriptions, keyed by subnet 'region/name'. | <code>map&#40;string&#41;</code> |  | <code>&#123;&#125;</code> |
| subnet_flow_logs | Optional map of boolean to control flow logs (default is disabled), keyed by subnet 'region/name'. | <code>map&#40;bool&#41;</code> |  | <code>&#123;&#125;</code> |
| subnet_private_access | Optional map of boolean to control private Google access (default is enabled), keyed by subnet 'region/name'. | <code>map&#40;bool&#41;</code> |  | <code>&#123;&#125;</code> |
| subnets | List of subnets being created. | <code title="list&#40;object&#40;&#123;&#10;  name               &#61; string&#10;  ip_cidr_range      &#61; string&#10;  region             &#61; string&#10;  secondary_ip_range &#61; map&#40;string&#41;&#10;&#125;&#41;&#41;">list&#40;object&#40;&#123;&#8230;&#125;&#41;&#41;</code> |  | <code>&#91;&#93;</code> |
| subnets_l7ilb | List of subnets for private HTTPS load balancer. | <code title="list&#40;object&#40;&#123;&#10;  active        &#61; bool&#10;  name          &#61; string&#10;  ip_cidr_range &#61; string&#10;  region        &#61; string&#10;&#125;&#41;&#41;">list&#40;object&#40;&#123;&#8230;&#125;&#41;&#41;</code> |  | <code>&#91;&#93;</code> |
| vpc_create | Create VPC. When set to false, uses a data source to reference existing VPC. | <code>bool</code> |  | <code>true</code> |

## Outputs

| name | description | sensitive |
|---|---|:---:|
| bindings | Subnet IAM bindings. |  |
| name | The name of the VPC being created. |  |
| network | Network resource. |  |
| project_id | Project ID containing the network. Use this when you need to create resources *after* the VPC is fully set up (e.g. subnets created, shared VPC service projects attached, Private Service Networking configured). |  |
| self_link | The URI of the VPC being created. |  |
| subnet_ips | Map of subnet address ranges keyed by name. |  |
| subnet_regions | Map of subnet regions keyed by name. |  |
| subnet_secondary_ranges | Map of subnet secondary ranges keyed by name. |  |
| subnet_self_links | Map of subnet self links keyed by name. |  |
| subnets | Subnet resources. |  |
| subnets_l7ilb | L7 ILB subnet resources. |  |

<!-- END TFDOC -->


The key format is `subnet_region/subnet_name`. For example `europe-west1/my_subnet`.
