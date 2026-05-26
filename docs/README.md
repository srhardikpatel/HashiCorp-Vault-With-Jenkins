# 1. AWS Setup
&emsp;***1. Create Security Groups with the Following Rules***  <br/><br/>
&emsp;&emsp;&emsp;&emsp;•	***Control Plane Security Group***  <br/>

&emsp;&emsp;&emsp;&emsp;![image](https://miro.medium.com/v2/resize:fit:600/format:webp/1*NHSP_x0rlAT2ZBvSlZHNgA.png)

&emsp;&emsp;&emsp;&emsp;•	***Worker Node Security Group***  <br/>

&emsp;&emsp;&emsp;&emsp;![image](https://miro.medium.com/v2/resize:fit:600/format:webp/1*tnUZtVzoRks6ssQaqBRQ2g.png)

&emsp;***2.	Launch Two EC2 Instances using above security group:***  <br/><br/>
&emsp;&emsp;•	***Control Plane Node***: Manages the Kubernetes cluster.  <br/>
&emsp;&emsp;•	***Worker Node***: Hosts application workloads.<br/><br/>

![image](https://miro.medium.com/v2/resize:fit:800/format:webp/1*nDtPbwcVdaScon2LHtHjxQ.png)

# 2. Set Up the Control Plane and Worker Node

> To run containers in Pods, Kubernetes uses a container runtime.
  By default, Kubernetes uses the Container Runtime Interface (CRI) to interface with your chosen container runtime.
  If you don't specify a runtime, kubeadm automatically tries to detect an installed container runtime by scanning through a list of known endpoints.
  You need to install a container runtime into each node in the cluster so that Pods can run there.
  Kubernetes 1.35 requires that you use a runtime that conforms with the Container Runtime Interface (CRI).  <br/><br/>
  Several common container runtimes supported in Kubernetes.  <br/>
•	containerd  <br/>
•	CRI-O  <br/>
•	Docker Engine  <br/>
•	Mirantis Container Runtime  <br/>

## Execute on Both "Control Plane" & "Worker" Nodes
&emsp;***A.	Installation of Containerd.io as a container runtime***  <br/>

> Before you can install Docker Engine, you need to uninstall any conflicting packages.
  Your Linux distribution may provide unofficial Docker packages, which may conflict with the official packages provided by Docker. You must uninstall these packages before you install the official version of Docker Engine.  <br/><br/>
  The unofficial packages to uninstall are:  <br/>
•	docker.io  <br/>
•	docker-compose  <br/>
•	docker-compose-v2  <br/>
•	docker-doc  <br/>
•	podman-docker  <br/>

Moreover, Docker Engine depends on containerd and runc. Docker Engine bundles these dependencies as one bundle: `containerd.io`. If you have installed the containerd or runc previously, uninstall them to avoid conflicts with the versions bundled with Docker Engine.  <br/>
Run the following command to uninstall all conflicting packages:

```
sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)
```

Before you install Docker Engine for the first time on a new host machine, you need to set up the Docker apt repository. Afterward, you can install and update Docker from the repository.

```
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

#Install the Docker packages.

sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
```

The Docker service starts automatically after installation. To verify that Docker is running, use:
```
sudo systemctl status docker
```

Some systems may have this behavior disabled and will require a manual start:
```
sudo systemctl start docker
```

Verify that the installation is successful by running the hello-world image:
```
sudo docker run hello-world
```
  
&emsp;***B. Download CNI Plugin*** <br/>
  
> The network model is implemented by the container runtime on each node. The most common container runtimes use Container Network Interface (CNI) plugins to manage their network and security capabilities. Many     different CNI plugins exist from many different vendors. Some of these provide only basic features of adding and removing network interfaces, while others provide more sophisticated solutions, such as integration  with other container orchestration systems, running multiple CNI plugins, advanced IPAM features etc.

```
# Set version and architecture
CNI_PLUGIN_VERSION=v1.6.2
ARCH_CNI=$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)

# Download and extract
curl -L -O "https://github.com/containernetworking/plugins/releases/download/${CNI_PLUGIN_VERSION}/cni-plugins-linux-${ARCH_CNI}-${CNI_PLUGIN_VERSION}.tgz"
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-${ARCH_CNI}-${CNI_PLUGIN_VERSION}.tgz
```

&emsp;***C. Installing Kubeadm, Kubelet and Kubectl*** <br/>

&emsp;These instructions are for Kubernetes v1.35.

```
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

&emsp;***D. Configure the systemd cgroup Driver*** <br/>

To use the systemd cgroup driver in `/etc/containerd/config.toml` with runc, set the following config based on your Containerd version <br/>

Containerd versions 1.x:
```
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
  ...
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
    SystemdCgroup = true
```

Containerd versions 2.x:
```
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
  ...
  [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
    SystemdCgroup = true
```

You need CRI support enabled to use containerd with Kubernetes. Make sure that cri is not included in the `disabled_plugins` list within `/etc/containerd/config.toml`

Once you apply this change, make sure to restart containerd:
```
sudo systemctl restart containerd
```

&emsp;***E. Enable IPv4 Packet Forwarding*** <br/>
```
# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system
```

Verify that net.ipv4.ip_forward is set to 1 with:
```
sysctl net.ipv4.ip_forward
```

&emsp;***F. Run the Preflight Checks***

```
sudo kubeadm init phase preflight
```

>The SystemVerification component of the preflight check performs the following validations:  <br/><br/>
•	***OS/Kernel***: Ensures the OS is Linux and the kernel version meets minimum requirements.  <br/>
•	***Kernel Config***: Validates that required kernel modules are loaded and settings are applied.  <br/>
•	***Cgroups***: Checks that necessary Cgroups (cpu, memory, devices, etc.) are enabled and properly configured.  <br/>
•	***Container Runtime***: Checks for the presence and proper version of container runtimes (e.g., Docker, Containerd).  <br/>
•	***Hostname***: Ensures the hostname is reachable and formatted correctly.  <br/>
•	***Network***: Validates that bridge-nf-call-iptables is set to 1.  <br/>
•	***Directories***: Verifies that required Kubernetes directories like `/etc/kubernetes/manifests` are available and empty.  <br/>

## Execute Only on the "Control Plane"
&emsp;***1. Initialize the Control Plane***
```
sudo kubeadm init
```

Save the output of this command, which includes a kubeadm join command for adding worker nodes.

&emsp;***2. Install a Network Plugin (Calico)***
```
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.31.4/manifests/calico.yaml
kubectl apply -f calico.yaml
```

## Execute Only on the "Worker" Node
&emsp;***1. Join the Worker Node to the Cluster***

&emsp;Use the `kubeadm join` command you saved from the control plane initialization step.

> When pasting the join command from the control plane make sure either you are working as `sudo` user or use `sudo` at the beginning and `--v=5` at the end of the command.

Example format:
```
sudo <paste-join-command-here> --v=5
```

## Execute Only on the "Control Plane"
&emsp;***1. Set Up Local Kubeconfig***
```
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

&emsp;***2. Verify API Server Port***
```
nc <control-plane public-IP> 6443 -zv -w 2
```

&emsp;***3. Verify the Control Plane Node***
```
kubectl get nodes
```

Both nodes should now show Ready.

# 3. Deploy a Sample Application
&emsp;***1.	Create an Nginx Pod and Expose the Service***  <br/>

```
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --type=NodePort --port=80
```

&emsp;***2. Retrieve the NodePort of the Service***  <br/>

```
kubectl get svc nginx
```

&emsp;***3. Access the application from the browser using the worker node’s public IP and the NodePort***

```
http://<worker-node-public-ip>:<NodePort>
```

>We are using the worker node ip because the application is deployed on worker node.

You can now use the cluster to deploy and manage containerized applications. For further information, refer to the official [Kubernetes documentation](https://kubernetes.io/docs/home/).

Happy deploying! 🚀

Feel free to reach out, share your thoughts, or ask any questions. I look forward to connecting and growing together in this dynamic field!

***Connect With Me On LinkedIn:*** [srhardikpatel](https://www.linkedin.com/in/srhardikpatel/)
