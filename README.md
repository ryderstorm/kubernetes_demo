# Kubernetes Demo

The code in this project is a demo of deploying Kubernetes applications using Terraform and AWS EKS. It includes scripts for building Docker images, creating an EKS cluster, and deploying the demo apps to the cluster.

It also includes scripts for setting up a local Kubernetes cluster using k3s.

## Requirements

### Required Apps

The following apps are required to run the demo:

| App       | URL                                                     | Description                                                                                                  |
| --------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Docker    | https://www.docker.com/                                 | Docker is used to build the Docker images for the demo apps.                                                 |
| AWS CLI   | https://aws.amazon.com/cli/                             | The AWS CLI is used to create the EKS cluster.                                                               |
| kubectl   | https://kubernetes.io/docs/tasks/tools/install-kubectl/ | kubectl is used to interact with the Kubernetes cluster.                                                     |
| Terraform | https://www.terraform.io/                               | Terraform is used to create the EKS cluster.                                                                 |
| Helm      | https://helm.sh/                                        | Helm is used to deploy the demo apps to the Kubernetes cluster.                                              |
| k9s       | https://k9scli.io/                                      | k9s is a command line tool for interacting with Kubernetes clusters.                                         |
| k3s       | https://k3s.io/                                         | k3s is a lightweight Kubernetes distribution used to provide a local development environment for Kubernetes. |

:information_source: **Note:** k3s is only necessary for the local development environment. It is not required for deploying the demo apps to AWS EKS. The `setup_k3s.sh` script will install k3s for you, so you don't need to install it manually.

### Docker Credentials

Images for the demo apps are already present in Docker Hub. If you run into rate limits while experimenting with the cluster, you'll need to set up a Docker Hub account and configure Docker to use your Docker Hub credentials.

You can set up the credentials by running `docker login` and entering your Docker Hub credentials. These credentials will then be used by the cluster to pull the Docker images and avoid rate limits.

This issue will be addressed in a future enhancement by setting up a Docker registry in the cluster and pushing the images to that registry.

## Demo Apps

The demo apps are simple web applications used to demonstrate how to deploy applications to Kubernetes. The demo apps are deployed to the cluster using a combination of Terraform, Helm, and kubectl.

The demo apps are:

| App             | URL                                        | Description                                                                                                          |
| --------------- | ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| Traefik         | https://traefik.io/                        | Traefik is a modern HTTP reverse proxy and load balancer used to route traffic to the demo apps.                     |
| whoami          | https://github.com/traefik/whoami          | Tiny Go webserver that prints OS information and HTTP request to output.                                             |
| Nginx Hello     | https://hub.docker.com/r/nginxdemos/hello/ | Simple web app that prints "Hello World" and the hostname of the container.                                          |
| 2048 Game       | https://github.com/alexwhen/docker-2048    | 2048 is a single-player sliding block puzzle game. The container runs a web server that hosts the game.              |
| Demo Client App | see `apps/timestamp-server`                | Simple web API that responds with a message and a timestamp.                                                         |
| Ubuntu Testbed  | see `apps/ubuntu-testbed`                  | Ubuntu container with a bash shell and diganostic tools installed. Used for testing connectivity within the cluster. |

### Building Docker Images for the Demo Apps

> :warning: :warning::warning:
> This functionality is currently WIP. The script will build the Docker images, but it will fail when attempting to push them to a Docker registry because the script is dependent on my own docker credentials.
>
> A future enhancement will add a Docker registry to the Kubernetes cluster and push the images to that registry.
>
> For now, the images already exist in Docker Hub, so you can skip this step and use the existing images.

Before you can deploy the demo apps to Kubernetes, you'll need to build the Docker images for the demo apps. To do this, run the build script:

```bash
./bin/build_docker_images.sh
```

## Using k3s for Local Development

k3s is a lightweight Kubernetes distribution. It is a single binary that provides a fully compliant Kubernetes API server and Kubernetes controller components. This project uses k3s to provide a local development environment for Kubernetes.

### Install k3s, set up local cluster, and deploy Traefik and demo apps

Run the script to install k3s and set up the local k8s cluster:

```bash
./bin/setup_k3s.sh
```

The script will output information about the cluster and the demo apps. You can use this information to access the demo apps and access the Kubernetes dashboard.

### Update hosts file for local domains

You'll need to update your `/etc/hosts` file to access the demo apps via the local domain. The script will output the IP address to use for the local domain along with the local domain names for the demo apps.

### Uninstall k3s

Run the script to uninstall k3s and remove the local cluster.

```bash
/usr/local/bin/k3s-uninstall.sh
```

### k3s References

- [k3s](https://k3s.io/)
- [k3s Documentation](https://docs.k3s.io/installation)

## Deploying a Kubernetes cluster using Terraform and AWS EKS

### Prerequisites

Before running the script, make sure that you have the AWS CLI installed and configured with your AWS credentials

### Optional: set up a new AWS user for the demo

If you want to set up a new AWS account for the demo to keep your resources separate, you can use the `bin/setup_aws_user.sh` script. This script automates the process of creating a new AWS user and configuring the AWS CLI to use the new user.

You can customize the settings of the new AWS user by modifying the `lib/set_envs.sh` script or passing in the following environment variables:

| Environment Variable | Description                                                               |
| -------------------- | ------------------------------------------------------------------------- |
| IAM_USER_NAME        | The name of the IAM user to create.                                       |
| POLICY_NAME          | The name of the IAM policy to create for the user.                        |
| AWS_REGION           | The AWS region to use for the new user.                                   |
| POLICY_FILE_PATH     | The path to the file containing the IAM policy to be applied to the user. |

To delete the AWS user, run the script again with the 'delete' command:

```bash
./bin/setup_aws_user.sh delete
```

### Creating the EKS cluster

Before creating the cluster, you can set up a monitor the state of the resources by running the monitoring script in a separate terminal window:

```bash
./bin/list_aws_resources.sh watch
```

To create the EKS cluster, run the following script:

```bash
./bin/setup_eks_cluster.sh
```

The script will create an EKS cluster with the default settings and configure `kubectl` to connect to the cluster. You can customize the settings of the EKS cluster by modifying the `lib/set_envs.sh` script.

You will see the resources being created in the terminal window where you are running the `list_aws_resources.sh` script. Once the cluster has been created, the script will begin deploying the demo apps to the cluster.

The script will output information about the cluster and the demo apps. You can use this information to access the demo apps and access the Kubernetes dashboard.

### Destroying the EKS cluster

To delete the EKS cluster, run the following script:

```bash
./bin/destroy_eks_cluster.sh
```

This script automates the process of deleting the EKS cluster.

## Running cluster validation tests

To run the tests to validate the demo apps are working in the cluster, run the following script:

```bash
./bin/run_tests.sh
```

## Interacting with the cluster

### Using kubectl

After the cluster has been created, you can use the `kubectl` command line tool to interact with the cluster. To install `kubectl`, run the following command:

```bash
brew install kubectl
```

Once `kubectl` has been installed, you can run the following command to test the connection to the cluster:

```bash
kubectl get nodes
```

Check out the [kubectl cheat sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/) for more information on using `kubectl`.

### Using k9s

After the cluster has been created, you can use the `k9s` command line tool to interact with the cluster. To install `k9s`, run the following command:

```bash
brew install derailed/k9s/k9s
```

Once `k9s` has been installed, you can run the following command to connect to the cluster:

```bash
k9s
```

Check out the [k9s documentation](https://k9scli.io/) for more information on using `k9s`.

## Load testing the cluster during an app update

We'll use the timestamp app to demonstrate the cluster's ability to maintain service during an app update.

### Order of operations

1. Run the monoitoring scrpt to monitor the timestamp app endpoint

- ```bash
  ./bin/endpoint_monitor.sh
  ```

2. Scale the endpoint up to 5 replicas
3. Make a change in `apps/timestamp-server/server.rb` that affects the output of the timestamp app on the `/` endpoint
4. Commit the change so that the build image script will generate a new tag for the image
5. Run the docker build script to build and push a new image with the updated code

- ```bash
  PUSH_IMAGES=true ./bin/build_docker_images.sh
  ```

6. Update the timestamp server deployment in your cluster to use the new image:

- ```bash
  kubectl set image -n demo-apps deployment/timestamp timestamp=ryderstorm/xyz-demo-timestamp-server:$(git rev-parse --short HEAD)
  ```

Watch the output of the monitoring script to verify that the timestamp app endpoint is still available during the update and seamlessly switches to the new version of the app.

> :warning: Don't forget to revert the change to `apps/timestamp-server/server.rb` after you're done testing.
