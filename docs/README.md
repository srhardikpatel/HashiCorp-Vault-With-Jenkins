# Overview

This guide demonstrates how to integrate HashiCorp Vault with Jenkins for secure secret management in CI/CD pipelines using: <br/><br/>
&emsp;&emsp;• AWS IAM Authentication Method <br/>
&emsp;&emsp;• AWS Secrets Engine <br/>
&emsp;&emsp;• Jenkins running on AWS EC2 <br/>
&emsp;&emsp;• Terraform for infrastructure provisioning <br/>
&emsp;&emsp;• Dynamic AWS credential generation <br/> 

Instead of storing long-term AWS Access Keys and secrets inside Jenkins, Vault dynamically generates temporary AWS credentials and securely injects them into Jenkins pipelines.

# Benefits

&emsp;&emsp;• No hardcoded AWS access keys <br/>
&emsp;&emsp;• Temporary dynamic credentials <br/>
&emsp;&emsp;• Centralized secret management <br/>
&emsp;&emsp;• Least privilege access <br/>
&emsp;&emsp;• Improved CI/CD security <br/>
&emsp;&emsp;• Automatic credential rotation <br/>


# Prerequisites

&emsp;&emsp; Before starting, ensure you have: </br>

&emsp;&emsp;• AWS Account <br/>
&emsp;&emsp;• EC2 Instance <br/>
&emsp;&emsp;• Vault Server Installed <br/>
&emsp;&emsp;• Jenkins Installed <br/>
&emsp;&emsp;• Terraform Installed <br/>
&emsp;&emsp;• Access to port `8080`(Jenkins) and `8200`(Vault server) in security group. <br/>
&emsp;&emsp;• IAM permissions to create: <br/>
&emsp;&emsp;&emsp;&emsp;• Roles <br/>
&emsp;&emsp;&emsp;&emsp;• Policies <br/>
&emsp;&emsp;&emsp;&emsp;• Users <br/>
&emsp;&emsp;&emsp;&emsp;• EC2 Instances <br/>

# Install Jenkins

```
sudo apt update
sudo apt install fontconfig openjdk-21-jre -y
java -version

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
sudo apt update
sudo apt install jenkins -y
```

# Install Terraform

```
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null


gpg --no-default-keyring \
--keyring /usr/share/keyrings/hashicorp-archive-keyring.gpg \
--fingerprint

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt-get install terraform
```

# Install Vault

```
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault
```

# Step 1 — Create IAM Role

&emsp;&emsp; Create an IAM role with custom trust policy.

```
{
    Version          = "2012-10-17"
    Statement        = [{
      Action         = "sts:AssumeRole"
      Effect         = "Allow"
      Principal      = {
        AWS          = "arn:aws:iam::<AccountId>:root"
      }
    }]
  }
```
> Replace the `AccountId` with your aws account id.

&emsp;&emsp; Example role name:

``` 
jenkins-ec2-role
```

# Step 2 - Create a Policy

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:GetUser",
        "iam:GetRole"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["sts:AssumeRole"],
      "Resource": ["arn:aws:iam::<AccountId>:role/<VaultRole>"]
    }
  ]
}
```
> Replace the `AccountId` with your aws account id and `VaultRole` with above created role name.

# Step 3 — Create USER with the policy(created in Step 2) attached.

# Step 4 - Create Access key for the USER created in Step 3.

&emsp;&emsp;&emsp;&emsp;![image](https://github.com/srhardikpatel/HashiCorp-Vault-With-Jenkins/blob/main/docs/assets/images/access%20key.png)

# Step 5 - Start the Vault dev server

> SSH into an Amazon EC2 instance and paste below line.

```
vault server -dev -dev-root-token-id root -dev-tls -dev-listen-address="0.0.0.0:8200" > vault.log 2>&1 &
```
> This command starts a HashiCorp Vault server in development mode with specific configurations for security, access tokens, and network binding.

***Here is the step-by-step breakdown of what each part of the command does:*** </br>

> `vault server` - This is the base command telling the Vault CLI to start a Vault server process. </br></br>
  `-dev` - Switches Vault into Development Mode. </br></br>
  **What it does**: It runs entirely in-memory (all data is lost when the server stops), automatically unseals the vault, and pre-configures a root token. </br>
  ⚠️ Warning: Never use this flag in a production environment. It bypasses crucial production security practices for the sake of local testing speed. </br></br>
  `-dev-root-token-id root` - By default, development mode generates a random, complex string to use as the root token.
   This flag overrides that behavior and explicitly sets the initial root token to the string root.
   This makes it incredibly easy to log in during local development (e.g., running vault login root), but is highly insecure for real environments. </br></br>
   `-dev-tls` - By default, running vault server -dev serves traffic over unencrypted HTTP. Adding the -dev-tls flag forces Vault to automatically generate a self-signed TLS certificate and
   serve traffic over HTTPS.
   This is highly useful if you need to test how your applications interact with Vault over a secure connection without setting up a formal Certificate Authority (CA) first. </br></br>
   `-dev-listen-address="0.0.0.0:8200"` - This tells the Vault server which network interface and port to listen on. </br></br>
   **0.0.0.0**: This means Vault will listen on all available network interfaces. Anyone who can reach your machine's IP address over the network can attempt to connect to this Vault instance.
   (The default behavior is usually 127.0.0.1, which restricts access strictly to your local machine). </br>
   **:8200**: This specifies the standard TCP port that Vault listens on. </br></br>
   `> vault.log` - This redirects Standard Output (1) to a file named vault.log </br></br>
   `2>&1` - This redirects Standard Error (2) to the same destination as Standard Output (1). </br></br>
   `&` - The single ampersand at the very end tells the shell to run the entire command in the background. </br></br>

# Step 6 - Export environment variable:

```

```

  























Feel free to reach out, share your thoughts, or ask any questions. I look forward to connecting and growing together in this dynamic field!

***Connect With Me On LinkedIn:*** [srhardikpatel](https://www.linkedin.com/in/srhardikpatel/)
