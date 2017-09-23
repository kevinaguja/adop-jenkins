#!/bin/bash

# Load secrets from files in $SECRETS_DIR
# Secret format is KEY=VALUE encoded in base 64
SECRETS_DIR=/etc/secrets
if [[ -d $SECRETS_DIR ]]; then
  COMMAND=$1; shift
  ARGS=$@

  export_vars() {
    while IFS= read -r LINE || [[ -n "$LINE" ]]; do
      export $(echo $LINE)
    done < $1
  }

  recurse_dir() {
    if [ "$(ls -A $1)" ]; then
      local SECRET
      for SECRET in $1/*; do
        if [ -d $SECRET ]; then
          recurse_dir $SECRET
        else
          export_vars $SECRET
        fi
      done
    fi
  }

  if  [ -d $SECRETS_DIR ]; then
    recurse_dir $SECRETS_DIR
  fi
fi

if [[ $ADOP_GERRIT_ENABLED == "true" ]] && [[ $ADOP_GITLAB_ENABLED = "true" ]]; then

  echo "You can't have both Gerrit and Gitlab enabled.."
  echo "Please set only either to true. Exiting with error.."
  exit 1

elif [[ $ADOP_GERRIT_ENABLED == "true" ]]; then

  echo "'jenkins' user will now be configured for Gerrit."
  host=$GERRIT_HOST_NAME
  port=$GERRIT_PORT
  username=$JENKINS_USERNAME
  password=$JENKINS_PASSWORD

  # Delete Load Platform for Gitlab
  rm -rf /usr/share/jenkins/ref/jobs/GitLab_Load_Platform

  nohup /usr/share/jenkins/ref/adop\_scripts/generate_key.sh -c ${host} -p ${port} -u ${username} -w ${password} &

elif [[ $ADOP_GITLAB_ENABLED = "true" ]]; then

  # Delete Load Platform for Gerrit
  rm -rf /usr/share/jenkins/ref/jobs/Load_Platform

  # Generate SSH key
  echo "'jenkins' user will now be configured for Gitlab."
  host=${GITLAB_HOST_NAME:-gitlab}
  port=${GITLAB_PORT:-22}
  username=${JENKINS_USERNAME}
  password=${JENKINS_PASSWORD}
  nohup /usr/share/jenkins/ref/adop\_scripts/generate_key.sh -c ${host} -p ${port} -u ${username} -w ${password} &

  # Wait until gitlab is up and running
  SLEEP_TIME=10
  MAX_RETRY=12
  COUNT=0
  until [[ $(curl -I -s ${GITLAB_HTTP_URL}/users/sign_in | head -1 | grep 200 | wc -l) -eq 1 ]] || [[ $COUNT -eq $MAX_RETRY ]]
  do
    echo "Testing GitLab Connection endpoint - ${GITLAB_HTTP_URL} .."
    echo "GitLab unavailable, sleeping for ${SLEEP_TIME}s ..retrying $COUNT/$MAX_RETRY"
    sleep ${SLEEP_TIME}
    ((COUNT ++))
  done

  if [[ $COUNT -eq $MAX_RETRY ]]
  # Skip Jenkins and Gitlab key configuration
  then
    echo "Couldn't wait for ${GITLAB_HOST_NAME} anymore. SSH and Jenkins gitlab token may not work properly.."

  # Start 1 time configuration
  else
    echo "Get the gitlab token and place it in a file for adop_gitlab.groovy"
    GITLAB_ROOT_TOKEN="$(curl -X POST "${GITLAB_HTTP_URL}/api/v3/session?login=root&password=${GITLAB_ROOT_PASSWORD}" | python -c "import json,sys;obj=json.load(sys.stdin);print obj['private_token'];")"
    echo "${GITLAB_ROOT_TOKEN}" > ${JENKINS_HOME}/gitlab-root-token

    echo "Perform a first login for jenkins user in Gitlab"
    curl --silent --header "PRIVATE-TOKEN: ${GITLAB_ROOT_TOKEN}" -X POST "${GITLAB_HTTP_URL}/api/v3/users?email=${GIT_GLOBAL_CONFIG_EMAIL}&name=jenkins&username=jenkins&password=${password}&provider=ldap&extern_uid=cn=${username},ou=people,${LDAP_ROOTDN}&admin=true&confirm=false" | true

    echo "Send ssh key to gitlab's root user profile"
    public_key_val=$(cat ${JENKINS_HOME}/.ssh/id_rsa.pub)
    echo "Adding jenkins SSH key to GitLab root user.."
    curl --silent --header "PRIVATE-TOKEN: ${GITLAB_ROOT_TOKEN}" -X POST "${GITLAB_HTTP_URL}/api/v3/users/1/keys" --data-urlencode "title=jenkins@adop-core" --data-urlencode "key=${public_key_val}" | true
  fi

fi

echo "Starting Jenkins.."
#echo "skip upgrade wizard step after installation"
#echo "2.60.3" > /var/jenkins_home/jenkins.install.UpgradeWizard.state

#chown -R 1000:1000 /var/jenkins_home
su jenkins -c /usr/local/bin/jenkins.sh
