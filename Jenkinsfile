//  pipe
pipeline {
  agent any
  tools { maven 'Maven_3.9' }

  environment {
    // macOS: чтобы Jenkins видел docker/ansible/terraform
    PATH = "/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:${PATH}"

    // DockerHub repo
    DOCKER_IMAGE = "assugan/diploma-app"
  }

  options { timestamps() }

  stages {
    stage('Checkout + Meta') {
      steps {
        checkout scm
        script {
          env.SHORT_SHA   = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          env.BRANCH_SAFE = (env.CHANGE_BRANCH ?: env.BRANCH_NAME).replaceAll('/','-').toLowerCase()
        }
      }
    }

    stage('Lint') {
      steps {
        sh 'mvn -f app/pom.xml -DskipTests checkstyle:check'
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
          expression { env.BRANCH_NAME == 'main' }  // именно ветка main
          not { changeRequest() }                   // и это не PR
        }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            set -euo pipefail
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin

            # buildx для multi-arch (Mac arm64 -> EC2 amd64)
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
          expression { env.BRANCH_NAME == 'main' }
          not { changeRequest() }
        }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          withEnv([
            'AWS_DEFAULT_REGION=eu-central-1',
            'ANSIBLE_HOST_KEY_CHECKING=False' // не стопоримся на unknown host keys
          ]) {
            sh '''
              set -euo pipefail

              # Убедимся, что ansible есть и поставим коллекции
              ansible --version
              ansible-galaxy collection install -r ansible/requirements.yml --force

              # (на всякий) Убедимся, что boto3 есть в активном Python
              python3 -m pip install --user boto3 botocore >/dev/null 2>&1 || true

              # Быстрая диагностика: увидим найденные хосты
              ansible-inventory -i ansible/inventory.aws_ec2.yml --graph

              # Деплой приложения и мониторинга на все найденные инстансы
              ansible-playbook -i ansible/inventory.aws_ec2.yml ansible/playbook.yml \
                --extra-vars "docker_image=$DOCKER_IMAGE:${BRANCH_SAFE}-${SHORT_SHA}"
            '''
          }
        }
      }
    }

  post {
    success { echo '✅ CI успешно; для main выполнены Buildx/Push/Deploy.' }
    failure { echo '❌ Ошибка пайплайна (см. логи выше).' }
  }
}