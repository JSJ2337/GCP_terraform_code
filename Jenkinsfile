pipeline {
    agent any

    environment {
        TF_IN_AUTOMATION = 'true'
    }

    stages {
        stage('Checkout') {
            steps {
                echo "✅ Repository checked out successfully"
                echo "Branch: ${env.GIT_BRANCH}"
                echo "Commit: ${env.GIT_COMMIT}"
            }
        }

        stage('Environment Check') {
            steps {
                echo '🔍 Checking installed tools...'
                sh 'terraform --version'
                sh 'terragrunt --version'
                sh 'git --version'
            }
        }

        stage('List Files') {
            steps {
                echo '📁 Repository structure:'
                sh 'ls -la'
                sh 'pwd'
            }
        }

        stage('Test Success') {
            steps {
                echo '🎉 Pipeline test completed successfully!'
                echo "Triggered by: ${env.BUILD_USER_ID ?: 'GitHub Webhook'}"
            }
        }
    }

    post {
        success {
            echo '✅ Build completed successfully!'
        }
        failure {
            echo '❌ Build failed!'
        }
        always {
            echo '🏁 Pipeline finished'
        }
    }
}
