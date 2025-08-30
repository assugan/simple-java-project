pipeline {
  agent any
  tools { maven 'Maven_3.9' }

  environment {
    PATH = "/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:${PATH}"
    DOCKER_IMAGE = "assugan/diploma-app"
    EC2_IP = "3.121.162.244"   //  EC2 IP
  }

  options { timestamps() }

  stages {
    stage('Checkout + Meta') {
      steps {
        checkout scm
        script {
          // Multibranch: для PR Jenkins сам выставляет CHANGE_ID
          env.IS_PR = env.CHANGE_ID ? 'true' : 'false'
          env.SHORT_SHA = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          env.BRANCH_SAFE = (env.CHANGE_BRANCH ?: env.BRANCH_NAME).replaceAll('/','-').toLowerCase()
        }
      }
    }

    stage('Lint') {
      steps {
        // Простейший пример линтера для Maven
        sh 'mvn -f app/pom.xml -DskipTests checkstyle:check || true'
      }
    }

    stage('Build') {
      steps {
        sh 'mvn -f app/pom.xml clean package -DskipTests'
      }
    }

    stage('Test') {
      steps {
        sh 'mvn -f app/pom.xml test'
      }
      post {
        always {
          junit 'app/target/surefire-reports/*.xml'
        }
      }
    }

    stage('Docker Buildx & Push (main only)') {
      when {
        allOf {
          branch 'main'
          expression { env.CHANGE_ID == null }  // не PR
        }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            set -euo pipefail
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin

            docker buildx create --name diploma_builder --use || true
            docker buildx inspect --bootstrap

            docker buildx build \
              --platform linux/amd64,linux/arm64 \
              -t "$DOCKER_IMAGE:${BRANCH_SAFE}-${SHORT_SHA}" \
              -t "$DOCKER_IMAGE:${BUILD_NUMBER}" \
              -t "$DOCKER_IMAGE:latest" \
              -f docker/Dockerfile \
              --push \
              .

            docker logout || true
          '''
        }
      }
    }

    stage('Deploy to EC2 (main only)') {
      when {
        allOf {
          branch 'main'
          expression { env.CHANGE_ID == null }  // не PR
        }
      }
      steps {
        sh '''
          set -euo pipefail
          mkdir -p ~/.ssh
          ssh-keyscan -H "$EC2_IP" >> ~/.ssh/known_hosts

          ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
            --extra-vars "docker_image=$DOCKER_IMAGE:${BRANCH_SAFE}-${SHORT_SHA}"
        '''
      }
    }
  }

  post {
    success { echo '✅ CI успешно; для main также выполнен CD.' }
    failure { echo '❌ Ошибка пайплайна (см. логи выше).' }
  }
}