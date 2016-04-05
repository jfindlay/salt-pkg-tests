{# Import global parameters that source from grains and pillars #}
{% import 'params.jinja' as params %}

{% if params.use_latest %}
  {% set repo_url = 'https://repo.saltstack.com/{0}apt/debian/{1}/{2}/latest' %}
  {% set repo_url = repo_url.format(params.dev, params.os_major_release, params.os_arch) %}
{% else %}
  {% set repo_url = 'https://repo.saltstack.com/{0}apt/debian/{1}/{2}/archive/{3}' %}
  {% set repo_url = repo_url.format(params.dev, params.os_major_release, params.os_arch, params.salt_version) %}
{% endif %}

{% set key_url = '{0}/SALTSTACK-GPG-KEY.pub'.format(repo_url) %}


install-https-transport:
  pkg.installed:
    - name: apt-transport-https

add-repo:
  pkgrepo.managed:
    - name: deb {{ repo_url }} {{ params.os_code_name }} main
    - file: /etc/apt/sources.list.d/salt-{{ params.repo_version }}.list
    - key_url: {{ key_url }}
    - require:
      - pkg: install-https-transport

update-package-database:
  module.run:
    - name: pkg.refresh_db
    - require:
      - pkgrepo: add-repo

install-salt:
  pkg.installed:
    - names: {{ params.pkgs }}
    - version: {{ params.salt_version }}
    - require:
      - module: update-package-database

install-salt-backup:
  cmd.run:
    - name: aptitude -y install {{ params.versioned_pkgs | join(' ') }}
    - onfail:
      - pkg: install-salt