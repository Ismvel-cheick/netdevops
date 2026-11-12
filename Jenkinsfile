// =============================================================================
// Pipeline CI/CD NetDevOps — les 9 étapes du sujet
//  1 Checkout  2 Lint  3 SonarQube  4 Build Docker  5 Trivy
//  6 Déploiement test  7 Tests de connectivité  8 Déploiement prod  9 Notification
// =============================================================================
pipeline {
    agent any

    // Vérifie le dépôt Git toutes les 2 minutes (la VM n'est pas joignable par webhook)
    triggers { pollSCM('H/2 * * * *') }

    options {
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '15'))
        disableConcurrentBuilds()
    }

    environment {
        IMAGE_TAG        = "${env.BUILD_NUMBER}"
        SONAR_HOST_URL   = 'http://localhost:9000'
        NOTIFY_EMAIL     = 'canzoumana26@gmail.com'
        // Mot de passe Vault fourni par un script qui lit la variable VAULT_PASS
        ANSIBLE_VAULT_PASSWORD_FILE = "${env.WORKSPACE}/ansible/vault-pass-from-env.sh"
        ANSIBLE_FORCE_COLOR = 'false'
        REPORTS          = 'reports'
    }

    stages {

        stage('1. Checkout') {
            steps {
                checkout scm
                sh '''
                    mkdir -p "$REPORTS"
                    chmod +x ansible/vault-pass-from-env.sh
                    git log --oneline -5
                '''
            }
        }

        stage('2. Lint') {
            steps {
                // Un problème de style rend le build "instable" (orange) sans l'arrêter
                catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                    sh 'yamllint -f parsable . > "$REPORTS/yamllint.txt" 2>&1; rc=$?; cat "$REPORTS/yamllint.txt"; exit $rc'
                }
                catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                    // ansible-lint vérifie la syntaxe du playbook : il doit pouvoir lire le coffre Vault
                    withCredentials([string(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')]) {
                        sh 'cd ansible && ansible-lint --offline site.yml > "../$REPORTS/ansible-lint.txt" 2>&1; rc=$?; cat "../$REPORTS/ansible-lint.txt"; exit $rc'
                    }
                }
                catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                    sh 'pylint scripts/*.py > "$REPORTS/pylint.txt" 2>&1; rc=$?; cat "$REPORTS/pylint.txt"; exit $rc'
                }
            }
        }

        stage('3. SonarQube Scan') {
            steps {
                // Si le serveur SonarQube est indisponible, le build devient instable
                // mais le déploiement continue (l'analyse est un contrôle qualité)
                catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            docker run --rm --network host \
                              -e SONAR_HOST_URL="$SONAR_HOST_URL" -e SONAR_TOKEN="$SONAR_TOKEN" \
                              -e SONAR_SCANNER_OPTS="-Xmx512m" \
                              -v "$WORKSPACE:/usr/src" \
                              sonarsource/sonar-scanner-cli:latest
                        '''
                    }
                }
            }
        }

        stage('4. Build Docker') {
            steps {
                sh '''
                    for svc in router-fw web-dmz dns-lan client; do
                      docker build --pull -t "netdevops/$svc:$IMAGE_TAG" -t "netdevops/$svc:latest" "docker/$svc"
                    done
                '''
            }
        }

        stage('5. Trivy Scan') {
            steps {
                sh '''
                    for svc in router-fw web-dmz dns-lan client; do
                      trivy image --quiet --severity HIGH,CRITICAL --ignore-unfixed \
                        --format table -o "$REPORTS/trivy-$svc.txt" "netdevops/$svc:$IMAGE_TAG"
                      trivy image --quiet --severity HIGH,CRITICAL --ignore-unfixed \
                        --format json -o "$REPORTS/trivy-$svc.json" "netdevops/$svc:$IMAGE_TAG"
                      echo "== $svc ==" && cat "$REPORTS/trivy-$svc.txt"
                    done
                '''
                // Une CVE CRITIQUE corrigeable rend le build instable (à traiter)
                catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
                    sh '''
                        for svc in router-fw web-dmz dns-lan client; do
                          trivy image --quiet --severity CRITICAL --ignore-unfixed --exit-code 1 \
                            "netdevops/$svc:$IMAGE_TAG" > /dev/null
                        done
                    '''
                }
            }
        }

        stage('6. Déploiement Test') {
            steps {
                withCredentials([string(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')]) {
                    sh '''
                        cd ansible
                        ansible-playbook -i inventories/test/hosts.yml site.yml \
                          -e image_tag="$IMAGE_TAG" -e stack_build=never
                    '''
                }
            }
        }

        stage('7. Tests de connectivité') {
            steps {
                sh '''
                    # Pas de "| tee" : le code retour des tests doit faire échouer le stage
                    rc=0
                    bash tests/connectivity.sh test > "$REPORTS/tests-test.txt" 2>&1 || rc=1
                    cat "$REPORTS/tests-test.txt"
                    python3 scripts/audit_nftables.py test-router-fw 172.30.1.10 > "$REPORTS/audit-nftables-test.txt" 2>&1 || rc=1
                    cat "$REPORTS/audit-nftables-test.txt"
                    exit $rc
                '''
            }
        }

        stage('8. Déploiement Prod') {
            steps {
                withCredentials([string(credentialsId: 'ansible-vault-pass', variable: 'VAULT_PASS')]) {
                    sh '''
                        cd ansible
                        ansible-playbook -i inventories/prod/hosts.yml site.yml \
                          -e image_tag="$IMAGE_TAG" -e stack_build=never
                    '''
                }
                sh '''
                    rc=0
                    bash tests/connectivity.sh prod > "$REPORTS/tests-prod.txt" 2>&1 || rc=1
                    cat "$REPORTS/tests-prod.txt"
                    python3 scripts/audit_nftables.py router-fw 172.20.1.10 > "$REPORTS/audit-nftables-prod.txt" 2>&1 || rc=1
                    cat "$REPORTS/audit-nftables-prod.txt"
                    exit $rc
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }
        success {
            echo "Pipeline réussi : build ${env.BUILD_NUMBER} déployé en production."
        }
        // 9. Notification en cas d'échec
        failure {
            script {
                try {
                    mail to: env.NOTIFY_EMAIL,
                         subject: "[NetDevOps] ECHEC du build #${env.BUILD_NUMBER}",
                         body: "Le pipeline ${env.JOB_NAME} #${env.BUILD_NUMBER} a échoué.\nDétails : ${env.BUILD_URL}console"
                } catch (err) {
                    echo "Notification email non envoyée (serveur SMTP non configuré) : ${err}"
                }
            }
        }
        unstable {
            echo 'Build instable : voir les rapports lint / Trivy dans les artefacts.'
        }
    }
}
