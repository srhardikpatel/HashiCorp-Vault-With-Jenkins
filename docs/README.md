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

Before starting, ensure you have: </br>

&emsp;&emsp;• AWS Account <br/>
&emsp;&emsp;• EC2 Instance <br/>
&emsp;&emsp;• Vault Server Installed <br/>
&emsp;&emsp;• Jenkins Installed <br/>
&emsp;&emsp;• Terraform Installed <br/>
&emsp;&emsp;• Access to port **8080** (Jenkins) and **8200** (Vault server) in security group. <br/>
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
sudo apt update && sudo apt install vault
```

# Step 1 - Create a Permissions Policy for Role in AWS

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "ec2:*",
            "Resource": "*"
        }
    ]
}
```

Example policy name:

``` 
ec2-access-policy
```

# Step 2 — Create a Role in AWS

Create an IAM role with custom trust policy.

```
{
    "Version"        : "2012-10-17",
    "Statement"      : [{
      "Action"       : "sts:AssumeRole",
      "Effect"       : "Allow",
      "Principal"    : {
        "AWS"        : "arn:aws:iam::<AccountId>:root"
       }
     }]
}
```
> Replace the `AccountId` with your aws account id.

Example role name:

``` 
jenkins-ec2-role
```

# Step 3 - Attach Permissions Policy(ec2-access-policy) to Role(jenkins-ec2-role)

&emsp;&emsp;&emsp;&emsp;![Alt text]({{"/assets/images/permission_policy.png" | relative_url}})

# Step 4 - Create a Permissions Policy for User

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
      "Resource": ["arn:aws:iam::<AccountId>:role/jenkins-ec2-role"]
    }
  ]
}
```
> Replace the `AccountId` with your aws account id.

Example policy name:

``` 
vault-policy
```

# Step 5 — Create User with the policy(created in Step 4) attached.

&emsp;&emsp;&emsp;&emsp;![Alt text]({{"/assets/images/user.png" | relative_url}})

Example user name:

``` 
vault-user
```

# Step 6 - Create Access key for the User(vault-user) created in Step 5.

&emsp;&emsp;&emsp;&emsp;![Alt text]({{"/assets/images/accesskey.png" | relative_url}})

# Step 7 - Start the Vault dev server

> SSH into an Amazon EC2 instance and paste below line.

```
vault server -dev -dev-root-token-id root -dev-listen-address="0.0.0.0:8200" > vault.log 2>&1 &
```
This command starts a HashiCorp Vault server in development mode with specific configurations for security, access tokens, and network binding.

***Here is the step-by-step breakdown of what each part of the command does:***

`vault server` - This is the base command telling the Vault CLI to start a Vault server process.

`-dev` - Switches Vault into Development Mode. **What it does**: It runs entirely in-memory (all data is lost when the server stops), automatically unseals the vault, and pre-configures a root token.

⚠️ Warning: Never use this flag in a production environment. It bypasses crucial production security practices for the sake of local testing speed.

`-dev-root-token-id root` - By default, development mode generates a random, complex string to use as the root token.
This flag overrides that behavior and explicitly sets the initial root token to the string root.
This makes it incredibly easy to log in during local development (e.g., running vault login root), but is highly insecure for real environments.

`-dev-listen-address="0.0.0.0:8200"` - This tells the Vault server which network interface and port to listen on.

**0.0.0.0**: This means Vault will listen on all available network interfaces. Anyone who can reach your machine's IP address over the network can attempt to connect to this Vault instance.
(The default behavior is usually 127.0.0.1, which restricts access strictly to your local machine).

**:8200**: This specifies the standard TCP port that Vault listens on.

`> vault.log` - This redirects Standard Output (1) to a file named vault.log

`2>&1` - This redirects Standard Error (2) to the same destination as Standard Output (1).

`&` - The single ampersand at the very end tells the shell to run the entire command in the background.

# Step 8 - Export environment variable

```
export VAULT_ADDR='http://0.0.0.0:8200'
```

# Step 9 - Enable AWS Secrets Engine

```
vault secrets enable aws
```

# Step 10 - Configure AWS root credentials

```
vault write aws/config/root \
    access_key=<access-key> \
    secret_key=<secret-key> \
    region=<region>
```
> Replace `access-key` and `secret-key` with the `access-key` and `secret-key` from step-6. </br>
  Use `region` of your choice.

# Step 11 - Create Dynamic AWS Role

```
vault write aws/roles/jenkins-role \
    credential_type=assumed_role \
    role_arns=arn:aws:iam::<AccountId>:role/jenkins-ec2-role \
    max_ttl=1h
```

Example role name:

```
jenkins-role
```

***Here is a step-by-step breakdown of what each part of the command is doing:***

`vault write` - This tells Vault to write (create or update) configuration data at a specific path.

`aws/roles/jenkins-role` - This is the path where the configuration is stored.

 **aws/**: Specifies that you are interacting with the AWS Secrets Engine.
 
 **roles/jenkins-role**: Creates or updates a Vault role named `jenkins-role`.
(Note: This is a Vault role, which acts as a blueprint for generating temporary AWS credentials).

`credential_type=assumed_role` - This determines the method Vault will use to generate AWS credentials. By setting it to `assumed_role`, Vault will call the AWS Security Token
Service (STS) AssumeRole API. Instead of creating a brand new `IAM` user, Vault will return temporary AWS security credentials (an Access Key, Secret Key, and Session Token) by assuming
an existing IAM role.

`role_arns=arn:aws:iam::123456789012:role/jenkins-ec2-role` - This is the target AWS IAM role that Vault is allowed to assume.
When a user or application (like Jenkins) requests credentials from Vault's `jenkins-role`, Vault will assume this specific AWS role (`jenkins-ec2-role` inside AWS account).

`max_ttl=1h` - This sets the Maximum Time-To-Live for the generated credentials to 1 hour. Any temporary credentials generated through this Vault role will automatically expire
and become invalid after one hour, and they cannot be renewed beyond this limit.

# Step 12 - Enable AWS Authentication in Vault

```
vault auth enable aws
```

# Step 13 - Configure Vault AWS client

```
vault write auth/aws/config/client \
    access_key=<access-key> \
    secret_key=<secret-key> \
    region=<region>
```
> Replace `access-key` and `secret-key` with the `access-key` and `secret-key` from step-6. </br>
  Use the same 'region' selected in step 10.

# Step 14 - Create Vault Policy for Jenkins

***Create policy file (jenkins-policy.hcl)***

```
path "aws/creds/jenkins-role" {
  capabilities = ["read"]
}
```

***Write policy***

```
vault policy write jenkins-policy jenkins-policy.hcl
```

Example policy name:

```
jenkins-policy
```

# Step 15 - Configure Jenkins Authentication Role in Vault

```
vault write auth/aws/role/jenkins \
    auth_type=iam \
    bound_iam_principal_arn=arn:aws:iam::<AccountId>:user/vault-user \
    policies=jenkins-policy
    max_ttl=1h
```

Example role name:

```
jenkins
```

***Here is a step-by-step breakdown of what each part of the command is doing:***

`vault write` - Tells Vault to create or update configuration data at a specific path.

`auth/aws/role/jenkins` - This targets the AWS Authentication Method in Vault.

**auth/aws/** - Interacts with the AWS auth backend (which must be enabled beforehand).

**role/jenkins** - Creates or updates a Vault auth role named `jenkins`. When Jenkins wants to log in, it will reference this specific role.

`auth_type=iam` - Specifies that Vault should use AWS `IAM-based` authentication (instead of `ec2` instance metadata authentication).
When Jenkins attempts to log in, it will send a signed AWS API request (STS GetCallerIdentity) to Vault.
Vault will then check with AWS to verify that the request genuinely came from the claimed IAM identity.

`bound_iam_principal_arn` - This is a security guardrail. It tells Vault: "Only allow a login to this `jenkins` role if the AWS identity making the request matches this
exact IAM User (vault-user)." If any other AWS user or role tries to use this Vault login path, Vault will reject it.

`policies=jenkins-policy` - Specifies the Vault policies that will be attached to the token Jenkins receives upon a successful login.
In this case, Jenkins will be granted the permissions defined inside the pre-existing Vault policy named `jenkins-policy` (e.g., permission to read specific secrets).

# Step 16 - Vault Login

```
vault login -method=aws role=jenkins \
    aws_access_key_id=<access-key> \
    aws_secret_access_key=<secret-key>
```
> Save the output somewhere.

# Step 17 - Configure Jenkins
  
```
http://<ec2-Instance-ip>:8080
```
Go to:
```
Manage Jenkins → Plugins
```
Install:

&emsp;&emsp;• HashiCorp Vault <br/>

# Step 18 - Configure Vault Token in Jenkins

Go to:
```
Credentials → Vault Token Credential
```
&emsp;&emsp;&emsp;&emsp;![Alt text]({{"/assets/images/token.png" | relative_url}})

Set Token = value of token from the step 16 saved output

Example ID value:

```
vault-token
```

# Step 19 - Create Jenkins Pipeline

Example Jenkinsfile:

```
def configuration = [
    vaultUrl: 'http://<ec2-Instance-ip>:8200',
    vaultCredentialId: 'vault-token',
    engineVersion: 1,
    skipSslVerification: true
]
def secrets = [
    [path: 'aws/creds/jenkins-role', 
            secretValues: [
                [vaultKey: 'access_key', envVar: 'AWS_ACCESS_KEY_ID'],
                [vaultKey: 'secret_key', envVar: 'AWS_SECRET_ACCESS_KEY'],
                [vaultKey: 'session_token', envVar: 'AWS_SESSION_TOKEN']
            ]
    ]
]

pipeline {
    agent any
    stages {
        stage('Vault Secrets') {
            steps {
                withVault([configuration: configuration, vaultSecrets: secrets]) {
                    sh 'terraform init'
                    sh 'terraform plan -out=tfplan'
                    sh 'terraform apply -auto-approve tfplan'
//                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }
}
```

# Step 20 - Terraform file to create EC2 Instance

```
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.24"
    }
  }
  required_version = ">=1.14"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "jenkins" {
  ami           = "ami-091138d0f0d41ff90"
  instance_type = "t3.micro"

  tags = {
    Name = "jenkins-server"
  }
}
```

# Thank you for reading.

Feel free to reach out, share your thoughts, or ask any questions. I look forward to connecting and growing together in this dynamic field!

***Connect With Me On LinkedIn:*** [srhardikpatel](https://www.linkedin.com/in/srhardikpatel/)
