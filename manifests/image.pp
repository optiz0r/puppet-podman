# @summary pull or remove container images
#
# @param image String
#   The name of the container image to pull, which should be present in a
#   configured container registry.
#
# @param ensure String
#   State of the resource must be either `present` or `absent`.
#
# @param flags Hash
#   All flags for the 'podman image pull' command are supported, using only the
#   long form of the flag name.
#
# @param user String
#   Optional user for running rootless containers.  When using this parameter,
#   the user must also be defined as a Puppet resource and must include the
#   'uid', 'gid', and 'home'
#
# @example
#   podman::image { 'my_container':
#     image => 'my_container:tag',
#     flags => {
#              creds => 'USERNAME:PASSWORD',
#              },
#   }
#
define podman::image (
  String $image,
  String $ensure  = 'present',
  Hash $flags     = {},
  String $user    = '',
){
  # Convert $flags hash to command arguments
  $_flags = $flags.reduce('') |$mem, $flag| {
    "${mem} --${flag[0]} \"${flag[1]}\""
  }

  if $user != '' {
    ensure_resource('podman::rootless', $user, {})

    # Set execution environment for the rootless user
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
      environment => [
        "HOME=${User[$user]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}",
      ],
      cwd         => User[$user]['home'],
      provider    => 'shell',
      user        => $user,
      require     => [
        Podman::Rootless[$user],
        Service['systemd-logind'],
      ],
    }
  } else {
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
    }
  }

  case $ensure {
    'present': {
      Exec { "pull_image_${title}":
        command => "podman image pull ${_flags} ${image}",
        unless  => "podman image exists ${image}",
        *       => $exec_defaults,
      }
    }
    'absent': {
      Exec { "pull_image_${title}":
        command => "podman image pull ${_flags} ${image}",
        unless  => "podman rmi ${image}",
        *       => $exec_defaults,
      }
    }
    default: {
      fail('"ensure" must be "present" or "absent"')
    }
  }
}
