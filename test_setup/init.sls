{% set os_ = salt['grains.get']('os', '') %}

{% set salt_version = pillar.get('salt_version', '') %}
{% set minion_id = '{0}-{1}'.format(grains.get('id'), salt_version) %}

{% if os_ == 'Ubuntu' and not salt_version.startswith('20') %}
  {% set master_service = 'salt-enterprise-master' %}
  {% set minion_service = 'salt-enterprise-minion' %}
{% else %}
  {% set master_service = 'salt-master' %}
  {% set minion_service = 'salt-minion' %}
{% endif %}


disable_services:
  service.dead:
    - names:
      - {{ master_service }}
      - {{ minion_service }}
    - require_in:
      - file: remove_pki
      - file: clear_minion_id
      - file: minion_config

remove_pki:
  file.absent:
    - name: /etc/salt/pki

clear_minion_id:
  file.absent:
    - name: /etc/salt/minion_id

minion_config:
  file.managed:
    - name: /etc/salt/minion
    - contents: |
        master: localhost
        id: {{ minion_id }}

enable_services:
# this doesn't seem to be working
#  service.enabled:
#    - names:
#      - salt-master
#      - salt-minion
  cmd.run:
    - names:
      - service {{ master_service }} start
      - service {{ minion_service }} start
    - require:
      - file: remove_pki
      - file: clear_minion_id
      - file: minion_config

wait_for_key:
  cmd.run:
    - name: sleep 7
    - require:
      - cmd: enable_services

accept_key:
  cmd.run:
    - name: 'salt-key -ya {{ minion_id }}'
    - require:
      - cmd: wait_for_key
