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
        sh '''
          set -euo pipefail

          # 1) Получаем актуальный IP из Terraform outputs
          EC2_IP="$(cd infra && terraform output -raw ec2_public_ip)"
          echo "EC2_IP=${EC2_IP}"

          # 2) Подготавливаем known_hosts
          mkdir -p ~/.ssh
          ssh-keyscan -H "$EC2_IP" >> ~/.ssh/known_hosts

          # 3) Делаем временный dynamic-inventory, чтобы не править ansible/inventory.ini
          cat > ansible/inventory.dynamic.ini <<INV
[app]
${EC2_IP} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/ssh-diploma-key.pem
INV

          # 4) Запуск плейбука с образом текущей сборки
          ansible-playbook -i ansible/inventory.dynamic.ini ansible/playbook.yml \
            --extra-vars "docker_image=$DOCKER_IMAGE:${BRANCH_SAFE}-${SHORT_SHA}"
        '''
      }
    }
  }

  post {
    success { echo '✅ CI успешно; для main выполнены Buildx/Push/Deploy.' }
    failure { echo '❌ Ошибка пайплайна (см. логи выше).' }
  }
}