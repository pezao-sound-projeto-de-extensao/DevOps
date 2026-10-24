#!/bin/bash
# Atualiza os serviços do swarm quando a tag :main muda no ECR (rodado pelo autodeploy.timer)
# ponytail: app-1 e app-2 checam de forma independente, então podem atualizar a mesma hora;
# escalonar os timers se a queda simultânea do web incomodar
set -euo pipefail

for svc in stockflow_app stockflow_web; do
  cur=$(docker service inspect "$svc" --format '{{.Spec.TaskTemplate.ContainerSpec.Image}}' 2>/dev/null) || continue
  img=${cur%@*}
  repo=${img#*/}
  repo=${repo%:*}

  remote=$(aws ecr describe-images --region us-east-1 --repository-name "$repo" --image-ids imageTag=main \
    --query 'imageDetails[0].imageDigest' --output text)
  [[ $cur == *"@$remote" ]] && continue

  echo "$svc: ${cur#*@} -> $remote"
  aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "${img%%/*}"
  docker service update --quiet --with-registry-auth --image "$img" "$svc"
done
