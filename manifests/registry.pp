# == Class: docker::registry
#
# Module to configure private docker registries from which to pull Docker images
# If the registry does not require authentication, this module is not required.
#
# === Parameters
# [*server*]
#   The hostname and port of the private Docker registry. Ex: dockerreg:5000
#
# [*ensure*]
#   Whether or not you want to login or logout of a repository
#
# [*username*]
#   Username for authentication to private Docker registry.  Required if ensure
#   is set to present.
#
# [*password*]
#   Password for authentication to private Docker registry. Required if ensure
#   is set to present.
#
# [*email*]
#   Email for registration to private Docker registry. Required if ensure is
#   set to present.
#
#
define docker::registry(
  $server      = $title,
  $ensure      = 'present',
  $username    = undef,
  $password    = undef,
  $email       = undef,
) {
  include docker::params

  validate_re($ensure, '^(present|absent)$')

  $docker_command = $docker::params::docker_command

  if $ensure == 'present' {
    validate_string($username)
    validate_string($password)
    validate_string($email)

    $auth_string = base64('encode', "${username}:${password}")

    # We can't manage the directory and config file directly here since we'd
    # end up with multiple resources managing the same files, and there isn't
    # another great place to put this.
    exec { "Create /root/.docker for ${title}":
      command => 'mkdir -m 0700 -p /root/.docker',
      creates => '/root/.docker',
    }

    -> exec { "Create /root/.docker/config.json for ${title}":
      command => 'echo "{}" > /root/.docker/config.json; chmod 0600 /root/.docker/config.json',
      creates => '/root/.docker/config.json',
    }

    -> augeas { "Create auth entry for ${title}":
      incl    => '/root/.docker/config.json',
      lens    => 'Json.lns',
      changes => [
        "set dict/entry[. = 'auths'] 'auths'",
        "set dict/entry[. = 'auths']/dict/entry[. = '${server}'] '${server}'",
        "set dict/entry[. = 'auths']/dict/entry[. = '${server}']/dict/entry[. = 'auth'] auth",
        "set dict/entry[. = 'auths']/dict/entry[. = '${server}']/dict/entry[. = 'auth']/string ${auth_string}",
        "set dict/entry[. = 'auths']/dict/entry[. = '${server}']/dict/entry[. = 'email'] email",
        "set dict/entry[. = 'auths']/dict/entry[. = '${server}']/dict/entry[. = 'email']/string ${email}",
      ],
    }

  } else {
    augeas { "Remove auth entry for ${title}":
      incl    => '/root/.docker/config.json',
      lens    => 'Json.lns',
      changes => [
        "rm dict/entry[. = 'auths']/dict/entry[. = '${server}']",
      ],
    }
  }
}
