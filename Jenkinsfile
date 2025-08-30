pipeline {
  agent any
  tools { maven 'Maven_3.9' }

  environment {
    PATH = "/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:${PATH}"
    DOCKER_IMAGE = "assugan/diploma-app"     // репозиторий в DockerHub должен существовать
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

    stage('Docker Build') {
      steps {
        sh '''
          set -euxo pipefail
          echo "--- docker version ---"
          docker version
          echo "--- building image ---"
          docker build -t $DOCKER_IMAGE:$BUILD_NUMBER -f docker/Dockerfile .
          echo "--- images (top 5) ---"
          docker images | head -n 5
        '''
      }
    }

    stage('Docker Login & Push') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            set -euxo pipefail
            echo "--- docker login ---"
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin
            echo "--- pushing tags ---"
            docker push $DOCKER_IMAGE:$BUILD_NUMBER
            docker tag  $DOCKER_IMAGE:$BUILD_NUMBER $DOCKER_IMAGE:latest
            docker push $DOCKER_IMAGE:latest
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
          echo "--- ansible version ---"
          which ansible || true
          ansible --version || true
          echo "--- inventory preview ---"
          ansible-inventory -i ansible/inventory.ini --list | head -n 30 || true

          echo "--- playbook ---"
          ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
            --extra-vars "docker_image=$DOCKER_IMAGE:$BUILD_NUMBER"
        '''
      }
    }
  }

  post {
    success { echo '✅ Build, Push and Deploy successful!' }
    failure { echo '❌ Build failed! См. подробные логи выше (включён set -euxo pipefail).' }
  }
}