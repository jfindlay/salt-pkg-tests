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

{% if on_rhel_5 %}
  {% set repo_key = 'SALTSTACK-EL5-GPG-KEY.pub' %}
{% else %}
  {% set repo_key = 'SALTSTACK-GPG-KEY.pub' %}
{% endif %}

{% set pkgs = ['salt-enterprise-master', 'salt-enterprise-minion', 'salt-enterprise-api', 'salt-enterprise-cloud', 'salt-enterprise-ssh', 'salt-enterprise-syndic'] %}
{% if salt_version %}
  {% set versioned_pkgs = [] %}
  {% for pkg in pkgs %}
    {% do versioned_pkgs.append(pkg + '-' + salt_version) %}
  {% endfor %}
  {% set pkgs = versioned_pkgs %}
{% endif %}


get-key:
  cmd.run:
    {% if on_rhel_5 %}
    - name: wget http://104.239.193.113/repo/{{ branch }}/testing/redhat/rhel{{ os_major_release }}/{{ repo_key }} ; rpm --import {{ repo_key }} ; rm -f {{ repo_key }}
    {% else %}
    - name: rpm --import http://104.239.193.113/repo/{{ branch }}/testing/redhat/rhel{{ os_major_release }}/{{ repo_key }}
    {% endif %}

add-repository:
  file.managed:
    - name: /etc/yum.repos.d/saltstack.repo
    - makedirs: True
    - contents: |
        ####################
        # Enable SaltStack's package repository
        [saltstack-repo]
        name=SaltStack repo for RHEL/CentOS {{ os_major_release }}
        baseurl=http://104.239.193.113/repo/{{ branch }}/testing/redhat/rhel{{ os_major_release }}
        enabled=1
        gpgcheck=1
        gpgkey=http://104.239.193.113/repo/{{ branch }}/testing/redhat/rhel{{ os_major_release }}/{{ repo_key }}
    - require:
      - cmd: get-key

update-package-database:
  module.run:
    - name: pkg.refresh_db
    - require:
      - file: add-repository

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
