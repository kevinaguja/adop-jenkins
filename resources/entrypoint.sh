#!/bin/bash

if [[ $ADOP_GERRIT_ENABLED == "true" ]] && [[ $ADOP_GITLAB_ENABLED = "true" ]]; then

  echo "You can't have both Gerrit and Gitlab enabled.."
  echo "Please set only either to true. Exiting with error.."
  exit 1

elif [[ $ADOP_GERRIT_ENABLED == "true" ]]; then

  echo "'jenkins' user will now be configured for Gerrit."
  host=$GERRIT_HOST_NAME
  port=$GERRIT_PORT
  username=$GERRIT_JENKINS_USERNAME
  password=$GERRIT_JENKINS_PASSWORD

  # Delete Load Platform for Gitlab
  rm -rf /usr/share/jenkins/ref/jobs/GitLab_Load_Platform

  nohup /usr/share/jenkins/ref/adop\_scripts/generate_key.sh -c ${host} -p ${port} -u ${username} -w ${password} &

elif [[ $ADOP_GITLAB_ENABLED = "true" ]]; then

  # Delete Load Platform for Gerrit
  rm -rf /usr/share/jenkins/ref/jobs/Load_Platform

  # Generate SSH key
  echo "'jenkins' user will now be configured for Gitlab."
  host=$GITLAB_HOST_NAME
  port=$GITLAB_PORT
  username=$GITLAB_JENKINS_USERNAME
  password=$GITLAB_JENKINS_PASSWORD
  nohup /usr/share/jenkins/ref/adop\_scripts/generate_key.sh -c ${host} -p ${port} -u ${username} -w ${password} &

  # Wait until gitlab is up and running
  SLEEP_TIME=10
  MAX_RETRY=12
  COUNT=0
  until [[ $(curl -I -s gitlab/gitlab/users/sign_in | head -1 | grep 200 | wc -l) -eq 1 ]] || [[ $COUNT -eq $MAX_RETRY ]]
  do
    echo "Testing GitLab Connection endpoint - http://gitlab/gitlab .."
    echo "GitLab unavailable, sleeping for ${SLEEP_TIME}s ..retrying $COUNT/$MAX_RETRY"
    sleep ${SLEEP_TIME}
    ((COUNT ++))
  done

  if [[ $COUNT -eq $MAX_RETRY ]]
  # Skip Jenkins and Gitlab key configuration
  then
    echo "Couldn't wait for Gitlab anymore. SSH and Jenkins gitlab token may not work properly.."

  # Start 1 time configuration
  else
    # Create token file for adop_gitlab.groovy to read
    echo "Obtaining GitLab root token.."
    GITLAB_ROOT_TOKEN="$(curl -X POST "http://gitlab/gitlab/api/v3/session?login=root&password=${GITLAB_ROOT_PASSWORD}" | python -c "import json,sys;obj=json.load(sys.stdin);print obj['private_token'];")"
    echo "${GITLAB_ROOT_TOKEN}" > ${JENKINS_HOME}/gitlab-root-token

    # Initialize a login for jenkins user in Gitlab
    public_key_val=$(cat ${JENKINS_HOME}/.ssh/id_rsa.pub)
    echo "Initializing jenkins user in Gitlab.."
    curl --silent --header "PRIVATE-TOKEN: ${GITLAB_ROOT_TOKEN}" -X POST "http://gitlab/gitlab/api/v3/users?email=${GIT_GLOBAL_CONFIG_EMAIL}&name=jenkins&username=jenkins&password=${password}&provider=ldap&extern_uid=cn=jenkins,ou=people,${LDAP_ROOTDN}&admin=true&confirm=false" | true

    # Send ssh key to gitlab's root user profile
    echo "Adding jenkins SSH key to GitLab root user.."
    curl --silent --header "PRIVATE-TOKEN: ${GITLAB_ROOT_TOKEN}" -X POST "http://gitlab/gitlab/api/v3/users/1/keys" --data-urlencode "title=jenkins@adop-core" --data-urlencode "key=${public_key_val}" | true
  fi

fi

echo "Starting Jenkins.."
echo "skip upgrade wizard step after installation"
echo "2.7.2" > /var/jenkins_home/jenkins.install.UpgradeWizard.state

chown -R 1000:1000 /var/jenkins_home
su jenkins -c /usr/local/bin/jenkins.sh
