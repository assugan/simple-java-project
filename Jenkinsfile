pipeline {
  agent any
  tools { maven 'Maven_3.9' }

  environment {
    // macOS: добавим стандартные пути, чтобы docker/ansible были видны
    PATH         = "/usr/local/bin:/opt/homebrew/bin:/Applications/Docker.app/Contents/Resources/bin:${PATH}"
    DOCKER_IMAGE = "assugan/diploma-app"
    AWS_REGION   = "eu-central-1"
  }

  options {
    timestamps()
  }

  stages {
    stage('Checkout + Meta') {
      steps {
        checkout scm
        script {
          // CHANGE_ID существует в сборках PR (Multibranch)
          env.IS_PR      = env.CHANGE_ID ? 'true' : 'false'
          env.SHORT_SHA  = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
          env.BRANCH_SAFE = (env.CHANGE_BRANCH ?: env.BRANCH_NAME).replaceAll('/', '-').toLowerCase()
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
          branch 'main'
          expression { env.CHANGE_ID == null } // не PR, а обычный коммит в main
        }
      }
      steps {
        withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DH_USER', passwordVariable: 'DH_PASS')]) {
          sh '''
            set -euo pipefail
            echo "$DH_PASS" | docker login -u "$DH_USER" --password-stdin

            # buildx может уже существовать — это нормально
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
          expression { env.CHANGE_ID == null } // не PR
        }
      }
      steps {
        withCredentials([
          sshUserPrivateKey(credentialsId: 'ec2-ssh-key', keyFileVariable: 'EC2_SSH_KEY', usernameVariable: 'EC2_SSH_USER')
        ]) {
          sh '''
            set -euo pipefail
            export AWS_DEFAULT_REGION="${AWS_REGION}"
            export ANSIBLE_HOST_KEY_CHECKING=False

            # Установим/обновим плагин инвентори и зависимости для AWS
            ansible --version
            ansible-galaxy collection install -r ansible/requirements.yml --force
            python3 -m pip install --user boto3 botocore >/dev/null 2>&1 || true

            # Посмотрим, что находит dynamic inventory по тегу Name=diploma-ec2 (как в Terraform)
            ansible-inventory -i ansible/inventory.aws_ec2.yml --graph

            # Деплой приложения и мониторинга.
            # Ключ и IdentitiesOnly явно — чтобы не зависеть от локальных настроек.
            ansible-playbook -i ansible/inventory.aws_ec2.yml ansible/playbook.yml -vvv\
              -u "$EC2_SSH_USER" --private-key "$EC2_SSH_KEY" \
              -e 'ansible_ssh_common_args=-o IdentitiesOnly=yes' \
              --extra-vars "docker_image=$DOCKER_IMAGE:${BRANCH_SAFE}-${SHORT_SHA}"
          '''
        }
      }
    }
  }

  post {
    success {
      echo '✅ CI пройден.'
    }
    failure {
      echo '❌ Ошибка пайплайна (см. логи выше).'
    }
  }
}