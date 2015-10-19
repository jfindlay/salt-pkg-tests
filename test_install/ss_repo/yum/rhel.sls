{% set os_ = salt['grains.get']('os', '') %}
{% set os_major_release = salt['grains.get']('osmajorrelease', '') %}
{% set os_family = salt['grains.get']('os_family', '')  %}
{% set on_rhel_5 = True if os_family == 'RedHat' and os_major_release == '5' else False %}

{% set staging = 'staging/' if salt['pillar.get']('staging') else '' %}
{% set salt_version = salt['pillar.get']('salt_version', '') %}
{% set pkgs = ['salt-master', 'salt-minion', 'salt-api', 'salt-cloud', 'salt-ssh', 'salt-syndic'] %}
{% set repo_key = 'SALTSTACK-EL5-GPG-KEY.pub' if on_rhel_5 else 'SALTSTACK-GPG-KEY.pub' %}

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
    - name: wget https://repo.saltstack.com/{{ staging }}yum/rhel{{ os_major_release }}/{{ repo_key }} ; rpm --import {{ repo_key }} ; rm -f {{ repo_key }}
    {% else %}
    - name: rpm --import https://repo.saltstack.com/{{ staging }}yum/rhel{{ os_major_release }}/{{ repo_key }}
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
        baseurl=https://repo.saltstack.com/{{ staging }}yum/rhel{{ os_major_release }}
        enabled=1
        gpgcheck=1
        gpgkey=https://repo.saltstack.com/{{ staging }}yum/rhel{{ os_major_release }}/{{ repo_key }}
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
