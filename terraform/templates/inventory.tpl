# inventory.tpl
all:
  children:
    spark_cluster:
      children:
        master:
          hosts:
            spark-master:
              ansible_host: ${master_ip}
        workers:
          hosts:
%{ for ip in worker_ips ~}
            spark-worker-${index(worker_ips, ip) + 1}:
              ansible_host: ${ip}
%{ endfor ~}
      vars:
        ansible_user: debian
        ansible_password: debian
        ansible_become_password: debian
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

