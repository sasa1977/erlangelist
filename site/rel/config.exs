use Mix.Releases.Config,
    # This sets the default release built by `mix release`
    default_release: :default,
    # This sets the default environment used by `mix release`
    default_environment: :prod

# For a full list of config options for both releases
# and environments, visit https://hexdocs.pm/distillery/configuration.html


# You may define one or more environments in this file,
# an environment's settings will override those of a release
# when building in that environment, this combination of release
# and environment configuration is called a profile

environment :dev do
  set dev_mode: true
  set include_erts: false
  set cookie: :"@>tB]Ts;!(?Wtgg}BX/>_.o3yl[A=nw`o4&s7)0cl9Ij!v5$~;3MKoywq*=g}$:^"
end

environment :prod do
  set include_erts: true
  set include_src: false
  set cookie: :"3H;P$XHQDOjdC6},6;sPy>jdMHkcAFAF_jr_CR0jD~VuY/igGD3NC3WiUBq9^Kke"
end

# You may define one or more releases in this file.
# If you have not set a default release, or selected one
# when running `mix release`, the first release in the file
# will be used by default

release :erlangelist do
  set version: current_version(:erlangelist)
end

