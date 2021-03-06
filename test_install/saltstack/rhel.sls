{# Import global parameters that source from grains and pillars #}
{% import 'params.jinja' as params %}

{# Parameters used with repo package install #}
{% set branch = params.salt_version.rsplit('.', 1)[0] %}
{% set repo_pkg = 'salt-repo-{0}.el{1}.noarch.rpm'.format(branch, params.os_major_release) %}
{% set repo_pkg_url = 'https://repo.saltstack.com/{0}yum/redhat/{1}'.format(params.dev, repo_pkg) %}

{# Parameters used with pkgrepo.managed install #}
{% if params.use_latest %}
  {% set repo_url = 'https://repo.saltstack.com/{0}yum/redhat/$releasever/$basearch/latest'.format(params.dev) %}
{% else %}
  {% set repo_url = 'https://repo.saltstack.com/{0}yum/redhat/$releasever/$basearch/archive/{1}' %}
  {% set repo_url = repo_url.format(params.dev, params.salt_version) %}
{% endif %}

{% set key_name = 'SALTSTACK-EL5-GPG-KEY.pub' if params.on_rhel_5 else 'SALTSTACK-GPG-KEY.pub' %} 
{% set key_url = '{0}/{1}'.format(repo_url, key_name) %}


{% if params.use_repo_pkg %}
add-repo:
  cmd.run:
    {% if params.on_rhel_5 %}
    - name: wget {{ repo_pkg_url }} ; rpm -iv {{ repo_pkg }} ; rm -f {{ repo_pkg }}
    {% else %}
    - name: rpm -iv {{ repo_pkg_url }}
    {% endif %}
    - unless:
      - rpm -q {{ repo_pkg.split('.rpm')[0] }}
{% else %}
add-repo:
  pkgrepo.managed:
    - name: saltstack-{{ params.repo_version }}
    - humanname: SaltStack {{ params.repo_version }} repo for RHEL/CentOS $releasever
    - baseurl: {{ repo_url }}
    - gpgcheck: 1
    - gpgkey: {{ key_url }}
{% endif %}

update-package-database:
  module.run:
    - name: pkg.refresh_db
    - require:
      {% if params.use_repo_pkg %}
      - cmd: add-repo
      {% else %}
      - pkgrepo: add-repo
      {% endif %}

install-salt:
  pkg.installed:
    - names: {{ params.pkgs }}
    - version: {{ params.salt_version }}
    - require:
      - module: update-package-database

install-salt-backup:
  cmd.run:
    - name: yum -y install {{ params.versioned_pkgs | join(' ') }}
    - onfail:
      - pkg: install-salt
