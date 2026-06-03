def configuration = [
    vaultUrl: 'http://3.238.162.196:8200',
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
                    sh 'echo "The secret is $AWS_ACCESS_KEY_ID"'
                    sh 'terraform init'
                    sh 'terraform plan -out=tfplan'
                    sh 'terraform apply -auto-approve tfplan'
//                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }
}
