{% set os_ = salt['grains.get']('os', '') %}
{% set os_major_release = salt['grains.get']('osmajorrelease', '') %}
{% set distro = salt['grains.get']('oscodename', '')  %}
{% set on_rhel_5 = os_major_release == '5' %}


{% if salt['pillar.get']('staging') %}
  {% set staging = 'staging/' %}
{% endif  %}
{% set salt_version = salt['pillar.get']('salt_version', '') %}
{% if salt_version %}
  {% set branch = salt_version.rsplit('.', 1)[0] %}
{% else %}
  {% set branch = salt['pillar.get']('branch', '') %}
{% endif %}

{% set repo_pkg = 'sse-repo-{0}.el{1}.rpm'.format(branch, os_major_release) %}
{% set pkgs = ['salt-enterprise-master', 'salt-enterprise-minion', 'salt-enterprise-api', 'salt-enterprise-cloud', 'salt-enterprise-ssh', 'salt-enterprise-syndic'] %}
{% if salt_version %}
  {% set versioned_pkgs = [] %}
  {% for pkg in pkgs %}
    {% do versioned_pkgs.append(pkg + '-' + salt_version) %}
  {% endfor %}
  {% set pkgs = versioned_pkgs %}
{% endif %}


add-repository:
  cmd.run:
    {% if on_rhel_5 %}
    - name: wget https://erepo.saltstack.com/sse/{{ branch }}/rhel/{{ repo_pkg }} ; rpm -ivh {{ repo_pkg }} ; rm -f {{ repo_pkg }}
    {% else %}
    - name: rpm -ivh https://erepo.saltstack.com/sse/{{ branch }}/rhel/{{ repo_pkg }}
    {% endif %}

update-package-database:
  module.run:
    - name: pkg.refresh_db
    - require:
      - cmd: add-repository

update-package-database-backup:
  cmd.run:
    - name: yum -y makecache
    - onfail:
      - module: update-package-database

upgrade-packages:
  pkg.uptodate:
    - name: uptodate
    - require:
      - module: update-package-database

install-salt:
  pkg.installed:
    - name: salt-pkgs
    - pkgs: {{ pkgs }}
    - require:
      - pkg: upgrade-packages

install-salt-backup:
  cmd.run:
    - name: yum -y install {{ pkgs | join(' ') }}
    - onfail:
      - pkg: install-salt
