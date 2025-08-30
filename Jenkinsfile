pipeline {
  agent any
  tools { maven 'Maven_3.9' }

  environment {
    PATH = "/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:${PATH}"
    DOCKER_IMAGE = "assugan/diploma-app"
    EC2_IP = "3.121.162.244"
  }

  options { timestamps() }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/assugan/simple-java-project.git'
      }
    }

    stage('Build (Maven)') {
      steps {
        sh 'mvn -f app/pom.xml clean package -DskipTests'
      }
    }

    stage('Test (Maven)') {
      steps {
        sh 'mvn -f app/pom.xml test'
      }
      post {
        always {
          junit 'app/target/surefire-reports/*.xml'
        }
      }
    }

    stage('Docker Buildx & Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            set -euo pipefail
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            docker buildx create --name diploma_builder --use || true
            docker buildx inspect --bootstrap
            docker buildx build \
              --platform linux/amd64,linux/arm64 \
              -t "$DOCKER_IMAGE:$BUILD_NUMBER" \
              -t "$DOCKER_IMAGE:latest" \
              -f docker/Dockerfile \
              --push \
              .
            docker logout || true
          '''
        }
      }
    }

    stage('Deploy to EC2 (Ansible)') {
      steps {
        sh '''
          set -euo pipefail
          mkdir -p ~/.ssh
          ssh-keyscan -H "$EC2_IP" >> ~/.ssh/known_hosts
          ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
            --extra-vars "docker_image=$DOCKER_IMAGE:$BUILD_NUMBER"
        '''
      }
    }
  }

  post {
    success { echo '✅ Build, Push and Deploy successful!' }
    failure { echo '❌ Build failed!' }
  }
}