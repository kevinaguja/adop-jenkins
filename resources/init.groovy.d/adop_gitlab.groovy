import jenkins.model.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.common.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.jenkins.plugins.sshcredentials.impl.*
import org.jenkinsci.plugins.plaincredentials.*
import org.jenkinsci.plugins.plaincredentials.impl.*
import hudson.util.Secret
import hudson.plugins.sshslaves.*
import org.apache.commons.fileupload.* 
import org.apache.commons.fileupload.disk.*
import java.nio.file.Files

// Check if enabled
def env = System.getenv()
if (!env['ADOP_GITLAB_ENABLED'].toBoolean()) {
  println "--> ADOP Gitlab Disabled"
  return
}

def jenkins_home = env['JENKINS_HOME']
def secretfile = new File(jenkins_home + '/gitlab-root-token')

if ( !secretfile.exists() ) {
  println "--> Can't find the secret file.. Exiting Gitlab configuration."
  return
}

// Constants
def instance = Jenkins.getInstance()

Thread.start {
  sleep 10000

  // Secret Text for Gitlab
  println "--> Registering Gitlab root user token.."
  def system_credentials_provider = SystemCredentialsProvider.getInstance()

  def credential_description = "ADOP Gitlab root token"

  gitlab_credentials_exist = false
  system_credentials_provider.getCredentials().each {
    credentials = (com.cloudbees.plugins.credentials.Credentials) it
    if ( credentials.getDescription() == credential_description) {
        gitlab_credentials_exist = true
        println("Found existing credentials: " + credential_description)
      }
   }

  if(!gitlab_credentials_exist) {
    def credential_scope = CredentialsScope.GLOBAL
    def credential_id = "gitlab-secrets-id"
    String secret_text = secretfile.text

    def credential_domain = com.cloudbees.plugins.credentials.domains.Domain.global()
    def credential_creds = new StringCredentialsImpl(credential_scope,credential_id,credential_description,Secret.fromString(secret_text))

    system_credentials_provider.addCredentials(credential_domain,credential_creds)
  }

  // Delete the secret file for security
  // secretfile.delete()

  // Save the state
  instance.save()
}
