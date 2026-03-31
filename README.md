[[_TOC_]]

# An EBSI blockchain network, including smart contracts and APIs

# Introduction
## What is EBSI?
The European Blockchain Services Infrastructure (EBSI) is an EU-led initiative to leverage blockchain technology for secure, efficient, and transparent cross-border public services. It supports use cases like digital identity, diploma verification, data sharing, and digital notarization, aligning with EU policies like the Digital Single Market. EBSI promotes interoperability, privacy, and trust in a decentralized manner.

**Useful Links:**
- [EBSI - European Commission](https://ec.europa.eu/digital-building-blocks/sites/display/EBSI/Home)
- [What is EBSI](https://ec.europa.eu/digital-building-blocks/sites/display/EBSI/What+is+ebsi)

## About this project
This project contains the necessary configuration to run an EBSI network in your own environment. 

This repository does NOT contain the code for the EBSI smart contracts, APIs, or any other EBSI services. Those will be cloned from different repositories and built into docker containers, as will be described in the installation section.

The EBSI network is mainly composed of 4 or more besu nodes, EBSI smart contracts and APIs that provide access to the EBSI smart contracts.

**This deployment includes:**
- Besu containers and configurations ([read more about Besu on their official page](https://besu.hyperledger.org/))
- Besu plugins (developed by EBSI)
- EBSI smart contracts
- APIs for interaction with the EBSI smart contracts
- An reverse proxy (traefik) for easy access to services

**Monitoring and healthcheck services are also included to help manage the network:**
- Healthcheck service for monitoring the health of the nodes
- Blockscout explorer for visibility on the blockchain block level ([read more about Blockscout on their official page](https://blockscout.com/))
- Starting Grafana dashboards for monitoring the network
- Monitoring with Prometheus and Grafana ([read more about Grafana on their official page](https://grafana.com/))


# Technical requirements
## Hardware
In order to run the EBSI network, we can propose a minimum hardware configuration, but in the end, it will depend on the number of nodes and the services you want to run.

**The default configuration we propose is:**
- 4 docker containers running besu (the minimum number of nodes for a network)
- 1 X APIs deployment
- 1 X Monitoring services deployment

| Resource | Minimum | Comments |
| ----------- | ----------- | ----------- |
| CPU | 4 | We recommend a score of minimum 650 points on SingleCPU and 1300 on MultiCPU scores measured with Geekbench 6 |
| RAM | 32GB | - | 
| DISK | 500GB | Must be SSD and we recommend min. 15k IOPs READ and 5k IOPs WRITE |

## Software
The network has been tested on Rocky Linux 8 and 9, but it should work on any other Linux distributions as well, due to the containerized nature of the services.

**The following software is required to be installed on the host VM:**
- Docker v.26+ (including docker compose)
- make

## Firewall
**The following ports need to be open on the host VM:**

| IP | Port | Protocol | Connection direction | Description |
| ----------- | ----------- | ----------- | ----------- | ----------- |
| 0.0.0.0/0 | 80/443 | TCP | Inbound | Allow connection to the APIs and to the monitoring stack from outside the VM |
| 0.0.0.0/0 | * | TCP/UDP | Outbound | Allows downloading the requirements for the project |


# Prepare environment and dependencies

## Install Docker
For detailed instructions on how to install Docker, please refer to the official Docker documentation: https://docs.docker.com/engine/install/
## Make sure you have the `make` command installed
The `make` command is used to simplify the process of building and running the containers. You can check if is installed by running:
```bash
make -v
```

## Clone the EBSI docker-compose repository
```bash
git clone https://code.europa.eu/ebsi/public/ebsi-node-docker-compose.git
cd ebsi-node-docker-compose
```

## Clone the EBSI source repositories

Either use the make command to clone the repos in the `sources/` subdirectory:
```bash
make clone_repos
```

Or run the `git clone` commands manually:
```bash
cd sources
git clone --branch main     https://code.europa.eu/ebsi/public/core-services            core-services
git clone --branch develop  https://code.europa.eu/ebsi/public/besu-plugins             besu-plugins
git clone --branch develop  https://code.europa.eu/ebsi/public/healthcheck              healthcheck
git clone --branch main     https://code.europa.eu/ebsi/public/validator-smart-contract validator-smart-contract
```

## Create the initial genesis file and keys for besu
```bash
cd ../
make setup
```

**This command will:**
- create a docker network for besu communication between nodes
- generate the genesis file and node keys
- set correct volume directory permissions for docker compose nodes


## Build the images from the cloned repositories
```bash
make build
```

# Deployment
*NOTE: The deployment is done using a `node` concept. Each `node` represents a separate docker network, in which are running services inside docker containers.*

## Option 1 (good for testing): Run the network on one VM

**Important:** we need 4 Besu instances to be running because this is the minimum to establish a consensus in an ethereum network.

### Run the services with the recommended configuration
**Node1:**
- 1 besu docker container
- 1 x API containers
- 1 x metric gathering service container

**Nodes 2-4:**
- 1 besu docker container

```bash
make up-light
```

### Deploy the APIs and the network on all nodes
**Node1:**
- 1 besu docker containers
- 1 x API containers
- 1 x metric gathering service container

**Nodes 2-4:**
- 1 besu docker container
- 1 x API containers
- 1 x metric gathering service container

```bash
make up
```  

## Deploy the smart contracts
```bash
make deploy_smart_contracts
```

## Option 2 (for production-like setup): Run the network on multiple VMs
In this scenario, each `node` represents an VM. Each VM will host one instance of besu, one instance of each API.

*NOTE: Each VM will have deployed only `node1`, as it requires only one besu and one instance of the APIs.*

### Overview

**Requirements:**
- port `48733` both UDP and TCP must be accessible between hosts for besu p2p communication
- port `48733` UDP/TCP must be open on the VM firewall if enabled
- 5 VMs (4 nodes + 1 infra monitoring VM)

**What the nodes VMs will contain:**
- 1 besu docker container
- 1 x API containers
- 1 x metric gathering service container


**What the Infra VM will contain:**
- prometheus/grafana stack for node metrics 

*NOTE: Each VM will run one of the 4 nodes contained in this deployment. VM-1 will run node 1, VM-2 will run node 2 etc.*

*NOTE: containers logs are not sent to the infra VM. We suggest you use a centralised log collection system such as loki or ELK if you wish to centrally collect container logs from all nodes. 

### Preparation
On all VMs, run all the steps from [Section 3 - Prepare environment and dependencies](#3-prepare-environment-and-dependencies).

### Copy the generated files from VM-1 to the other VMs
Pre-requisite: clone the repo on all VMs and reproduce all the steps, without starting the services.

From VM-1:
- copy the `./keys/genesis.json` file to the other VMs in the same location. We need to have the same `genesis.json` file on all nodes.
- copy the `./keys/node2/*` files to VM-2
- copy the `./keys/node3/*` files to VM-3
- copy the `./keys/node4/*` files to VM-4
- copy the `./keys/bootnode.env` file to VM-2
- copy the `./keys/bootnode.env` file to VM-3
- copy the `./keys/bootnode.env` file to VM-4

*Note: We will need the keys generated on VM-1 because they are set as initial validators in the genesis.json file. The network require a minimum of 4 validators to be functional.*

### Setup the IP of the bootnode and the listening IP
In order for BESU to be able to discover their peers, we will declare the IP of VM-1 to be the discovery node. The nodes will connect to this node and discover the other nodes in the network.

In `global.env` file, we need to fill in on VMs 1 to 4 the IP of the VM-1 in the `BESU_BOOTNODE_HOST` variable.
```bash
# VM-1:/path/to/global.env
BESU_BOOTNODE_HOST=<VM-1_PRIVATE_IP>
DOCKER_NODE_EXPOSE_PORTS_IP=0.0.0.0

# VM-2:/path/to/global.env
BESU_BOOTNODE_HOST=<VM-1_PRIVATE_IP>
DOCKER_NODE_EXPOSE_PORTS_IP=0.0.0.0

# VM-3:/path/to/global.env
BESU_BOOTNODE_HOST=<VM-1_PRIVATE_IP>
DOCKER_NODE_EXPOSE_PORTS_IP=0.0.0.0

# VM-4:/path/to/global.env
BESU_BOOTNODE_HOST=<VM-1_PRIVATE_IP>
DOCKER_NODE_EXPOSE_PORTS_IP=0.0.0.0
```

### Setup the advertised IP of each node
On each VM, go to `global.env` and set the variable `BESU_P2P_HOST` to the IP of the current VM, that other VMs can use to connect to it.
```bash
# VM-1:/path/to/global.env
BESU_P2P_HOST=<VM-1-IP>

# VM-2:/path/to/global.env
BESU_P2P_HOST=<VM-2-IP>

# VM-3:/path/to/global.env
BESU_P2P_HOST=<VM-3-IP>

# VM-4:/path/to/global.env
BESU_P2P_HOST=<VM-4-IP>
```

### Configure the infra monitoring
in `global.env` on all VMs (nodes + infra VM):
```
INFRA_PUSHPROX_DOMAIN=pushprox.monitoring.test
NODE_PUSHPROX_URL=pushprox.monitoring.test
```

in `infra/local.env` on the infra VM only:
```
GRAFANA_ADMIN_PASSWORD=<your grafana dashboard admin password>
PROMETHEUS_IP_ALLOWLIST=<csv of IP CIDR ranges to allow access to the prometheus dashboard>
PUSHPROX_IP_ALLOWLIST=<csv of IP CIDR ranges to allow the VM node public IPs to send their metrics>
```

in `infra/config/prometheus/prometheus.yml` on the infra VM only, replace the value of `proxy_url` with the domain of pushprox. 
Example:
```shell
proxy_url: http://pushprox.monitoring.test
```

### Setup the ports of each node
On each VM, go to `nodes/node{1,2,3,4}/local.env` and change the port to `48733`. (for vm-1 change /nodes/node1/local.env, vm-2 -> /nodes/node2/local.env etc.)
*Note: By default, each node has a different port so that it works when they run on the same VM.*

### Start the network
**VM-infra: Create docker networks**
```bash
make docker_networks
```
**VM-infra: Start the monitoring stack**
```bash
make -C infra upd
```

For each node VM, we start a different NODE and the light infra, used for sending metrics to VM 1.
**VM-1:**
```bash
make -C nodes/node1 upd
```

**VM-2:**
```bash
make -C nodes/node2 upd
```

**VM-3:**
```bash
make -C nodes/node3 upd
```

**VM-4:**
```bash
make -C nodes/node4 upd
```

## Deploy the smart contracts on VM-1
```bash
make deploy_smart_contracts
```

## For debugging, you can also start each node individually in the foreground
**Start monitoring containers:**
```bash
make -C infra up
```

**Start each node in the foreground (you need one terminal per command):**
```bash
make -C nodes/node1 up
make -C nodes/node2 up
make -C nodes/node3 up
make -C nodes/node4 up
```

## Useful commands to manage the network
**Stop all nodes and monitoring**
```bash
make down
```

**Reset generated genesis/keys and container data (nodes + monitoring)**
*NOTE: stop all nodes first*
```bash
make reset
```

**Delete built images**
```bash
make clean_images
```

**Wipe everything (all generated files, container data and all docker images, networks, etc.)**
```bash
make down
make nuke
```

# Accessing services
The APIs are accessible via a reverse proxy for each node, by default listening on the corresponding docker network gateway IP.

*IMPORTANT: If the deployment is multi-VM, below replace the IPs with the network IPs of each VM.*

**Add these entries in `/etc/hosts` to access services via the reverse proxies:**
```bash
# monitoring:
192.168.51.1 (or public IP of the VM)   dashboard.monitoring.test metrics.monitoring.test
# nodes:
192.168.55.1 (or public IP of the VM)   besu.node1.test api.node1.test app.node1.test proxy.node1.test blockchain.node1.test
192.168.56.1 (or public IP of the VM)   besu.node2.test api.node2.test app.node2.test proxy.node2.test
192.168.57.1 (or public IP of the VM)   besu.node3.test api.node3.test app.node3.test proxy.node3.test
192.168.58.1 (or public IP of the VM)   besu.node4.test api.node4.test app.node4.test proxy.node4.test
```
*NOTE: you can change the docker subnets in `global.env`*

**Then, you can then access services via:**

Complete documentation of API endpoints can be found here: [https://hub.ebsi.eu/apis](https://hub.ebsi.eu/apis)

- monitoring:
    - dashboards: http://dashboard.monitoring.test (login: `admin`, password: `admin`)
    - prometheus metrics: http://prometheus.monitoring.test
- node1:
    - blockscout: http://blockchain.node1.test (only available on node1)
    - health: http://api.node1.test/health
    - besu RPC API: http://besu.node1.test/jsonrpc
    - core services APIs: http://api.node1.test/<endpoint>
    - reverse proxy dashboard: http://proxy.node1.test
- node2:
    - health: http://api.node2.test/health
    - besu RPC API: http://besu.node2.test/jsonrpc
    - core services APIs: http://api.node2.test/<endpoint>
    - reverse proxy dashboard: http://proxy.node2.test
- node3:
    - health: http://api.node3.test/health
    - besu RPC API: http://besu.node3.test/jsonrpc
    - core services APIs: http://api.node3.test/<endpoint>
    - reverse proxy dashboard: http://proxy.node3.test
- node4:
    - health: http://api.node4.test/health
    - besu RPC API: http://besu.node4.test/jsonrpc
    - core services APIs: http://api.node4.test/<endpoint>
    - reverse proxy dashboard: http://proxy.node4.test

*NOTE: port numbers can be configured in `./nodes/node*/local.env`*


# Monitoring
We are using a set of components from Grafana Labs to ensure monitoring:
- prometheus
- Grafana (UI)
- pushprox master and client
  
Pushprox client is deployed on each node and is sending the metrics to pushprox master. Pushprox master is then sending the collected metrics from all nodes to prometheus, which is responsible for storing the data.
Then, the users can go to Grafana and see those metrics, by having Grafana querying the prometheus instance for metrics.

## Prometheus metrics exported for each node

**The following metrics are available:**
- besu clients:
    - prefix: `besu_`
    - doc: https://besu.hyperledger.org/public-networks/how-to/monitor/metrics#metrics-list
- node reverse proxies (traefik):
    - prefix: `traefik_`
    - doc: https://doc.traefik.io/traefik/observability/metrics/overview/
- node healthcheck service:
    - prefix: `health_*`
    - doc: see `http://localhost:3000/metrics` for an example from within one of the nodes `healthcheck` container
    - configuration: see healthcheck section below

## Configuration customisation
### To change the configuration of the network, you can modify the following files:
- global configuration: `./global.env`
- container images versions: `./versions.env`
- individual node configuration: `./nodes/node*/local.env`

### To change the configuration of the services, you can modify the following files:
**See configuration files in `./env/` corresponding to containers defined in `./base/`:**
- common to all nodes: `./env/all_nodes/common.env`
- common to all EBSI core-services APIs: `./env/all_nodes/core-services/common.env`
- specific to each API (when needed): `./env/all_nodes/core-services/<SERVICE>.env`

### Creating new monitoring dashboards (grafana)
Save new dashboards in `./infra/config/grafana/dashboards/` and restart the infra stack

**To easily create new dashboards:**
- create and edit new dashboard in grafana editor
- copy final dashboard json model from editor (settings -> json -> copy/paste)
- save to provisioning directory: `./infra/config/grafana/dashboards/<DASHBOARD_FILE>.json`

# Load balancing and WAF
If you are deploying 4 or more nodes that have APIs ready to be consumed, it makes sense to have a load balancer in front of them to ensure better service availability. For this, we provide an example of how this can be achieved using HAProxy:
[https://code.europa.eu/ebsi/public/reverse-proxy-waf-example](https://code.europa.eu/ebsi/public/reverse-proxy-waf-example)

In the repository above, there is also an example of implementation of WAF, using ModSecurity. You can follow the example there or you can comment out the parts related to ModSecurity from the HAProxy configuration file, depending on your needs.

# Security considerations
- This project doesn't enforce any authentication mechanism for BESU, so we strongly suggest that the port 48733 is opened only to the peers VM ips and NOT to the entire internet.

# Debugging
- To see if BESU is correctly connected to it's peers, you can set the variable `BESU_LOGGING=DEBUG` in order to see if the peers are connecting to the current server. This can be seen from grafana as well if is correctly configured.
- To check that the nodes can communicate on **UDP** on port 48733, we suggest using `nc -ul 48733` on the listening server and `nc -l <ip of listening server> 48733` and write a text to be sent. You should see the text being received on the first VM.
- To check that the nodes can communicate on **TCP** on port 48733, you can use nmap to check that the port is open `nmap -p 48733 <ip of target vm>`.
- inspect logs on docker containers using `docker logs -f <container name>`

## Development
Installation of pre-commit
```bash
brew install pre-commit
# cd /.../besu-plugins
pre-commit install
```

# How can I contribute?

If you are interested in contributing to the EBSI initiative you can submit improvement proposals through EBSI Improvement Proposals — also known as EBIPs. With EBIPs, you can give us your feedback and suggestions for changes, enhancements, or even new features for EBSI’s specifications.

You can read more about it [here](https://code.europa.eu/ebsi/ecosystem).
