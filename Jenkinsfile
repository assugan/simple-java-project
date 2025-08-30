pipeline {
  agent any
  tools { maven 'Maven_3.9' }

  environment {
    // На macOS добавляем пути к docker/ansible
    PATH = "/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:${PATH}"
    DOCKER_IMAGE = "assugan/diploma-app"     // репозиторий в DockerHub должен существовать
    EC2_IP = "18.197.110.98"                 // подставь актуальный публичный IP EC2
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

    stage('Docker Buildx (multi-arch) & Push') {
        steps {
            withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
            sh '''
                set -euxo pipefail

                echo "--- docker login ---"
                echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin

                echo "--- enable buildx ---"
                docker buildx create --name diploma_builder --use || true
                docker buildx inspect --bootstrap

                echo "--- build & push multi-arch (amd64 + arm64) ---"
                docker buildx build \
                --platform linux/amd64,linux/arm64 \
                -t $DOCKER_IMAGE:$BUILD_NUMBER \
                -t $DOCKER_IMAGE:latest \
                -f docker/Dockerfile \
                --push \
                .

                echo "--- logout ---"
                docker logout || true
            '''
            }
        }
    }

    stage('Deploy to EC2 (Ansible)') {
      steps {
        sh '''
          set -euxo pipefail

          echo "--- add EC2 host key to known_hosts ---"
          mkdir -p ~/.ssh
          ssh-keyscan -H $EC2_IP >> ~/.ssh/known_hosts

          echo "--- ansible version ---"
          which ansible || true
          ansible --version || true

          echo "--- inventory preview ---"
          ansible-inventory -i ansible/inventory.ini --list | head -n 30 || true

          echo "--- run playbook ---"
          ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
            --extra-vars "docker_image=$DOCKER_IMAGE:$BUILD_NUMBER"
        '''
      }
    }
  }

  post {
    success { echo '✅ Build, Push and Deploy successful!' }
    failure { echo '❌ Build failed! См. подробные логи выше.' }
  }
}