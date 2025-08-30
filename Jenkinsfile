pipeline {
  agent any

  // Гарантируем Maven из Manage Jenkins → Tools (Имя: Maven_3.9)
  tools { maven 'Maven_3.9' }

  environment {
    // На macOS явно подсвечиваем путь к docker/ansible (если нужно)
    PATH = "/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:${PATH}"
    DOCKER_IMAGE = "assugan/diploma-app"
  }

  options { timestamps() }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/assugan/simple-java-project.git'
      }
    }

    stage('Build with Maven') {
      steps {
        sh 'mvn -f app/pom.xml clean package -DskipTests'
      }
    }

    stage('Run Tests') {
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
        sh 'docker build -t $DOCKER_IMAGE:$BUILD_NUMBER -f docker/Dockerfile .'
      }
    }

    stage('Docker Push') {
      steps {
        withDockerRegistry([credentialsId: 'dockerhub-creds', url: '']) {
          sh '''
            docker push $DOCKER_IMAGE:$BUILD_NUMBER
            docker tag  $DOCKER_IMAGE:$BUILD_NUMBER $DOCKER_IMAGE:latest
            docker push $DOCKER_IMAGE:latest
          '''
        }
      }
    }

    stage('Deploy to EC2') {
      steps {
        sh '''
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